# frozen_string_literal: true

class Cms::HygienePagesController < Cms::BaseController
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

  def edit
    @hygiene_page = HygienePage.find_by(slug: params[:id])
  end

  def update
    @hygiene_page = HygienePage.find(params[:id])
    @hygiene_page.attributes = hygiene_page_params
    @hygiene_page.save
    if @hygiene_page.errors.empty?
      flash[:success] = "#{@hygiene_page.slug.underscore.humanize.capitalize} successfully updated!"
      redirect_to cms_root_path
    else
      flash.now[:danger] = @hygiene_page.errors.full_messages.to_sentence
      render :new
    end
  end

  private

  def handle_record_not_found
    flash[:danger] = 'Hygiene Page not found!'
    redirect_to cms_root_path
  end

  def hygiene_page_params
    params.require(:hygiene_page).permit(
      :content
    )
  end
end
