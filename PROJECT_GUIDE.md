# Ledger 项目开发指南

> 本文档整合了项目开发过程中积累的经验和规范，是开发工作的核心参考文档。

---

## 一、核心原则

### 1.1 数据性能优先

处理多年数据时，必须重点关注：

```ruby
# ✅ 正确：让数据库做统计
stats = Transaction.where(date: 5.years.ago..Time.now)
                   .group("date_trunc('month', date)")
                   .sum(:amount)

# ❌ 错误：把数据取出来用 Ruby 遍历
transactions = Transaction.all.to_a
stats = transactions.group_by { |t| t.date.beginning_of_month }
                     .transform_values { |ts| ts.sum(&:amount) }
```

### 1.2 大批量数据处理

```ruby
# ✅ 必须使用 find_each 处理大批量数据
Transaction.find_each(batch_size: 1000) do |transaction|
  # 处理每条记录
end

# ❌ 错误：会导致内存爆炸
Transaction.all.each do |transaction|
end
```

### 1.3 查询优化

```ruby
# 使用索引优化查询
add_index :transactions, [:account_id, :date]

# 预加载关联避免 N+1
@transactions = Transaction.includes(:account, :category, :tags)

# 使用 pluck 获取特定字段
Account.pluck(:id, :name)  # 而不是 Account.all.map { |a| [a.id, a.name] }
```

---

## 二、代码规范

### 2.1 模型设计

```ruby
# 业务逻辑放在模型中
class Transaction < ApplicationRecord
  # Scope 定义常用查询
  scope :by_date, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :income, -> { where(type: 'INCOME') }
  scope :expense, -> { where(type: 'EXPENSE') }
  
  # 完整的数据验证
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date, presence: true
end
```

### 2.2 ViewComponent 使用指南

| 场景 | 建议 |
|------|------|
| 复杂业务逻辑 | 使用 ViewComponent |
| 多处复用 | 使用 ViewComponent |
| 简单数据展示 | 使用 partial |
| 静态 HTML | 使用 partial |

### 2.3 Git 提交规范

```
<type>: <subject>

type:
- feat: 新功能
- fix: 修复 bug
- refactor: 重构
- docs: 文档变更
- style: 代码格式
- test: 测试
- chore: 构建/工具
```

---

## 三、已实现功能清单

### 3.1 DS 组件库 ✅

| 组件 | 状态 | 文件 |
|------|------|------|
| Button | ✅ | `app/components/ds/button_component.rb` |
| Card | ✅ | `app/components/ds/card_component.rb` |
| Badge | ✅ | `app/components/ds/badge_component.rb` |
| Icon | ✅ | `app/components/ds/icon_component.rb` |
| FilledIcon | ✅ | `app/components/ds/filled_icon_component.rb` |
| Alert | ✅ | `app/components/ds/alert_component.rb` |
| Menu | ✅ | `app/components/ds/menu_component.rb` |
| MenuItem | ✅ | `app/components/ds/menu_item_component.rb` |
| Tooltip | ✅ | `app/components/ds/tooltip_component.rb` |
| Toggle | ✅ | `app/components/ds/toggle_component.rb` |
| Select | ✅ | `app/components/ds/select_component.rb` |
| Input | ✅ | `app/components/ds/input_component.rb` |
| Tabs | ✅ | `app/components/ds/tabs_component.rb` |
| Disclosure | ✅ | `app/components/ds/disclosure_component.rb` |
| Dialog | ✅ | `app/components/ds/dialog_component.rb` |
| EmptyState | ✅ | `app/components/ds/empty_state_component.rb` |
| DonutChart | ✅ | `app/components/ds/donut_chart_component.rb` |
| SankeyChart | ✅ | `app/components/ds/sankey_chart_component.rb` |
| FilterBadge | ✅ | `app/components/ds/filter_badge_component.rb` |
| SelectionBar | ✅ | `app/components/ds/selection_bar_component.rb` |

### 3.2 核心功能 ✅

- ✅ 交易管理 (5 种类型: INCOME/EXPENSE/TRANSFER/ADVANCE/REIMBURSE)
- ✅ 账户管理 (多货币支持)
- ✅ 分类管理 (层级分类)
- ✅ 标签系统 (多对多关联)
- ✅ 预算管理 (进度条 + 预警)
- ✅ 应收款管理 (报销流程)
- ✅ 计划管理 (分期还款)
- ✅ 交易对方
- ✅ 导入数据 (貔貅记账 CSV 格式)
- ✅ 报表统计
- ✅ 备份管理 (WebDAV 云备份)
- ✅ 快捷键支持
- ✅ 数据核对工具

### 3.3 移动端响应式 ✅

- ✅ Safe Area 支持 (iPhone 刘海屏)
- ✅ 滑入式侧边栏
- ✅ 移动端底部导航
- ✅ 触摸友好按钮 (min 44px)

---

## 四、Stimulus 控制器清单

