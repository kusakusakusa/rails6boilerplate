# frozen_string_literal: true

module Cms
  class AttachmentsController < Cms::BaseController
    before_action :find_record

    def index
      @attachments = @record.public_send(params[:resource]).order(created_at: :desc)
    end

    def new
      @attachment = @record.public_send(params[:resource]).build
    end

    def create
      begin
        ActiveRecord::Base.transaction do
          @record.public_send(params[:resource]).attach(attachment_file)
          @record.save!

          flash[:success] = "#{params[:resource].singularize.titlecase} successfully added"
          redirect_to public_send("cms_#{@record.class.name.underscore}_#{params[:resource]}_path", @record)
        end
      rescue ActiveRecord::RecordInvalid => e
        flash[:danger] = e.message
        redirect_to public_send("new_cms_#{@record.class.name.underscore}_#{params[:resource].singularize}_path")
      end
    end

    def edit
      @attachment = @record.public_send(params[:resource]).find(params[:id])
    end

    def update
      begin
        ActiveRecord::Base.transaction do
          @record.public_send(params[:resource]).attach(attachment_file)
          @record.save!
          @record.public_send("#{params[:resource]}_attachments").find(params[:id]).purge
          flash[:success] = "#{params[:resource].singularize.titlecase} successfully updated"
          redirect_to public_send("cms_#{@record.class.name.underscore}_#{params[:resource]}_path", @record)
        end
      rescue ActiveRecord::RecordInvalid => e
        flash[:danger] = e.message
        redirect_to public_send("edit_cms_#{@record.class.name.underscore}_#{params[:resource].singularize}_path", @record, params[:id])
      end
    end

    def destroy
      @record.public_send("#{params[:resource]}_attachments").find(params[:id]).purge
      flash[:success] = "#{params[:resource].singularize.titlecase} successfully deleted"
      redirect_to public_send("cms_#{@record.class.name.underscore}_#{params[:resource]}_path", @record)
    end

    def update_order
      ActiveRecord::Base.transaction do
        desired_order.each_with_index do |id, index|
          @record.public_send(params[:resource]).find(id).update(created_at: Time.zone.now - index.minutes)
        end
      end

      flash[:success] = 'Order successfully updated'
      redirect_to public_send("cms_#{@record.class.name.underscore}_#{params[:resource]}_path", @record)
    end

    private

    def find_record
      params.keys.each do |key|
        regex_group = key.match /(?<class_name>\w+)_id/
        begin
          @record = Object.const_get(regex_group[:class_name].camelize).find(params[key.to_sym])
          return
        rescue NameError => e
          next
        end
      end
      flash[:danger] = "Record not found"
      redirect_back(fallback_location: cms_root_path)
    end

    def desired_order
      params.permit(:ordering)[:ordering].split(',')
    end

    def attachment_file
      params.require(:attachment).permit(:file)[:file]
    end
  end
end
