class CounterpartiesController < ApplicationController
  before_action :set_counterparty, only: [ :update, :destroy ]

  def create
    @counterparty = Counterparty.new(counterparty_params)

    if @counterparty.save
      redirect_to settings_path(section: "contacts"), notice: "交易对方已创建"
    else
      redirect_to settings_path(section: "contacts"), alert: @counterparty.errors.full_messages.join(", ")
    end
  end

  def update
    if @counterparty.update(counterparty_params)
      redirect_to settings_path(section: "contacts"), notice: "交易对方已更新"
    else
      redirect_to settings_path(section: "contacts"), alert: @counterparty.errors.full_messages.join(", ")
    end
  end

  def destroy
    has_receivables = @counterparty.receivables.exists?
    has_payables = Payable.where(counterparty_id: @counterparty.id).or(Payable.where(counterparty: @counterparty.name)).exists?

    if has_receivables || has_payables
      linked = []
      linked << "应收款" if has_receivables
      linked << "应付款" if has_payables
      redirect_to settings_path(section: "contacts"), alert: "该交易对方关联了#{linked.join('和')}，无法删除"
      return
    end

    @counterparty.destroy
    redirect_to settings_path(section: "contacts"), notice: "交易对方已删除"
  end

  private

  def set_counterparty
    @counterparty = Counterparty.find(params[:id])
  end

  def counterparty_params
    params.require(:counterparty).permit(:name, :contact, :note)
  end
end
