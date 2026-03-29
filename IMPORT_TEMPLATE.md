# 贔貅记账导入模板设计

## 数据分析

### 源数据结构
```
日期 | 收支大类 | 交易分类 | 交易类型 | 流入金额 | 流出金额 | 币种 | 资金账户 | 标签 | 备注
```

### 目标系统结构（Ledger Rails App）
```
date | type(INCOME/EXPENSE) | amount | account_id | category_id | note
```

---

## 映射规则

### 1. 交易类型映射
| 源字段 | 目标字段 | 规则 |
|--------|---------|------|
| 流入金额 > 0 | type = INCOME | 收入 |
| 流出金额 > 0 | type = EXPENSE | 支出 |
| 转账 | 特殊处理 | 双向记录或忽略 |

### 2. 金额处理
```ruby
# 优先级：流入 > 流出
amount = 流入金额 > 0 ? 流入金额 : 流出金额
```

### 3. 账户映射
需要创建账户映射表（资金账户 → Account）

**主要账户**（按频率）：
- 支付宝余额 → Alipay
- 微信零钱 → WeChat
- 农行7110 → ABC-7110
- 农行2917 → ABC-2917
- 京东 → JD
- 中信1622 → CITIC-1622
- 中信7431 → CITIC-7431
- 花呗 → Huabei
- 京东白条 → JD-Baitiao
- 拼多多 → Pinduoduo
- 等等...

### 4. 分类映射
**收支大类** → Category（需要创建或匹配）

**主要分类**：
- 吃的 → Food
- 蚁巢成本 → Business Cost
- 闲鱼售出 → Income
- 生活缴费 → Utilities
- 汽车相关 → Transportation
- 装修 → Home Renovation
- 育儿 → Childcare
- 穿的 → Clothing
- 休闲娱乐 → Entertainment
- 数码产品 → Electronics
- 其他收入 → Other Income
- 日用耗品 → Daily Supplies
- 物品购入 → Shopping
- 房贷 → Mortgage
- 等等...

### 5. 特殊处理

#### 转账交易
- **类型**：转账（资金账户 → 资金账户）
- **处理方案**：✅ **双向记录**（推荐）
  - 从源账户创建 EXPENSE 交易
  - 到目标账户创建 INCOME 交易
  - 分类自动设为"转账"
  - 金额相同，便于对账
- **示例**：
  ```
  农行2917 → 支付宝余额 (1000元)
  ↓
  农行2917: -1000 (EXPENSE, 转账)
  支付宝余额: +1000 (INCOME, 转账)
  ```

#### 空分类（7160条）
- 处理：归类为"其他"或"未分类"

#### 多币种
- 目前仅人民币，暂不处理

---

## 导入流程

### 第1步：账户初始化
```ruby
# 创建或匹配账户
accounts_map = {
  "支付宝余额" => Account.find_or_create_by(name: "支付宝"),
  "微信零钱" => Account.find_or_create_by(name: "微信"),
  "农行7110" => Account.find_or_create_by(name: "农行7110"),
  # ... 其他账户
}
```

### 第2步：分类初始化
```ruby
# 创建或匹配分类
categories_map = {
  "吃的" => Category.find_or_create_by(name: "饮食", category_type: "EXPENSE"),
  "蚁巢成本" => Category.find_or_create_by(name: "业务成本", category_type: "EXPENSE"),
  # ... 其他分类
}
```

### 第3步：数据导入
```ruby
# 处理转账
if row['交易类型'] == '转账'
  account_str = row['资金账户']  # "账户A → 账户B"
  parts = account_str.split('→').map(&:strip)
  from_account = accounts_map[parts[0]]
  to_account = accounts_map[parts[1]]
  amount = row['流入金额'] > 0 ? row['流入金额'] : row['流出金额']
  
  # 创建两条交易
  Transaction.create!(type: 'EXPENSE', amount: amount, account: from_account, ...)
  Transaction.create!(type: 'INCOME', amount: amount, account: to_account, ...)
  next
end

# 处理普通交易
if row['流入金额'].to_f > 0
  type = 'INCOME'
  amount = row['流入金额'].to_f
else
  type = 'EXPENSE'
  amount = row['流出金额'].to_f
end

Transaction.create!(
  date: date,
  type: type,
  amount: amount,
  account: account,
  category: category,
  note: note
)
```

---

## 导入前检查清单

- [ ] 备份现有数据
- [ ] 创建所有必需的账户
- [ ] 创建所有必需的分类
- [ ] 测试小批量导入（前100条）
- [ ] 验证日期格式
- [ ] 验证金额精度
- [ ] 检查重复交易
- [ ] 确认转账处理方案

---

## 预期结果

- **总交易数**：~22,000 条
- **有效交易**：~7,000 条（导入）
- **转账交易**：~7,000 条（创建 ~14,000 条记录）
- **总导入记录**：~21,000 条
- **导入时间**：~5-10 分钟
- **数据覆盖**：2026-03-20 至今

---

## 建议

1. **分阶段导入**：按月份导入，便于验证和调试
2. **去重处理**：检查是否有重复交易
3. **数据清洗**：处理异常账户名称（如人名、特殊字符）
4. **备注优化**：合并交易分类 + 备注，便于查询
5. **账户合并**：多个支付宝账户、微信账户可合并

