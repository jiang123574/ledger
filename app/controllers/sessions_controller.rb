class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new create]
  layout "login"

  def new
  end

  def create
    if valid_credentials?
      reset_session
      session[:authenticated] = true
      redirect_to session[:return_to] || root_path, notice: "登录成功"
    else
      flash.now[:alert] = "用户名或密码错误"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:authenticated] = nil
    session[:return_to] = nil
    redirect_to login_path, notice: "已退出登录"
  end

  private

  def valid_credentials?
    auth_user = ENV["AUTH_USER"]
    auth_password = ENV["AUTH_PASSWORD"]
    return false if auth_user.blank? || auth_password.blank?

    ActiveSupport::SecurityUtils.secure_compare(params[:username], auth_user) &&
      ActiveSupport::SecurityUtils.secure_compare(params[:password], auth_password)
  end
end
