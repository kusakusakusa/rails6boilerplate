# frozen_string_literal: true

module Cms
  class SamplesController < Cms::BaseController
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

    def index
      @samples = Sample.all
    end

    def new
      @sample = Sample.new
    end

    def show
      @sample = Sample.find(params[:id])
    end

    def edit
      @sample = Sample.find(params[:id])
    end

    def create
      @sample = Sample.new(sample_params)
      @sample.save
      if @sample.errors.empty?
        redirect_to cms_samples_path
      else
        flash[:danger] = @sample.errors.full_messages.to_sentence
        render :new
      end
    end

    def update
      @sample = Sample.find(params[:id])
      @sample.attributes = sample_params
      @sample.save
      if @sample.errors.empty?
        flash[:success] = "#{@sample.title} successfully updated!"
        redirect_to cms_samples_path
      else
        render :new
      end
    end

    def destroy
      @sample = Sample.find(params[:id])
      @sample.destroy
      if @sample.errors.empty?
        flash[:success] = "#{@sample.title} successfully deleted!"
      else
        flash[:danger] = @sample.errors.full_messages.to_sentence
      end
      redirect_to cms_samples_path
    end

    private

    def handle_record_not_found
      flash[:danger] = 'Post not found!'
      redirect_to cms_samples_path
    end

    def sample_params
      params.require(:sample).permit(
        :title,
        :description,
        :publish_date,
        :featured,
        :content,
        :cover_image
      )
    end
  end
end
