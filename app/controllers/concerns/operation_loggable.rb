# frozen_string_literal: true

# 操作日志记录 Concern
# 用于在控制器中统一记录各种操作
module OperationLoggable
  extend ActiveSupport::Concern

  # 记录创建操作
  def log_create(item, description: nil)
    OperationLog.log_create(item, request: request, description: description)
  end

  # 记录更新操作
  def log_update(item, description: nil)
    OperationLog.log_update(item, request: request, description: description)
  end

  # 记录删除操作
  def log_destroy(item, description: nil)
    OperationLog.log_destroy(item, request: request, description: description)
  end

  # 记录结算操作
  def log_settle(item, amount: nil, account: nil, description: nil)
    OperationLog.log_settle(item, amount: amount, account: account, request: request, description: description)
  end

  # 记录撤销操作
  def log_revert(item, description: nil)
    OperationLog.log_revert(item, request: request, description: description)
  end

  # 记录执行操作
  def log_execute(item, result: nil, description: nil)
    OperationLog.log_execute(item, result: result, request: request, description: description)
  end

  # 记录导入操作
  def log_import(item_type:, count: nil, source: nil, description: nil)
    OperationLog.log_import(item_type: item_type, count: count, source: source, request: request, description: description)
  end
end