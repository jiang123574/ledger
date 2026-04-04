# frozen_string_literal: true

# 交易类型中文显示映射
# 消除 Transaction.display_type 和 TransactionsController.t_display 的代码重复
module TransactionTypeDisplay
  TYPE_LABELS = {
    "INCOME" => "收入",
    "EXPENSE" => "支出",
    "TRANSFER" => "转账",
    "ADVANCE" => "预支",
    "REIMBURSE" => "报销"
  }.freeze

  def self.label(type)
    TYPE_LABELS[type] || type
  end
end