| 控制器 | 功能 | 状态 |
|--------|------|------|
| `menu_controller.js` | 下拉菜单定位 | ✅ |
| `tooltip_controller.js` | 工具提示定位 | ✅ |
| `select_controller.js` | 自定义选择器 | ✅ |
| `alert_controller.js` | 可关闭警告 | ✅ |
| `bulk_select_controller.js` | 批量选择 | ✅ |
| `auto_submit_form_controller.js` | 表单自动提交 | ✅ |
| `theme_controller.js` | 主题切换 | ✅ |
| `color_theme_controller.js` | 颜色主题 | ✅ |
| `dashboard_section_controller.js` | Section 折叠 | ✅ |
| `dashboard_sortable_controller.js` | 拖拽排序 | ✅ |
| `donut_chart_controller.js` | 环形图 | ✅ |
| `category_donut_chart_controller.js` | 分类环形图 | ✅ |
| `sankey_chart_controller.js` | 桑基图 | ✅ |
| `time_series_chart_controller.js` | 时间序列图 | ✅ |
| `trend_line_chart_controller.js` | 趋势线图 | ✅ |
| `sparkline_chart_controller.js` | 迷你图 | ✅ |
| `budget_gauge_controller.js` | 预算仪表盘 | ✅ |
| `mobile_layout_controller.js` | 移动端布局 | ✅ |
| `haptic_controller.js` | 触摸反馈 | ✅ |
| `page_transition_controller.js` | 页面过渡动画 | ✅ |
| `page_skeleton_controller.js` | 页面骨架屏 | ✅ |
| `stagger_list_controller.js` | 列表错开动画 | ✅ |
| `loading_button_controller.js` | 加载按钮 | ✅ |
| `list_filter_controller.js` | 列表过滤 | ✅ |
| `account_sort_controller.js` | 账户排序 | ✅ |
| `credit_card_form_controller.js` | 信用卡表单 | ✅ |
| `stats_loader_controller.js` | 统计数据加载 | ✅ |
| `ds_disclosure_controller.js` | Disclosure 交互 | ✅ |

---

## 五、配置速查

### 5.1 常用命令

```bash
# 安装依赖
bundle install

# 数据库迁移
rails db:migrate

# 运行开发服务器
rails s

# 运行测试
bundle exec rspec

# 代码检查
bundle exec rubocop

# 清除缓存
rails runner "Rails.cache.clear"
```

### 5.2 数据核对脚本

用于验证导入数据与 CSV 源文件的一致性：

```bash
# 验证单个账户
rails verify:account[账户ID]

# 示例：验证支付宝余额账户
rails verify:account[735]

# 快速扫描所有账户，找出有差异的账户
rails verify:all
```

**输出说明：**

| 字段 | 含义 |
|------|------|
| CSV | CSV 文件中的数据 |
| 数据库 | 实际导入的数据 |
| 差异 | CSV - 数据库 |

**常见差异原因：**

1. 转账账户格式无法解析（如 `转账 / 优惠抵扣`）
2. 账户不存在
3. 金额为 0 的记录被跳过
4. CSV 末尾汇总行（无效数据）

### 5.2 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| DB_HOST | localhost | 数据库主机 |
| DB_USERNAME | postgres | 数据库用户名 |
| DB_PASSWORD | - | 数据库密码 |
| RAILS_MASTER_KEY | - | Rails 主密钥 |

---

## 六、API 端点

- `GET /api/external/health` - 健康检查
- `GET /api/external/context` - 获取账户/分类/标签列表
- `POST /api/external/transactions` - 创建交易
- `GET /api/currency/rates` - 汇率信息

---

## 七、待优化事项

### 7.1 性能优化

- [x] 添加数据库连接池配置
  - 配置文件: `config/database.yml`
  - 连接池大小: 10 (可配置 `RAILS_DB_POOL`)
  - 添加超时设置: checkout_timeout, statement_timeout
- [x] 实现关键页面片段缓存
  - Dashboard 控制器添加数据缓存
  - 使用 Rails.cache 配合 SolidCache
  - 缓存键基于最后交易更新时间
- [x] 添加 API 速率限制
  - 配置文件: `config/initializers/rack_attack.rb`
  - API 请求: 100次/分钟
  - POST 请求: 20次/分钟
  - 交易创建: 30次/分钟

### 7.2 功能增强

- [x] PWA 支持 (离线访问)
  - 增强版 service worker: 缓存策略 + 离线页面
  - 完善的 manifest.json: 快捷方式、主题色
  - 自动注册 service worker
- [x] 触摸反馈 (haptic feedback)
  - Stimulus 控制器: `haptic_controller.js`
  - 支持多种反馈模式: light/medium/heavy/success/error
  - 自动检测设备支持
- [x] Core Web Vitals 监控
  - 监控脚本: `app/javascript/web_vitals.js`
  - 指标: LCP, FID, CLS, FCP, TTFB
  - 评分标准基于 Google 推荐

---

## 八、过时文档清理

以下文档已完成使命，可以删除：

| 文件 | 原因 |
|------|------|
| `RUBY_MIGRATION_PLAN.md` | 迁移已完成 |
| `UI_PLAN.md` | UI 已实现 |
| `README_ORIGINAL.md` | 旧项目说明，已不适用 |
| `docs/sure-ui-research.md` | 设计已采纳实现 |
| `docs/MOBILE_RESPONSIVE.md` | 功能已实现 |

---

**文档维护**: 每次重大更新后，请更新本文档的"已实现功能清单"和"待优化事项"。