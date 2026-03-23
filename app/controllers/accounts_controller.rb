class AccountsController < ApplicationController
  before_action :set_account, only: [ :show, :edit, :update, :destroy ]

  def index
    @accounts = Account.order(:sort_order, :name)
    @categories = Category.active.by_sort_order
    
    # 支持筛选的交易查询
    @transactions = Transaction.includes(:account, :category, :tags)
    
    # 按账户筛选
    if params[:account_id].present?
      @transactions = @transactions.where(account_id: params[:account_id])
    end
    
    # 按类型筛选
    if params[:type].present?
      @transactions = @transactions.where(type: params[:type])
    end
    
    # 按日期筛选
    if params[:start_date].present?
      @transactions = @transactions.where("date >= ?", params[:start_date])
    end
    if params[:end_date].present?
      @transactions = @transactions.where("date <= ?", params[:end_date])
    end
    
    # 按关键词搜索
    if params[:search].present?
      @transactions = @transactions.where("note LIKE ?", "%#{params[:search]}%")
    end
    
    @transactions = @transactions.order(date: :desc, created_at: :desc).limit(200)
    
    @transaction = Transaction.new(currency: "CNY", date: Date.today)
  end

  def show
  end

  def new
    @account = Account.new
  end

  def edit
  end

  def create
    @account = Account.new(account_params)
    if @account.save
      redirect_to accounts_path, notice: "账户已创建"
    else
      render :new
    end
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "账户已更新"
    else
      render :edit
    end
  end

  def destroy
    @account.destroy
    redirect_to accounts_url, notice: "账户已删除"
  end

  def reorder
    @account = Account.find(params[:id])
    target_account = Account.find(params[:target_id])
    
    # 交换 sort_order
    current_order = @account.sort_order
    target_order = target_account.sort_order
    
    @account.update!(sort_order: target_order)
    target_account.update!(sort_order: current_order)
    
    head :ok
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def account_params
    params.require(:account).permit(
      :name, :type, :initial_balance, :currency,
      :billing_day, :due_day, :credit_limit,
      :billing_day_mode, :due_day_mode, :due_day_offset,
      :include_in_total, :hidden, :sort_order
    )
  end
end
