# 缓存 TTL 集中管理
# 所有 Controller 中的 expires_in 值统一在此定义，便于维护和调整
module CacheConfig
  # 高频变动数据（交易列表、账户余额）
  FAST = 30.seconds
  SHORT = 1.minute
  MEDIUM = 2.minutes

  # 中频变动数据（预算列表、统计）
  MODERATE = 5.minutes
  TEN_MINUTES = 10.minutes

  # 低频变动数据（账户列表、分类）
  LONG = 1.hour
end
