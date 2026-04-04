# frozen_string_literal: true

# Entry → Transaction 展示适配器
# 在 Transaction → Entry 迁移完成前，将 Entry 对象包装为兼容 Transaction 视图的接口
class TransactionPresenter
  attr_reader :id, :account_id, :account, :date, :amount, :currency, :note,
              :type, :category, :category_id, :target_account_id, :target_account

  # 从 Entry 构建兼容 Transaction 的展示对象
  def self.from_entry(entry)
    presenter = new
    presenter.id = entry.id
    presenter.account_id = entry.account_id
    presenter.account = entry.account
    presenter.date = entry.date
    presenter.amount = entry.amount.abs
    presenter.currency = entry.currency
    presenter.note = entry.notes || entry.name

    if entry.transfer_id.present?
      presenter.type = 'TRANSFER'
      # 判断转出/转入方向
      if entry.amount < 0
        presenter.account_id = entry.account_id
        presenter.account = entry.account
        presenter.target_account_id = find_transfer_target_account(entry)
        presenter.target_account = Account.find_by(id: presenter.target_account_id)
      else
        source_account_id = find_transfer_source_account(entry)
        presenter.account_id = source_account_id
        presenter.account = Account.find_by(id: source_account_id)
        presenter.target_account_id = entry.account_id
        presenter.target_account = entry.account
      end
    elsif entry.entryable.respond_to?(:kind)
      presenter.type = entry.entryable.kind.upcase
      if entry.entryable.respond_to?(:category)
        presenter.category = entry.entryable.category
        presenter.category_id = entry.entryable.category_id
      end
    end

    presenter
  end

  def persisted?
    true
  end

  def new_record?
    false
  end

  def to_param
    id.to_s
  end

  def model_name
    ActiveModel::Name.new(Transaction, nil, 'transaction')
  end

  private

  def self.find_transfer_target_account(entry)
    target_entry = Entry.where(transfer_id: entry.transfer_id)
                        .where.not(id: entry.id)
                        .where('amount > 0')
                        .first
    target_entry&.account_id
  end

  def self.find_transfer_source_account(entry)
    source_entry = Entry.where(transfer_id: entry.transfer_id)
                        .where.not(id: entry.id)
                        .where('amount < 0')
                        .first
    source_entry&.account_id
  end

  private_class_method :find_transfer_target_account, :find_transfer_source_account
end
