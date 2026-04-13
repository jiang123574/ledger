# AccountDashboardService 使用文档

## 概述

`AccountDashboardService` 是从 `AccountsController#index` 中提取的数据准备服务，用于加载账户仪表盘所需的所有数据。

## 使用方法

### 基本用法

```ruby
# 创建服务实例
service = AccountDashboardService.new(params)

# 加载仪表盘数据
dashboard_data = service.load_dashboard

# 返回的数据结构
{
  accounts: [],                    # 账户列表 (Array)
  accounts_map: {},                # 账户映射 {id => Account} (Hash)
  account_balances: {},            # 账户余额映射 {id => balance} (Hash)
  total_assets: 0,                 # 总资产 (BigDecimal)
  categories: [],                  # 活跃分类列表 (Array)
  expense_categories: [],          # 活跃支出分类列表 (Array)
  counterparties: [],              # 交易对手列表 (Array)
  unsettled_receivables: [],       # 未结应收款 (ActiveRecord_Relation)
  entries_with_balance: [],        # 带余额的条目列表 [[Entry, balance], ...] (Array)
  total_count: 0,                  # 条目总数 (Integer)
  account_balance: 0,              # 账户余额 (BigDecimal)
  total_income: 0,                 # 总收入 (BigDecimal)
  total_expense: 0,                # 总支出 (BigDecimal)
  total_balance: 0,                # 总余额 (BigDecimal)
  entry: Entry.new,                # 新建条目对象 (Entry)
  new_transaction: OpenStruct.new  # 新建交易对象 (OpenStruct)
}
```

### 支持的参数

```ruby
params = {
  page: 1,                    # 页码 (默认: 1, 范围: 1-1000)
  per_page: 15,               # 每页条数 (默认: 15, 范围: 15-200)
  account_id: nil,            # 账户ID过滤 (可选)
  type: nil,                  # 交易类型过滤: "expense" 或 "income" (可选)
  category_ids: [],           # 分类ID过滤 (可选, 数组)
  search: nil,                # 搜索关键词 (可选)
  period_type: "month",       # 期间类型: "month", "week", "year", "all" (默认: "month")
  period_value: "2026-04",    # 期间值 (默认: 当前期间)
  sort_direction: "desc",     # 排序方向: "asc" 或 "desc" (默认: "desc")
  show_hidden: "false"        # 是否显示隐藏账户: "true" 或 "false" (默认: "false")
}
```

## 在 Controller 中使用

```ruby
class AccountsController < ApplicationController
  def index
    service = AccountDashboardService.new(params)
    dashboard_data = service.load_dashboard
    
    # 将数据赋值给实例变量（保持视图兼容性）
    dashboard_data.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end
end
```

## 缓存策略

服务使用了以下缓存策略：

- **账户列表**: 缓存 10 分钟 (CacheConfig::TEN_MINUTES)
- **账户余额**: 缓存 1 分钟 (CacheConfig::SHORT)
- **总资产**: 缓存 1 分钟 (CacheConfig::SHORT)
- **分类列表**: 缓存 1 小时 (CacheConfig::LONG)
- **交易对手**: 缓存 1 小时 (CacheConfig::LONG)
- **条目总数**: 缓存 30 秒 (CacheConfig::FAST)
- **条目列表**: 缓存 2 分钟 (CacheConfig::MEDIUM)
- **统计数据**: 缓存 1 分钟 (CacheConfig::SHORT)

缓存版本通过 `CacheBuster` 管理，确保数据更新时缓存自动失效。

## 依赖的服务

- `AccountStatsService`: 用于计算条目余额和统计数据
- `SystemAccountSyncService`: 用于同步系统账户
- `PeriodFilterable`: 用于期间过滤
- `CacheBuster`: 用于缓存版本管理
- `CacheConfig`: 用于缓存 TTL 配置

## 注意事项

1. 服务会自动检查并同步系统账户（应收款、应付款）
2. 所有缓存键都包含版本号，确保数据一致性
3. 条目列表只缓存 ID 和余额，每次请求重新查询对象以确保预加载信息完整
4. 服务返回的 `entries_with_balance` 是二维数组 `[[Entry, balance], ...]`