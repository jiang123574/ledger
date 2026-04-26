# 可复用的结算状态判断模块
# 提供统一的 settled? 方法判断逻辑
#
# 使用方式：
#   class Payable < ApplicationRecord
#     include Settlementable
#   end

module Settlementable
  extend ActiveSupport::Concern

  # 判断是否已结算/完成
  # 条件：已标记结算时间 或 剩余金额 <= 0
  def settled?
    settled_at.present? || remaining_amount.to_d <= 0
  end
end
