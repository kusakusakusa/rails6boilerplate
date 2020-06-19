# frozen_string_literal: true

class ApplicationController < ActionController::Base
  layout :layout_by_resource

  def homepage
  end

  def healthcheck
    head :ok, content_type: 'text/html'
  end

  def log_test
    env = nil
    case Rails.env.to_sym
    when :test, :development, :staging
      env = :staging
    else
      env = Rails.env.to_sym
    end

    log = CloudWatchLogger.new(
      {
        access_key_id: Rails.application.credentials.dig(env, :aws, :cloudwatch, :access_key_id),
        secret_access_key: Rails.application.credentials.dig(env, :aws, :cloudwatch, :secret_access_key)
      },
      "#{Rails.application.class.module_parent_name}-#{Rails.env}",
      'errors',
      region: Rails.application.credentials.dig(env, :aws, :region)
    )

    log.error('log error test')

    render body: nil, status: 204 and return
  end

  def hygiene_page
    begin
      @hygiene_page = HygienePage.find_by!(slug: params[:id])
    rescue
      raise ActionController::RoutingError.new('Not Found')
    end
  end

  def sample_pdf
    @sample = Sample.find_by(id: 1) || Sample.new(
      title: Faker::Lorem.words(number: 4).join(' '),
      description: Faker::Lorem.paragraph(sentence_count: 6),
      publish_date: Faker::Date.between(from: 1.year.ago, to: Date.today),
      featured: [true, false].sample,
      price: 1000,
      user: User.find_by(id: 1) || User.new(
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        email: Faker::Internet.email,
        password: 'password',
        confirmed_at: Time.now.utc
      )
    )
    render  pdf: "sample_pdf",   # Excluding ".pdf" extension.
          template: "layouts/pdf/sample_pdf.html.slim",
          layout: false,
          footer:  {
                      html: { 
                        template: 'layouts/pdf/footer.html.slim',
                        layout: false,
                        locals: { sample: @sample }
                      }
                    },
          margin:  {   
                      top: 10,
                      bottom: 40,
                      left: 10,
                      right: 10
                    }
  end

  private

  def layout_by_resource
    if devise_controller?
      if resource_name == :admin_user &&
        controller_name == 'registrations'
        # update account pages should use cms template
        'cms'
      else
        'devise'
      end
    else
      'application'
    end
  end

  def after_sign_in_path_for(resource)
    cms_root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    case resource_or_scope
    when :admin_user
      new_admin_user_session_path
    else
      root_path
    end
  end
end
