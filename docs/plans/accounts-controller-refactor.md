# Issue #91: accounts_controller.rb 重构计划

## 目标
- 控制器从 644 行减少至 300 行以内
- 数据准备逻辑提取到服务对象
- 重复的 JSON 序列化逻辑提取到 Presenter
- 功能保持不变，测试覆盖新提取的服务

## 当前问题分析

### 1. `index` action 过重 (7-121 行)
- 加载账户列表、余额、分类、交易对手、应收款
- 构建分页 entries + 计算运行余额
- 调用 AccountStatsService 获取统计
- 混合了缓存逻辑和业务逻辑

### 2. `entries` action 与 index 高度重复 (145-250 行)
- 缓存键构建、分页逻辑与 index 几乎相同
- 大量 entry → JSON 转换代码（~60 行）

### 3. `bills_entries` action 有类似的 entry → JSON 转换 (293-387 行)
- 与 entries action 的数据转换逻辑高度相似

## 重构方案

### Task 1: 创建 AccountDashboardService
提取 `index` action 的数据准备逻辑:
- 账户列表加载（含缓存）
- 账户余额映射（含缓存）
- 分类加载（含缓存）
- 未结应收款加载
- entries 查询构建 + 分页 + 运行余额计算
- 统计数据加载（含缓存）

### Task 2: 创建 EntryPresenter
提取 entry → JSON 转换逻辑:
- 从 `entries` action 提取 entry_data 构建（lines 188-247）
- 从 `bills_entries` action 提取类似逻辑（lines 330-374）
- 统一为 EntryPresenter.entry_json(e, balance_map, account_filter)

### Task 3: 精简控制器
- index action 改为调用 AccountDashboardService
- entries action 改为调用 EntryPresenter
- bills_entries action 改为调用 EntryPresenter
- 删除重复代码

### Task 4: 编写测试
- AccountDashboardService 单元测试
- EntryPresenter 单元测试
- 回归测试确保功能不变

## 相关文件
- `app/controllers/accounts_controller.rb` - 主要修改目标
- `app/services/account_stats_service.rb` - 已有的统计服务（保持不变）
- `app/services/account_dashboard_service.rb` - 新建
- `app/presenters/entry_presenter.rb` - 新建
- `spec/services/account_dashboard_service_spec.rb` - 新建
- `spec/presenters/entry_presenter_spec.rb` - 新建
