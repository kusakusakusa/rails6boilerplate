# frozen_string_literal: true

module Cms
  class <%= name.camelcase.pluralize %>Controller < Cms::BaseController
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

    def index
      @<%= file_name.pluralize %> = <%= name.camelcase %>.all
    end

    def new
      @<%= underscored %> = <%= name.camelcase %>.new
    end

    def show
      @<%= underscored %> = <%= name.camelcase %>.find(params[:id])
    end

    def edit
      @<%= underscored %> = <%= name.camelcase %>.find(params[:id])
    end

    def create
      @<%= underscored %> = <%= name.camelcase %>.new(<%= underscored %>_params)
      @<%= underscored %>.save
      if @<%= underscored %>.errors.empty?
        flash[:success] = "<%= name.camelcase %> successfully created"
        redirect_to cms_<%= underscored %>_path(@<%= underscored %>)
      else
        flash[:danger] = @<%= underscored %>.errors.full_messages.to_sentence
        render :new
      end
    end

    def update
      @<%= underscored %> = <%= name.camelcase %>.find(params[:id])
      @<%= underscored %>.attributes = <%= underscored %>_params
      @<%= underscored %>.save
      if @<%= underscored %>.errors.empty?
        flash[:success] = "<%= name.camelcase %> successfully updated"
        redirect_to cms_<%= underscored %>_path(@<%= underscored %>)
      else
        flash[:danger] = @<%= underscored %>.errors.full_messages.to_sentence
        render :edit
      end
    end

    def destroy
      @<%= underscored %> = <%= name.camelcase %>.find(params[:id])
      @<%= underscored %>.destroy
      if @<%= underscored %>.errors.empty?
        flash[:success] = "<%= file_name.humanize %> successfully deleted!"
      else
        flash[:danger] = @<%= underscored %>.errors.full_messages.to_sentence
      end
      redirect_to cms_<%= file_name.pluralize %>_path
    end

    private

    def handle_record_not_found
      flash[:danger] = '<%= name.camelcase %> not found!'
      redirect_to cms_<%= file_name.pluralize %>_path
    end

    def <%= underscored %>_params
      params.require(:<%= underscored %>).permit(
        :TODO
      )
    end
  end
end
