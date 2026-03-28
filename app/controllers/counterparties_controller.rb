class CounterpartiesController < ApplicationController
  before_action :set_counterparty, only: [ :edit, :update, :destroy ]

  def index
    # Counterparties are referenced by name in receivables.counterparty string field
    # Cannot use joins with string field, so we use subquery
    @counterparties = Counterparty.all
                                  .order(:name)
                                  .map do |cp|
                                    cp.define_singleton_method(:receivables_count) { Receivable.where(counterparty: cp.name).count }
                                    cp
                                  end
                                  .sort_by { |cp| [ -cp.receivables_count, cp.name ] }

    # Stats
    @total_counterparties = Counterparty.count
    @total_receivables = Receivable.where.not(counterparty: [ nil, "" ]).count
  end

  def show
    @counterparty = Counterparty.find(params[:id])
    @receivables = @counterparty.receivables.order(date: :desc)
    @total_amount = @receivables.sum(:original_amount)
    @settled_amount = @receivables.where.not(settled_at: nil).sum(:original_amount)
    @pending_amount = @total_amount - @settled_amount
  end

  def new
    @counterparty = Counterparty.new
  end

  def create
    @counterparty = Counterparty.new(counterparty_params)

    if @counterparty.save
      redirect_to counterparties_path, notice: "交易对方已创建"
    else
      redirect_to counterparties_path, alert: @counterparty.errors.full_messages.join(", ")
    end
  end

  def edit
  end

  def update
    if @counterparty.update(counterparty_params)
      redirect_to counterparties_path, notice: "交易对方已更新"
    else
      redirect_to counterparties_path, alert: @counterparty.errors.full_messages.join(", ")
    end
  end

  def destroy
    if @counterparty.receivables.any?
      redirect_to counterparties_path, alert: "该交易对方关联了应收款，无法删除"
      return
    end

    @counterparty.destroy
    redirect_to counterparties_path, notice: "交易对方已删除"
  end

  private

  def set_counterparty
    @counterparty = Counterparty.find(params[:id])
  end

  def counterparty_params
    params.require(:counterparty).permit(:name, :contact, :note)
  end
end
