# 账单金额显示优化

## TL;DR

> **Quick Summary**: 在信用卡账单卡片中添加"账单金额"显示，让用户能看到该期账单的消费总额。
>
> **Deliverables**:
> - 在账单卡片上添加账单金额显示行
>
> **Estimated Effort**: Quick
> **Parallel Execution**: NO - 单文件修改
> **Critical Path**: 单任务

---

## Context

### Original Request
用户希望给每期账单算出账单金额，更醒目地显示。

### Interview Summary
**Key Discussions**:
- 账单金额定义：消费金额 (spend_amount) - 该期账单周期内的消费总额
- 当前已有数据：后端已返回 spend_amount, repay_amount, balance_due
- 显示方式：在卡片标题下方新增醒目的账单金额显示

**Research Findings**:
- 后端 accounts_controller.rb 的 bills 方法已返回账单数据
- 前端 renderBillCards 函数（约第 2492-2569 行）渲染账单卡片
- 当前显示：消费&取现金额、还款&退款金额、待还金额

---

## Work Objectives

### Core Objective
优化信用卡账单卡片显示，让账单金额（消费金额）更加醒目。

### Concrete Deliverables
- 修改后的 app/views/accounts/index.html.erb

### Definition of Done
- [ ] 账单卡片显示醒目的账单金额
- [ ] 页面无 JS 错误

### Must Have
- 账单金额使用醒目字体和颜色显示
- 保留还款金额和笔数统计信息

### Must NOT Have (Guardrails)
- 不要修改后端数据返回逻辑（已有数据）
- 不要删除原有的账期、还款日等信息

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: NO（前端 JS 修改，无需单元测试）
- **Automated tests**: None
- **Agent-Executed QA**: YES - 手动测试

### QA Policy
每任务包含 Agent-Executed QA 场景。

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Single task):
└── Task 1: 优化账单卡片显示 [quick]
```

### Dependency Matrix
- **1**: 无依赖

### Agent Dispatch Summary
- **1**: `quick` - 单文件修改

---

## TODOs

- [ ] 1. 优化账单卡片显示

  **What to do**:
  - 修改 renderBillCards 函数
  - 在卡片标题后新增醒目账单金额行（text-lg font-bold text-expense）
  - 底部简化为还款金额和笔数统计

  **Must NOT do**:
  - 不要修改后端代码
  - 不要删除账期、还款日等原有信息

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (Single)
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `app/views/accounts/index.html.erb:2531-2544` - 当前金额汇总显示位置
  - 后端返回数据：`bill.spend_amount`, `bill.repay_amount`, `bill.spend_count`, `bill.repay_count`

  **Acceptance Criteria**:
  - [ ] 账单金额醒目显示（大字体、红色）
  - [ ] 还款金额和笔数统计显示正确

  **QA Scenarios**:
  ```
  Scenario: 账单金额显示正常
    Tool: Bash (curl)
    Preconditions: 有信用卡账户且有账单数据
    Steps:
      1. 访问信用卡账户页面
      2. 切换到账单模式
      3. 检查账单卡片显示
    Expected Result: 账单金额醒目显示，格式正确
    Evidence: .sisyphus/evidence/task-1-bill-display.txt

  Scenario: 数据格式正确
    Tool: Playwright
    Preconditions: 有账单数据
    Steps:
      1. 打开浏览器访问账单页面
      2. 截图验证显示效果
    Expected Result: 账单金额用大字体红色显示
    Evidence: .sisyphus/evidence/task-1-screenshot.png
  ```

  **Commit**: YES
  - Message: `feat: 优化账单金额醒目显示`
  - Files: `app/views/accounts/index.html.erb`

---

## Final Verification Wave

- [ ] F1. **Plan Compliance Audit** — `oracle`
  验证账单金额醒目显示，无 JS 错误。

- [ ] F2. **Code Quality Review** — `unspecified-high`
  检查代码风格，无 console.log，无多余注释。

---

## Success Criteria

### Verification Commands
```bash
# 检查页面无 JS 错误（手动验证）
```

### Final Checklist
- [ ] 账单金额醒目显示
- [ ] 页面无 JS 错误