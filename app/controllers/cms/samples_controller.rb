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
        flash[:success] = "Sample successfully created"
        redirect_to cms_sample_path(@sample)
      else
        flash[:danger] = @sample.print_errors
        render :new
      end
    end

    def update
      @sample = Sample.find(params[:id])
      @sample.attributes = sample_params
      @sample.save
      if @sample.errors.empty?
        flash[:success] = "Sample successfully updated"
        redirect_to cms_sample_path(@sample)
      else
        flash[:danger] = @sample.print_errors
        render :edit
      end
    end

    def destroy
      @sample = Sample.find(params[:id])
      @sample.destroy
      if @sample.errors.empty?
        flash[:success] = "#{@sample.title} successfully deleted!"
      else
        flash[:danger] = @sample.print_errors
      end
      redirect_to cms_samples_path
    end

    private

    def handle_record_not_found
      flash[:danger] = 'Sample not found!'
      redirect_to cms_samples_path
    end

    def sample_params
      params.require(:sample).permit(
        :title,
        :description,
        :publish_date,
        :featured,
        :price,
        :featured_image
      )
    end
  end
end
