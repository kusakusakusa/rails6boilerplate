# frozen_string_literal: true

module Cms
  class UsersController < Cms::BaseController
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

    def index
      @users = User.all
    end

    def new
      @user = User.new
    end

    def show
      @user = User.find(params[:id])
    end

    def edit
      @user = User.find(params[:id])
    end

    def create
      begin
        @user = User.create_with_temporary_password!(user_params)

        flash[:success] = "User successfully created"
        redirect_to cms_user_path(@user)
      rescue ActiveRecord::RecordInvalid => e
        if @user
          flash[:danger] = @user.print_errors
        else
          @user = User.new(user_params)
          flash[:danger] = e.message
        end

        render :new
      end
    end

    def update
      @user = User.find(params[:id])
      @user.attributes = user_params
      @user.save
      if @user.errors.empty?
        flash[:success] = "User successfully updated"
        redirect_to cms_user_path(@user)
      else
        flash[:danger] = @user.print_errors
        render :edit
      end
    end

    def destroy
      @user = User.find(params[:id])
      @user.destroy
      if @user.errors.empty?
        flash[:success] = "Users successfully deleted!"
      else
        flash[:danger] = @user.print_errors
      end
      redirect_to cms_users_path
    end

    private

    def handle_record_not_found
      flash[:danger] = 'User not found!'
      redirect_to cms_users_path
    end

    def user_params
      params.require(:user).permit(
        :email,
        :first_name,
        :last_name,
      )
    end
  end
end
