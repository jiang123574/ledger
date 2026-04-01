# Monetizable - 货币处理
# 学习自 Sure

module Monetizable
  extend ActiveSupport::Concern
  
  included do
    def amount_money
      Money.new(amount, currency)
    end
    
    def amount_money=(money)
      self.amount = money.amount
      self.currency = money.currency.iso_code
    end
  end
end