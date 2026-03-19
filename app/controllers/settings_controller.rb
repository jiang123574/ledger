class SettingsController < ApplicationController
  def show
    @currencies = Currency.order(:code)
  end

  def update
    redirect_to settings_path, notice: "设置已更新"
  end
end
