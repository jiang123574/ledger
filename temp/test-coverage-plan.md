# Issue #90: 提升测试覆盖率至 80%+ 执行计划

创建时间: 2026-04-11
目标: 将行覆盖率从 7.66% 提升至 80%+

## 项目规模
- 模型文件: 23 个
- 控制器文件: 23 个
- 服务文件: 16 个
- 当前测试文件: 38 个

## 执行策略

### Phase 1: 核心模型单元测试 (优先级最高)
- [ ] Entry 模型 (核心模型)
- [ ] Account 模型
- [ ] Category 模型
- [ ] Receivable 模型
- [ ] Payable 模型
- [ ] Entryable::Transaction 模型
- [ ] Counterparty 模型

### Phase 2: 控制器测试
- [ ] AccountsController (最复杂，644 行)
- [ ] EntriesController
- [ ] ReceivablesController
- [ ] PayablesController
- [ ] CategoriesController
- [ ] DashboardController

### Phase 3: 服务层测试
- [ ] EntryCreationService
- [ ] AccountDashboardService
- [ ] CacheBuster
- [ ] SystemAccountSyncService
- [ ] Import 服务

### Phase 4: 其他模型和组件
- [ ] 剩余模型
- [ ] 剩余控制器
- [ ] ViewComponents

## 当前进度
正在执行: 准备阶段

## 注意事项
- 使用 ClawTeam 多智能体并行执行
- 每个 agent 负责一个模块
- 确保测试可运行
