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

    # 按分类筛选（支持多选）
    if params[:category_ids].present?
      category_ids = Array(params[:category_ids]).reject(&:blank?)
      @transactions = @transactions.where(category_id: category_ids) if category_ids.any?
    end

    # 按周期筛选（年/月/周）
    period_type = params[:period_type].presence || "month"
    period_value = params[:period_value].presence ||
      case period_type
      when "year" then Date.current.year.to_s
      when "week" then Date.current.strftime("%G-W%V")
      else Date.current.strftime("%Y-%m")
      end

    begin
      range =
        case period_type
        when "all"
          nil # 不限制日期范围
        when "year"
          year = period_value.to_i
          start_date = Date.new(year, 1, 1)
          end_date = start_date.end_of_year
          start_date..end_date
        when "week"
          if (m = period_value.match(/\A(\d{4})-W(\d{2})\z/))
            year = m[1].to_i
            week = m[2].to_i
            start_date = Date.commercial(year, week, 1)
            end_date = start_date + 6.days
            start_date..end_date
          end
        else # month
          if (m = period_value.match(/\A(\d{4})-(\d{2})\z/))
            year = m[1].to_i
            month = m[2].to_i
            start_date = Date.new(year, month, 1)
            end_date = start_date.end_of_month
            start_date..end_date
          end
        end

      @transactions = @transactions.where(date: range) if range.present?
    rescue Date::Error
      # Ignore invalid period input and keep existing scope.
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
      redirect_to accounts_path, alert: @account.errors.full_messages.join(", ")
    end
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "账户已更新"
    else
      redirect_to accounts_path, alert: @account.errors.full_messages.join(", ")
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
