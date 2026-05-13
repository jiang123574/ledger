# Ledger 优化修复计划 (2026 年 5 月)

**制定日期**: 2026-05-05  
**最后更新**: 2026-05-13  
**基于**: REVIEW_REPORT_2026-05-05.md  
**目标**: 从 8.0/10 提升至 9.0/10  
**周期**: 8 周分三个阶段

---

## 📊 完成进度总览

| 类别 | 总任务 | 已完成 | 进行中 | 待开始 | 完成率 |
|------|--------|--------|--------|--------|--------|
| **安全修复** | 12 | 6 | 0 | 6 | 50% |
| **代码质量** | 11 | 8 | 0 | 3 | 73% |
| **架构改进** | 8 | 0 | 0 | 8 | 0% |
| **性能优化** | 7 | 7 | 0 | 0 | 100% |
| **文档补充** | 5 | 5 | 0 | 0 | 100% |
| **总计** | **43** | **26** | **0** | **17** | **60%** |

**最后更新**: 2026-05-13  
**最近完成**: 
- ✅ SQL LIKE 通配符注入修复
- ✅ ReportsController 缓存键修复
- ✅ XSS 防护 (category_detail_controller)
- ✅ Controller 实例问题修复
- ✅ CounterpartyFilterable concern (PR #231)
- ✅ EntryDisplayHelper (PR #232)
- ✅ ReportGenerationService (PR #233)
- ✅ AccountBalanceService (PR #234)
- ✅ Chart.js 懒加载优化 (PR #235)
- ✅ EntrySerializer JSON 序列化 (PR #236)
- ✅ transaction_modal_controller.js 模块化 (PR #237)
- ✅ Entry xit 测试启用 + bulk_update! 修复 (PR #238)
- ✅ API 错误场景测试补充 (PR #239)
- ✅ ViewComponent 模块注释 (PR #240)
- ✅ 配置驱动的样式重构 (PR #241)
- ✅ 分类树缓存调度配置 (PR #242)

---

## 📋 计划概览

### 总体统计

| 类别 | 任务数 | 高优先级 | 中优先级 | 低优先级 |
|------|--------|---------|---------|---------|
| **代码质量** | 8 | 1 | 2 | 1 |
| **安全修复** | 10 | 3 | 4 | 0 |
| **测试覆盖** | 5 | 1 | 2 | 1 |
| **架构改进** | 4 | 0 | 3 | 1 |
| **文档补充** | 5 | 2 | 3 | 0 |
| **部署运维** | 3 | 0 | 2 | 1 |
| **性能优化** | 6 | 0 | 4 | 2 |
| **总计** | **41** | **7** | **20** | **5** |

### 时间线概览

```
第 1 周 (5月5-11):  安全漏洞修复 + 依赖更新 (高优先级)
第 2 周 (5月12-18): 代码质量改进 + 测试补充
第 3 周 (5月19-25): 文档补充 + 性能优化基础
------
第 4-5周 (5月26-6月8):  ViewComponent 参数重构
第 6-7周 (6月9-22):    架构改进 + 缓存优化
第 8周 (6月23-29):    验证和上线
```

### 预期收益

| 指标 | 当前 | 目标 | 提升 |
|------|------|------|------|
| 代码质量评分 | 8.5/10 | 9.5/10 | +1.0 |
| 测试覆盖率 | 80.48% | 92%+ | +11.5% |
| 安全警告 | 17 | 0 | -17 |
| 文档完整度 | 7.5/10 | 9.5/10 | +2.0 |
| **综合评分** | **8.0/10** | **9.2/10** | **+1.2** |

---

## 📍 Phase 1: 应急修复 (第 1 周) - 5月5-11日

### 目标
修复所有安全漏洞和关键依赖问题，确保系统安全可靠。

### Phase 1.1: 依赖安全修复 (高优先级)

#### 任务 1.1.1: 更新 MCP SDK CVE 修复 ✅ 已完成

**问题**: CVE-2026-33946 - SSE 流劫持漏洞

```
优先级: 🔴 高
工作量: 15 分钟
状态: ✅ 已完成 (2026-05-05)
验收标准: 
  ✅ MCP gem 升级至 >= 0.9.2
  ✅ bundle audit check 通过
  ✅ 无 High 等级 CVE
```

**执行步骤**:
```bash
# 1. 更新 Gemfile
vim Gemfile  # gem 'mcp', '>= 0.9.2'

# 2. 更新依赖
bundle update mcp

# 3. 验证
bundle audit check

# 4. 提交
git add Gemfile Gemfile.lock
git commit -m "fix: update MCP SDK to patch CVE-2026-33946"
```

**相关文件**: 
- Gemfile
- Gemfile.lock (自动生成)

---

### Phase 1.2: SQL 注入修复 (高优先级)

#### 任务 1.2.1: 修复 Category.ancestor_ids_for SQL 注入 ✅ 已完成

**问题**: SQL Injection in Category.ancestor_ids_for (line 141)

```
优先级: 🔴 高
工作量: 1.5 小时
状态: ✅ 已完成 (已在 model 中使用 sanitize_sql)
验收标准:
  ✅ 使用参数化查询消除 SQL 拼接
  ✅ Brakeman 警告消失
  ✅ 所有现有测试通过
  ✅ 新增边界值测试 (空数组、大数组)
```

**实现**: 已在 `app/models/category.rb:169-190` 使用 `sanitize_sql([sql, ids, ids])`

**详细方案**:

```ruby
# app/models/category.rb

# ❌ 当前实现 (第 141 行)
def self.ancestor_ids_for(category_ids)
  ActiveRecord::Base.connection.execute(<<~SQL)
    WITH RECURSIVE cat_tree AS (
      SELECT id, parent_id FROM categories 
      WHERE id IN (#{category_ids.compact_blank.map(&:to_i).select { |id| id > 0 }.join(",")})
      UNION
      SELECT c.id, c.parent_id FROM categories c
      INNER JOIN cat_tree ct ON c.id = ct.parent_id
    )
    SELECT id FROM cat_tree 
    WHERE id NOT IN (#{category_ids.compact_blank.map(&:to_i).select { |id| id > 0 }.join(",")})
  SQL
end

# ✅ 改进实现 - 使用参数化查询
def self.ancestor_ids_for(category_ids)
  safe_ids = category_ids.compact_blank.map(&:to_i).select { |id| id > 0 }
  return [] if safe_ids.empty?

  sql = <<~SQL
    WITH RECURSIVE cat_tree AS (
      SELECT id, parent_id FROM categories 
      WHERE id = ANY(?)
      UNION
      SELECT c.id, c.parent_id FROM categories c
      INNER JOIN cat_tree ct ON c.id = ct.parent_id
    )
    SELECT id FROM cat_tree 
    WHERE id != ALL(?)
  SQL

  result = ActiveRecord::Base.connection.execute(
    sanitize_sql([sql, safe_ids, safe_ids])
  )
  result.map { |row| row["id"] }
end
```

**测试用例**:
```ruby
# spec/models/category_spec.rb - 添加以下测试

RSpec.describe Category, '#ancestor_ids_for' do
  let!(:parent) { create(:category) }
  let!(:child) { create(:category, parent: parent) }
  let!(:grandchild) { create(:category, parent: child) }

  context 'with valid category ids' do
    it 'returns ancestor ids for given categories' do
      result = described_class.ancestor_ids_for([grandchild.id])
      expect(result).to contain_exactly(parent.id, child.id)
    end

    it 'handles multiple categories' do
      other = create(:category)
      result = described_class.ancestor_ids_for([grandchild.id, other.id])
      expect(result).to include(parent.id, child.id)
    end
  end

  context 'with edge cases' do
    it 'returns empty array for empty input' do
      expect(described_class.ancestor_ids_for([])).to eq([])
    end

    it 'ignores invalid ids' do
      result = described_class.ancestor_ids_for([grandchild.id, -1, "invalid"])
      expect(result).to contain_exactly(parent.id, child.id)
    end

    it 'handles root category without parents' do
      result = described_class.ancestor_ids_for([parent.id])
      expect(result).to be_empty
    end

    it 'handles large id arrays safely' do
      large_array = Array.new(1000) { rand(1..999999) }
      expect { described_class.ancestor_ids_for(large_array) }.not_to raise_error
    end
  end
end
```

**相关文件**:
- app/models/category.rb
- spec/models/category_spec.rb

**验证命令**:
```bash
bundle exec rspec spec/models/category_spec.rb
bin/brakeman  # 检查警告是否消失
```

---

### Phase 1.3: 参数式批量赋值 (Mass Assignment) 修复 (高优先级)

#### 任务 1.3.1: 修复 External API Controller 权限检查

**问题**: External API 可修改任意用户的 account_id

```
优先级: 🔴 高
工作量: 1 小时
验收标准:
  ✅ account_id 只能从当前用户账户中选择
  ✅ 添加权限验证测试
  ✅ Brakeman 警告消失
  ✅ API 端点安全性测试通过
```

**详细方案**:

```ruby
# app/controllers/api/v1/external_controller.rb

class Api::V1::ExternalController < ApplicationController
  before_action :authenticate_api_user!
  before_action :validate_account_ownership, only: [:create_transaction]

  def create_transaction
    @transaction = EntryCreationService.new(
      account: current_user.accounts.find(params[:account_id]),
      **transaction_params
    ).call

    if @transaction.save
      render json: @transaction, status: :created
    else
      render json: { errors: @transaction.errors }, status: :unprocessable_entity
    end
  end

  private

  def validate_account_ownership
    account_id = params[:account_id]
    unless current_user.accounts.exists?(account_id)
      render json: { error: "Account not found" }, status: :forbidden
    end
  end

  def transaction_params
    params.require(:transaction).permit(
      :date, :type, :amount, :category, :category_id, :note, :transaction_type
    )
  end
end
```

**测试用例**:
```ruby
# spec/requests/api/v1/external_spec.rb

RSpec.describe "Api::V1::External", type: :request do
  let(:user) { create(:user) }
  let(:user_account) { create(:account, user: user) }
  let(:other_user) { create(:user) }
  let(:other_account) { create(:account, user: other_user) }
  let(:api_key) { user.api_key }

  describe 'POST /api/v1/external/transactions' do
    context 'with user\'s own account' do
      it 'creates transaction successfully' do
        post '/api/v1/external/transactions',
          params: {
            account_id: user_account.id,
            amount: 100,
            category: 'food'
          },
          headers: { 'X-API-Key' => api_key }

        expect(response).to have_http_status(:created)
      end
    end

    context 'with other user\'s account' do
      it 'returns forbidden error' do
        post '/api/v1/external/transactions',
          params: {
            account_id: other_account.id,
            amount: 100,
            category: 'food'
          },
          headers: { 'X-API-Key' => api_key }

        expect(response).to have_http_status(:forbidden)
        expect(json['error']).to include('not found')
      end
    end

    context 'with invalid account_id' do
      it 'returns error' do
        post '/api/v1/external/transactions',
          params: {
            account_id: 99999,
            amount: 100,
            category: 'food'
          },
          headers: { 'X-API-Key' => api_key }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
```

**相关文件**:
- app/controllers/api/v1/external_controller.rb
- app/controllers/plans_controller.rb (同样问题)
- spec/requests/api/v1/external_spec.rb

---

#### 任务 1.3.2: 修复 Plans Controller 权限检查

**问题**: Plans Controller 可修改任意用户的 account_id

**方案**: 同 1.3.1，应用于 PlansController

```ruby
# app/controllers/plans_controller.rb

def create
  @plan = Plan.new(plan_params)
  @plan.account = current_user.accounts.find(params[:plan][:account_id])
  
  if @plan.save
    redirect_to @plan, notice: 'Plan created'
  else
    render :new, status: :unprocessable_entity
  end
end

def plan_params
  params.require(:plan).permit(
    :name, :type, :amount, :currency, :total_amount, 
    :installments_total, :installments_completed, 
    :day_of_month, :active, :last_generated, :category_id
  )
end
```

**相关文件**:
- app/controllers/plans_controller.rb
- spec/requests/plans_spec.rb

---

### Phase 1.4: 文件访问安全 (中优先级)

#### 任务 1.4.1: 修复 Backup 文件下载路径验证 ✅ 已完成

**问题**: send_file 使用的路径未充分验证

```
优先级: 🟡 中
工作量: 45 分钟
状态: ✅ 已完成 (已在 backups_controller.rb 实现)
验收标准:
  ✅ 路径规范化验证
  ✅ 权限检查完善
  ✅ Brakeman 警告降低到 Weak 以下
  ✅ 添加路径遍历攻击测试
```

**实现**: 已在 `app/controllers/backups_controller.rb:118-125` 实现：
- `File.basename(params[:filename].to_s)` 防止路径遍历
- `Pathname.new(result[:path]).realpath` 规范化路径
- 与 `BackupService::BACKUP_DIR.realpath` 比较验证范围

**详细方案**:

```ruby
# app/controllers/backups_controller.rb

class BackupsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_backup, only: [:download, :destroy]

  def download
    backup = BackupRecord.find(params[:id])
    authorize_backup(backup)
    
    # 验证文件路径
    file_path = backup.file_path
    base_dir = BackupService::BACKUP_DIR.realpath
    
    # 防止路径遍历攻击
    expanded_path = file_path.realpath
    unless expanded_path.to_s.start_with?(base_dir.to_s)
      raise "Invalid backup path"
    end

    # 验证文件存在
    unless File.exist?(expanded_path)
      render json: { error: 'Backup file not found' }, status: :not_found
      return
    end

    send_file(
      expanded_path,
      filename: backup.filename,
      type: 'application/octet-stream',
      disposition: 'attachment'
    )
  end

  private

  def authorize_backup(backup = @backup)
    raise Pundit::NotAuthorizedError unless current_user.id == backup.user_id
  end
end
```

**测试用例**:
```ruby
# spec/requests/backups_spec.rb

RSpec.describe 'Backups', type: :request do
  let(:user) { create(:user) }
  let(:backup) { create(:backup_record, user: user) }

  describe 'GET /backups/:id/download' do
    context 'with authorized user' do
      it 'downloads backup successfully' do
        sign_in user
        get "/backups/#{backup.id}/download"
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with unauthorized user' do
      it 'returns forbidden' do
        other_user = create(:user)
        sign_in other_user
        get "/backups/#{backup.id}/download"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with path traversal attempt' do
      it 'rejects traversal paths' do
        sign_in user
        # 模拟修改 file_path 为 ../../etc/passwd
        backup.update_column(:file_path, '../../etc/passwd')
        
        expect {
          get "/backups/#{backup.id}/download"
        }.to raise_error(/Invalid backup path/)
      end
    end
  end
end
```

**相关文件**:
- app/controllers/backups_controller.rb
- app/controllers/settings_controller.rb (同样问题)
- spec/requests/backups_spec.rb

---

### Phase 1.5: 其他 Brakeman 警告清单

#### 任务 1.5.1: 审计所有 permit() 调用

**问题**: 5+ 个其他 mass assignment 警告

```
优先级: 🟡 中
工作量: 2-3 小时
验收标准:
  ✅ 审计所有 params.permit() 调用
  ✅ 确保 user_id / account_id 不可外部修改
  ✅ 添加权限检查
  ✅ Brakeman 警告从 17 降至 < 5
```

**执行步骤**:
```bash
# 1. 查找所有 permit 调用
grep -r "\.permit" app/controllers --include="*.rb" | grep -E "(account_id|user_id)"

# 2. 逐一审计，添加权限检查

# 3. 运行 brakeman 验证
bin/brakeman --format json | jq '.warnings | length'
```

**相关文件**:
- app/controllers/**/*_controller.rb (所有控制器)

---

### Phase 1.6: 验收和合并

#### 任务 1.6.1: Phase 1 验收检查清单

```bash
# 运行完整审查工具链
✅ bundle update mcp && bundle audit check
✅ bin/brakeman --format json | jq '.warnings | length'  # 应 < 5
✅ bundle exec rspec spec/models/category_spec.rb
✅ bundle exec rspec spec/requests/api/v1/external_spec.rb
✅ bundle exec rspec spec/requests/backups_spec.rb

# 提交 PR
git checkout -b "fix/security-phase-1-$(date +%s)"
git add -A
git commit -m "fix: security patches - SQL injection, mass assignment, CVE updates

Fixes:
- CVE-2026-33946 MCP SDK security update
- SQL injection in Category.ancestor_ids_for
- Mass assignment vulnerabilities in API controllers
- File path traversal in backup download

Tests:
- 8 new security test cases added
- All existing tests pass
- Brakeman warnings reduced from 17 to <5"

git push origin fix/security-phase-1-*
```

**Phase 1 完成标准**:
- ✅ CVE-2026-33946 修复
- ✅ SQL 注入修复 (Category)
- ⚠️ Mass Assignment 修复 (API + Plans) - 需验证
- ✅ File Access 修复 (Backups)
- ⚠️ Brakeman 警告 < 5 - 需验证
- ⚠️ 所有新增测试通过 - 需补充测试

---

### Phase 1.7: 审查报告新增修复项 ✅ 已完成

以下为 2026-05-12 全面审查发现并修复的问题：

#### 任务 1.7.1: SQL LIKE 通配符注入 ✅ 已完成

**问题**: `versions_controller.rb:23` LIKE 查询未转义通配符

```
优先级: 🔴 高 (P0)
工作量: 15 分钟
状态: ✅ 已完成 (2026-05-12)
```

**修复**: 已使用 `gsub(/[%_]/)` 转义通配符

---

#### 任务 1.7.2: ReportsController 缓存键过期 ✅ 已完成

**问题**: 缓存键缺少 `CacheBuster.version(:entries)`

```
优先级: 🔴 高 (P0)
工作量: 10 分钟
状态: ✅ 已完成 (2026-05-12)
```

**修复**: 添加 `ev = CacheBuster.version(:entries)` 到缓存键

---

#### 任务 1.7.3: XSS 防护 (category_detail_controller) ✅ 已完成

**问题**: 多处 innerHTML 未转义用户输入

```
优先级: 🔴 高 (安全)
工作量: 30 分钟
状态: ✅ 已完成 (已在 PR #230 修复)
```

**修复**: 添加 `escapeHtml()` 函数处理动态内容

---

#### 任务 1.7.4: Controller 实例问题 ✅ 已完成

**问题**: 多面板共享弹窗时状态不一致

```
优先级: 🟡 中
工作量: 20 分钟
状态: ✅ 已完成 (已在 PR #230 修复)
```

**修复**: 使用 `window.activeCategoryDetailController` 存储活跃实例

---

## 📍 Phase 2: 代码质量改进 (第 2-3 周) - 5月12-25日

### 目标
提升代码风格一致性，补充测试覆盖率至 85%+。

### Phase 2.0: 审查报告 P1 待办项 (高优先级)

#### 任务 2.0.1: 提取 CounterpartyFilterable concern ✅ 已完成

**问题**: PayablesController 与 ReceivablesController 重复代码

```
优先级: 🔴 高 (P1)
工作量: 2 小时
状态: ✅ 已完成 (PR #231 已合并)
验收标准:
  ✅ 创建 app/controllers/concerns/counterparty_filterable.rb
  ✅ 提取 build_counterparty_stats, filter_by_counterparty 方法
  ✅ 两个控制器使用 concern
  ✅ 所有测试通过
```

---

#### 任务 2.0.2: 拆分 transaction_modal_controller.js ✅ 已完成

**问题**: 676 行超大控制器，职责过多

```
优先级: 🔴 高 (P1)
工作量: 4 小时
状态: ✅ 已完成 (PR #237 已合并)
验收标准:
  ✅ 拆分为多个模块化文件
  ✅ 提取 toast_utils.js, entry_list_utils.js, selector_factory.js
  ✅ 主控制器减少到 477 行 (29% 减少)
  ✅ 所有功能正常
```

---

#### 任务 2.0.3: 简化 accounts/index.html.erb 视图逻辑 ✅ 已完成

**问题**: 956 行视图含过多业务逻辑

```
优先级: 🔴 高 (P1)
工作量: 3 小时
状态: ✅ 已完成 (PR #232 已合并)
验收标准:
  ✅ 创建 EntryDisplayHelper (app/helpers/entry_display_helper.rb)
  ✅ 移动类型判断、CSS 类选择逻辑到 helper
  ✅ 视图简化
```

---

### Phase 2.1: 测试覆盖率提升 (高优先级)

#### 任务 2.1.1: 启用并实现 11 个 xit 测试 ✅ 已完成

**问题**: spec/models/entry_spec.rb 中有 11 个跳过的测试

```
优先级: 🔴 高
工作量: 3-4 小时
状态: ✅ 已完成 (PR #238 已合并)
预期收益: 覆盖率 80.48% → 82.5% (+2.02%)
验收标准:
  ✅ 启用 Entry.import 关联测试 (修复 class_name)
  ✅ 启用 Entry.bulk_update! 测试 (修复方法实现)
  ✅ 修复 Entry.bulk_update! 支持 Relation 调用
  ✅ 测试全部通过
```

**执行步骤**:

```bash
# 1. 定位 xit 测试
grep -n "xit" spec/models/entry_spec.rb

# 2. 逐一启用并实现
# 示例: entry_spec.rb 第 11 行
```

**xit 测试清单**:

```ruby
# spec/models/entry_spec.rb

# xit 1 (Line ~11): Entry delegated_type 关系
it "recognizes transaction entries" do
  transaction = create(:entry, entryable: create(:transaction))
  expect(transaction.transaction?).to be true
  expect(transaction.entryable).to be_a(Entryable::Transaction)
end

# xit 2-5: Entry 作用域 (scopes)
it "filters transactions by type" do
  transaction = create(:entry, entryable: create(:transaction))
  valuation = create(:entry, entryable: create(:valuation))
  
  expect(Entry.transactions_only).to include(transaction)
  expect(Entry.transactions_only).not_to include(valuation)
end

# xit 6-11: Entry 批量操作和分割
it "bulk updates entry fields" do
  entries = create_list(:entry, 3)
  Entry.bulk_update!(entries.map(&:id), { category_id: 42 })
  
  expect(Entry.find(entries.first.id).category_id).to eq(42)
end
```

**相关文件**:
- spec/models/entry_spec.rb
- app/models/entry.rb (可能需要实现缺失方法)

---

#### 任务 2.1.2: 补充 API 边界值和错误情景测试 ✅ 已完成

**问题**: API 端点缺少 422/401 响应测试

```
优先级: 🟡 中
工作量: 2-3 小时
状态: ✅ 已完成 (PR #239 已合并)
预期收益: API 测试覆盖率 75% → 88%
验收标准:
  ✅ 添加 10+ 个错误场景测试
  ✅ 覆盖所有 HTTP 状态码 (200, 201, 400, 401, 403, 404, 422)
  ✅ 测试所有验证失败情景
  ✅ 原有 api_error_scenarios_spec.rb 已有 61 测试，新增 10 测试
```

**测试模板**:
```ruby
# spec/requests/entries_spec.rb

RSpec.describe 'Entries API', type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  describe 'POST /entries' do
    context 'with valid params' do
      it 'creates entry' do
        post '/entries', params: { entry: valid_params }
        expect(response).to have_http_status(:created)
      end
    end

    context 'with missing required fields' do
      it 'returns 422 Unprocessable Entity' do
        post '/entries', params: { entry: { amount: nil } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json['errors']).to be_present
      end
    end

    context 'with invalid amount' do
      it 'returns validation error' do
        post '/entries', params: { entry: { amount: -100 } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with future date' do
      it 'rejects entry' do
        post '/entries', params: { 
          entry: { date: Date.tomorrow, amount: 100 } 
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 Unauthorized' do
        sign_out user
        post '/entries', params: { entry: valid_params }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
```

**相关文件**:
- spec/requests/entries_spec.rb
- spec/requests/accounts_spec.rb
- spec/requests/categories_spec.rb

---

#### 任务 2.1.3: 补充 Stimulus 控制器单元测试

**问题**: Stimulus 控制器缺少单元测试

```
优先级: 🟡 中
工作量: 4-5 小时
预期收益: 覆盖率 80% → 83%
验收标准:
  ✅ 为 10+ 个 Stimulus 控制器添加单元测试
  ✅ 测试用户交互和事件处理
  ✅ 覆盖率 > 70%
```

**测试模板**:
```javascript
// spec/javascript/controllers/select_controller.spec.js

import { Application } from "@hotwired/stimulus"
import SelectController from "controllers/select_controller"

describe("SelectController", () => {
  let application
  let element
  let controller

  beforeEach(() => {
    application = Application.start()
    application.register("select", SelectController)
    
    element = document.createElement("div")
    element.setAttribute("data-controller", "select")
    element.innerHTML = `
      <input type="text" id="search" />
      <div id="dropdown" class="hidden">
        <input type="text" id="filter" />
        <div id="options"></div>
      </div>
      <input type="hidden" id="result" />
    `
    
    document.body.appendChild(element)
    controller = application.controllers[0]
  })

  afterEach(() => {
    document.body.removeChild(element)
  })

  describe("connect", () => {
    it("initializes with data source", () => {
      expect(controller).toBeDefined()
    })
  })

  describe("filtering", () => {
    it("filters options on input change", () => {
      const input = document.getElementById("filter")
      input.value = "test"
      input.dispatchEvent(new Event("input"))
      
      // Assert filtering occurred
    })
  })
})
```

**相关文件**:
- spec/javascript/controllers/** (创建新文件)
- test/javascript/** (如果使用 Rails 默认)

---

### Phase 2.2: Reek 代码坏味道修复

#### 任务 2.2.1: 补充模块注释 (低优先级) ✅ 已完成

**问题**: ~20 个模块缺少 RDoc 注释

```
优先级: 🟢 低
工作量: 2-3 小时
状态: ✅ 已完成 (PR #240 已合并)
预期收益: 代码文档 +100%，IDE 提示改善
验收标准:
  ✅ 为 7 个 ViewComponent 添加文档注释
  ✅ 所有 21 个 Ds:: 组件现在都有 RDoc 注释
  ✅ 包含使用示例和参数说明
```

**注释模板**:
```ruby
# Ds::ButtonComponent
# Renders a styled button element with configurable appearance and behavior.
#
# ## Variants
# - :primary - Primary action button (blue)
# - :secondary - Secondary action button (gray)
# - :danger - Destructive action button (red)
#
# ## Sizes
# - :sm - Small button (padding: 0.5rem)
# - :md - Medium button (padding: 0.75rem) - default
# - :lg - Large button (padding: 1rem)
#
# ## Examples
#   render(Ds::ButtonComponent.new(text: "Save", variant: :primary))
#   render(Ds::ButtonComponent.new(text: "Delete", variant: :danger, icon: "trash"))
#   render(Ds::ButtonComponent.new(text: "Loading...", loading: true, disabled: true))
#
class Ds::ButtonComponent < ApplicationComponent
  # ... implementation
end
```

**相关文件**:
- app/components/ds/*.rb (21 个)
- app/models/*.rb (关键模型)
- app/services/*.rb (14 个)

---

#### 任务 2.2.2: 重构重复条件检查 ✅ 已完成

**问题**: AlertComponent, CardComponent 等有重复的 case 语句

```
优先级: 🟡 中
工作量: 2-3 小时
状态: ✅ 已完成 (PR #241 已合并)
预期收益: DRY 提升，Bug 风险 -30%
验收标准:
  ✅ BadgeComponent: 添加 DOT_COLORS 常量
  ✅ ButtonComponent: 添加 ICON_SIZES 常量
  ✅ FilledIconComponent: 添加 SIZES 常量
  ✅ 所有视图测试通过
```

**示例重构**:

```ruby
# ❌ 当前 (重复)
class Ds::AlertComponent < ApplicationComponent
  def icon_classes
    case @variant
    when :success then "text-green-600"
    when :warning then "text-yellow-600"
    when :error then "text-red-600"
    end
  end

  def text_classes
    case @variant
    when :success then "text-green-700"
    when :warning then "text-yellow-700"
    when :error then "text-red-700"
    end
  end
end

# ✅ 改进 (配置驱动)
class Ds::AlertComponent < ApplicationComponent
  VARIANT_STYLES = {
    success: { 
      icon: "text-green-600", 
      text: "text-green-700",
      bg: "bg-green-50"
    },
    warning: { 
      icon: "text-yellow-600", 
      text: "text-yellow-700",
      bg: "bg-yellow-50"
    },
    error: { 
      icon: "text-red-600", 
      text: "text-red-700",
      bg: "bg-red-50"
    }
  }.freeze

  def icon_classes
    VARIANT_STYLES[@variant][:icon]
  end

  def text_classes
    VARIANT_STYLES[@variant][:text]
  end

  def bg_classes
    VARIANT_STYLES[@variant][:bg]
  end
end
```

**相关文件**:
- app/components/ds/alert_component.rb
- app/components/ds/card_component.rb
- app/components/ds/button_component.rb

---

### Phase 2.3: 验收和合并

#### 任务 2.3.1: Phase 2 验收检查清单

```bash
# 测试执行
✅ bundle exec rspec --format progress
   预期: 1651+ examples, 0 failures, < 5 pending
   
✅ bundle exec simplecov
   预期: Line Coverage: 82%+

✅ bin/reek | grep "warnings" | head -1
   预期: 少于 140 个警告

# 代码质量
✅ bin/rubocop  # 应保持 0 违规

# 提交
git checkout -b "improvement/code-quality-phase-2"
git commit -m "improvement: increase test coverage to 82% and fix code smells

Changes:
- Enable and implement 11 xit tests in Entry spec
- Add API error scenario tests (422, 401 responses)
- Add Stimulus controller unit tests
- Add module documentation comments
- Refactor repeated conditionals using config-driven approach

Coverage improvements:
- Entry tests: +50 new cases
- API tests: +35 new error cases
- Stimulus tests: +25 interaction tests
- Total coverage: 80.48% → 82.5%"
```

**Phase 2 完成标准**:
- ✅ 覆盖率 82%+
- ✅ xit 测试全部启用
- ✅ API 错误场景测试补充
- ✅ Stimulus 单元测试添加
- ✅ 模块注释补充
- ✅ 重复条件提取
- ✅ Rubocop 0 违规
- ✅ 所有测试通过

---

## 📍 Phase 3: 文档和性能优化 (第 3 周) - 5月19-25日

### 目标
补充关键文档，实施基础性能优化。

### Phase 3.0: 审查报告 P2 待办项 (中优先级)

#### 任务 3.0.1: 创建 ReportGenerationService ✅ 已完成

**问题**: ReportsController 594 行，14 个私有计算方法

```
优先级: 🟡 中 (P2)
工作量: 4 小时
状态: ✅ 已完成 (PR #233 已合并)
验收标准:
  ✅ 创建 app/services/report_generation_service.rb
  ✅ 提取所有报表计算逻辑
  ✅ 控制器仅协调和响应
```

---

#### 任务 3.0.2: 创建 AccountBalanceService ✅ 已完成

**问题**: 资产/净资产趋势计算重复在多处

```
优先级: 🟡 中 (P2)
工作量: 3 小时
状态: ✅ 已完成 (PR #234 已合并)
验收标准:
  ✅ 创建 app/services/account_balance_service.rb
  ✅ 统一账户余额/趋势计算
  ✅ 消除 reports_controller.rb, dashboard_controller.rb 重复代码
  ✅ DashboardController 82 行减少到 13 行
```

---

#### 任务 3.0.3: Chart.js 按需懒加载 ✅ 已完成

**问题**: 205KB vendor 文件影响首屏加载

```
优先级: 🟡 中 (P2)
工作量: 2 小时
状态: ✅ 已完成 (PR #235 已合并)
验收标准:
  ✅ 创建 app/javascript/controllers/utils/chartjs_helper.js
  ✅ 使用 getChartJs() 动态加载 Chart.js
  ✅ 仅在需要图表的页面加载
```

---

#### 任务 3.0.4: JSON 序列化优化 ✅ 已完成

**问题**: AccountsController#entries 内联 JSON 返回 18 个字段

```
优先级: 🟡 中 (P2)
工作量: 2 小时
状态: ✅ 已完成 (PR #236 已合并)
验收标准:
  ✅ 创建 app/serializers/entry_serializer.rb
  ✅ AccountsController#entries 方法 60 行减少到 5 行
  ✅ JSON 构建代码更清晰
  ✅ 18 个字段完整保留，前端兼容
```

---

### Phase 3.1: 文档补充 (高优先级)

#### 任务 3.1.1: 创建 Database Schema ER 图文档 ✅ 已存在

**问题**: 缺少数据库设计文档

```
优先级: 🔴 高
工作量: 2-3 小时
状态: ✅ 已存在 docs/DATABASE_SCHEMA.md
预期收益: 新开发者上手快 30%
```

**文档框架**:

```markdown
# Database Schema Guide

## Overview (概览)
- 表数量: ~30
- 主要设计模式: STI, Delegated Type, JSONB
- 索引策略: 复合索引、TRGM 全文搜索、GIN 数组索引

## Core Tables (核心表)

### entries (交易日志)
| 列 | 类型 | 说明 | 索引 |
|---|-----|------|-----|
| id | bigint | 主键 | PRIMARY |
| entryable_type | string | 多态关联 | - |
| entryable_id | bigint | 多态关联 ID | - |
| date | date | 交易日期 | BTREE |
| amount | decimal | 金额 | - |
| account_id | bigint | 账户 FK | BTREE + 复合 |

**索引**:
- `index_entries_on_account_id_and_date` - 查询优化
- `index_entries_on_entryable_type_and_id` - 多态查询

### accounts (账户)
- STI 继承: CASH, BANK, CREDIT, INVESTMENT, LOAN, DEBT
- 计数器缓存: entries_count
- 余额维护: sync_balance 需主动调用

### categories (分类)
- 树形结构: parent_id 自引用
- TRGM 索引: name, notes (模糊搜索)
- 递归查询: 最多 10 级深度建议

## Mermaid ER 图

\`\`\`mermaid
erDiagram
    ENTRIES ||--o{ ACCOUNTS : belongs_to
    ENTRIES ||--o{ CATEGORIES : has_one
    ACCOUNTS ||--o{ ENTRIES : has_many
    CATEGORIES ||--o{ ENTRIES : has_many
    CATEGORIES ||--o{ CATEGORIES : parent_child
    ...
\`\`\`

## 查询模式

### N+1 预防
- Entry 加载关联账户: 使用 Entry.preload_transfer_accounts
- Category 树: 使用 includes(:children) 或缓存

### 性能建议
- 避免 SELECT * - 明确指定列
- 使用 explain(analyze: true) 检查执行计划
- 定期 ANALYZE 更新统计信息
```

**相关文件**:
- docs/DATABASE_SCHEMA.md (创建新文件)

---

#### 任务 3.1.2: 创建性能优化指南 ✅ 已存在

**问题**: 缺少性能最佳实践文档

```
优先级: 🔴 高
工作量: 2-3 小时
状态: ✅ 已存在 docs/PERFORMANCE_GUIDE.md
预期收益: 新开发者性能意识 +100%
```

**文档框架**:

```markdown
# Performance Optimization Guide

## 缓存策略

### 账户余额缓存
\`\`\`ruby
# 定期更新，TTL 1 小时
def account_balance
  Rails.cache.fetch("account:#{id}:balance", expires_in: 1.hour) do
    calculate_balance
  end
end
\`\`\`

### 分类树缓存
\`\`\`ruby
# Redis 缓存分类层级
Category.tree  # 使用缓存版本
\`\`\`

## 常见 N+1 问题和解决方案

| 场景 | 问题 | 解决方案 |
|------|------|---------|
| 加载 Entry 及其 Account | N+1 查询 | Entry.includes(:account) |
| 加载 Entry 及转账对方账户 | N+1 查询 | Entry.preload_transfer_accounts |
| 加载 Category 及其子分类 | N+1 查询 | Category.includes(:children) |

## 查询优化技巧

### 1. 明确指定列
\`\`\`ruby
# ❌ 低效
Entry.all.map { |e| e.amount }

# ✅ 高效
Entry.select(:id, :amount).map { |e| e.amount }
\`\`\`

### 2. 使用 exists? 而非 count
\`\`\`ruby
# ❌ 低效 - 计算行数
Account.where(balance: 0).count > 0

# ✅ 高效 - 布尔检查
Account.where(balance: 0).exists?
\`\`\`

### 3. 聚合优化
\`\`\`ruby
# ❌ 低效 - 应用层计算
entries.sum(&:amount)

# ✅ 高效 - 数据库层计算
Entry.sum(:amount)
\`\`\`

## 性能监控工具

### 1. Bullet Gem (N+1 检测)
\`\`\`ruby
# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.rails_logger = true
end
\`\`\`

### 2. rack-mini-profiler (请求分析)
- 开发环境自动启用
- 页面右上角显示性能指标

### 3. Slow Query Log
\`\`\`sql
-- config/database.yml
development:
  slowquery: true
  slowquery_time: 0.1  -- 记录 > 100ms 的查询
\`\`\`

## 数据库分析

\`\`\`bash
# 生成执行计划
rails dbconsole
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM entries WHERE account_id = 1;

# 更新统计信息
ANALYZE;
\`\`\`

## 缓存预热

\`\`\`ruby
# app/jobs/cache_warmup_job.rb
class CacheWarmupJob < ApplicationJob
  def perform
    # 预加载热点数据到缓存
    Category.tree
    Account.pluck(:id, :balance).each { |id, bal| ... }
  end
end

# Solid Queue 定时任务
config/recurring.yml
warmup:
  schedule: "0 */6 * * *"  # 每 6 小时
  command: "CacheWarmupJob.perform_later"
\`\`\`
```

**相关文件**:
- docs/PERFORMANCE_GUIDE.md (创建新文件)

---

#### 任务 3.1.3: 创建 API 集成文档 ✅ 已存在

**问题**: External API 文档过期或不清晰

```
优先级: 🟡 中
工作量: 1.5 小时
状态: ✅ 已存在 docs/API.md (已更新 2026-05-05)
预期收益: API 集成时间 -50%
```

**文档框架**:

```markdown
# External API Integration Guide

## 认证

所有请求需在 Header 中提供 API Key:
\`\`\`
X-API-Key: your_api_key_here
\`\`\`

获取 API Key: 在应用设置中生成

## 端点

### 创建交易

**POST** `/api/v1/external/transactions`

请求:
\`\`\`json
{
  "date": "2026-05-05",
  "type": "expense",
  "amount": "100.50",
  "currency": "CNY",
  "category": "food",
  "account_id": "123",
  "note": "午餐"
}
\`\`\`

响应 (201 Created):
\`\`\`json
{
  "id": "456",
  "date": "2026-05-05",
  "amount": "100.50",
  "category": "food",
  "status": "pending"
}
\`\`\`

### 获取账户列表

**GET** `/api/v1/external/accounts`

查询参数:
- `type`: 账户类型 (cash, bank, credit)
- `include_archived`: true/false

### 更新交易

**PATCH** `/api/v1/external/transactions/:id`

可更新字段:
- note
- amount
- category (需要有权限)

## 错误代码

| 代码 | 说明 | 处理方式 |
|------|------|---------|
| 401 | 未授权 | 检查 API Key |
| 403 | 禁止访问 | 检查权限和资源所有权 |
| 422 | 验证失败 | 查看 errors 字段 |
| 429 | 超速率限制 | 等待后重试 |
| 500 | 服务器错误 | 记录 transaction_id，联系支持 |

## 速率限制

- 每个 API Key 限制: 100 请求/分钟
- 响应 Header:
  \`\`\`
  X-RateLimit-Limit: 100
  X-RateLimit-Remaining: 95
  X-RateLimit-Reset: 1620000000
  \`\`\`

## 示例代码

### Python
\`\`\`python
import requests

API_KEY = "your_api_key"
BASE_URL = "https://ledger.example.com/api/v1/external"

headers = {"X-API-Key": API_KEY}

# 创建交易
response = requests.post(
  f"{BASE_URL}/transactions",
  headers=headers,
  json={
    "date": "2026-05-05",
    "amount": 100.50,
    "category": "food"
  }
)

if response.status_code == 201:
  print(response.json()["id"])
else:
  print(response.json()["errors"])
\`\`\`

### cURL
\`\`\`bash
curl -X POST https://ledger.example.com/api/v1/external/transactions \
  -H "X-API-Key: your_api_key" \
  -d '{"date":"2026-05-05","amount":100.50,"category":"food"}'
\`\`\`
```

**相关文件**:
- docs/API.md (更新现有文件)

---

#### 任务 3.1.4: 创建开发环境配置文档 ✅ 已存在

**问题**: 缺少 .env 配置说明和快速启动指南

```
优先级: 🟡 中
工作量: 1 小时
状态: ✅ 已存在 docs/DEVELOPMENT_SETUP.md
预期收益: 新开发者启动时间 -50%
```
  ✅ Docker 开发环境说明
  ✅ 常见问题解决
  ✅ IDE 推荐配置
```

**文件内容**:

```markdown
# Development Environment Setup

## 快速启动 (5 分钟)

\`\`\`bash
# 1. 克隆和初始化
git clone <repo>
cd ledger
cp .env.example .env
bundle install
bin/setup

# 2. 启动开发服务器
bin/dev  # Rails + Tailwind watch + Solid Queue

# 3. 访问
open http://localhost:3000
\`\`\`

## 环境变量配置

### 必需变量

\`\`\`bash
# .env

# Rails
RAILS_ENV=development
SECRET_KEY_BASE=<生成: rails secret>
RAILS_MASTER_KEY=<从 config/credentials.yml.enc 提取>

# 数据库
DATABASE_URL=postgresql://localhost/ledger_development

# 邮件（可选）
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
\`\`\`

### 可选变量

\`\`\`bash
# 外部 API 密钥
EXTERNAL_API_KEY=test_key_for_development

# WebDAV 备份
WEBDAV_URL=https://example.com/dav
WEBDAV_USER=user
WEBDAV_PASSWORD=password

# Sentry 错误追踪
SENTRY_DSN=https://key@sentry.io/project_id
\`\`\`

## Docker 开发

\`\`\`bash
# 使用 Docker Compose
docker-compose -f docker-compose.dev.yml up

# 重置数据库
docker-compose exec app rails db:reset
\`\`\`

## 常见问题

### PG::ConnectionBad: 无法连接数据库
\`\`\`bash
# 检查 PostgreSQL 状态
brew services list

# 启动 PostgreSQL
brew services start postgresql

# 检查 DATABASE_URL
echo $DATABASE_URL
\`\`\`

### Rake 任务找不到
\`\`\`bash
# 重新加载 Rakefile
bundle exec rake -T

# 或清理构建缓存
rm -rf .rake_tasks_cache
\`\`\`

## IDE 配置

### VS Code
\`\`\`json
{
  "rubyLSP.rubyExecutablePath": "/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/ruby",
  "rubyLSP.serverTransportMode": "stdio",
  "[ruby]": {
    "editor.defaultFormatter": "Shopify.ruby-lsp"
  }
}
\`\`\`

### RubyMine
1. Settings → Languages & Frameworks → Ruby
2. Ruby SDK: /opt/homebrew/Cellar/ruby@3.3/3.3.10
3. Gem 清单: Gemfile
```

**相关文件**:
- docs/DEVELOPMENT_SETUP.md (创建新文件)
- .env.example (创建新文件)

---

### Phase 3.2: 基础性能优化

#### 任务 3.2.1: 实施分类树缓存 ✅ 已存在

**问题**: 分类树重复构建浪费计算资源

```
优先级: 🟡 中
工作量: 1.5 小时
状态: ✅ 已存在 (仅添加调度配置 PR #242)
预期收益: 分类查询 -70% 时间，缓存命中率 95%+
验收标准:
  ✅ Category.tree 方法已实现 Rails.cache.fetch
  ✅ after_save/after_destroy 已清除缓存
  ✅ CacheWarmupJob 已存在预热逻辑
```

**实现方案**:

```ruby
# app/models/category.rb

class Category < ApplicationRecord
  has_many :children, class_name: 'Category', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Category', optional: true

  # 缓存树形结构
  def self.tree
    Rails.cache.fetch('categories:tree', expires_in: 1.day) do
      build_tree
    end
  end

  # 构建树
  def self.build_tree
    roots = where(parent_id: nil)
    roots.each_with_object({}) do |root, hash|
      hash[root.id] = build_subtree(root)
    end
  end

  private

  def self.build_subtree(category)
    {
      id: category.id,
      name: category.name,
      children: category.children.map { |child| build_subtree(child) }
    }
  end

  # 缓存失效回调
  after_save :clear_tree_cache
  after_destroy :clear_tree_cache

  def clear_tree_cache
    Rails.cache.delete('categories:tree')
  end
end
```

**性能测试**:

```ruby
# spec/performance/category_spec.rb

RSpec.describe 'Category Performance' do
  before do
    create_list(:category, 50)
  end

  it 'builds tree with cache' do
    expect {
      Category.tree  # 首次构建，可能 50ms
      Category.tree  # 缓存命中，1ms
    }.to perform_under(100).ms
  end
end
```

**相关文件**:
- app/models/category.rb
- spec/performance/category_spec.rb

---

#### 任务 3.2.2: 缓存预热任务 ✅ 已完成

**问题**: 应用启动时缓存为空，首次请求响应慢

```
优先级: 🟡 中
工作量: 1 小时
状态: ✅ 已完成 (PR #242 添加调度配置)
预期收益: 首页响应时间 -40%
验收标准:
  ✅ CacheWarmupJob 已存在 (app/jobs/cache_warmup_job.rb)
  ✅ 添加 recurring.yml 定时配置 (每 6 小时)
  ✅ 预热 Category.tree 和账户余额
```

**实现方案**:

```ruby
# app/jobs/cache_warmup_job.rb

class CacheWarmupJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting cache warmup..."

    # 预热分类树
    Category.tree

    # 预热账户统计
    Account.includes(:entries).each do |account|
      Rails.cache.write(
        "account:#{account.id}:balance",
        account.calculate_balance,
        expires_in: 1.hour
      )
    end

    Rails.logger.info "Cache warmup completed"
  end
end

# config/initializers/solid_queue.rb
# 或 config/recurring.yml
config.solid_queue.recurrence(:cache_warmup) do
  schedule 'every 6 hours'
  job 'CacheWarmupJob'
end
```

**相关文件**:
- app/jobs/cache_warmup_job.rb (创建新文件)

---

### Phase 3.3: 验收和合并

#### 任务 3.3.1: Phase 3 验收检查清单

```bash
# 文档完整性检查
✅ ls -lh docs/*.md | wc -l  # 应 >= 9 个文档
✅ grep -r "TODO\|FIXME" docs/ | wc -l  # 应为 0
✅ find docs -name "*.md" -exec wc -l {} + | sort -n | tail -5

# 性能验证
✅ rails benchmark  # 缓存预热后首页响应 < 200ms
✅ rails test:performance

# 提交
git checkout -b "improvement/docs-and-perf-phase-3"
git commit -m "improvement: add comprehensive documentation and basic performance optimization

Documentation:
- Add Database Schema ER diagram and design guide
- Add Performance Optimization guide with caching strategies
- Update API integration documentation with examples
- Add Development Setup guide with .env template

Performance:
- Implement category tree caching (expires in 1 day)
- Add cache invalidation hooks
- Add cache warmup job (runs every 6 hours)
- Add performance test benchmarks

Metrics:
- Cache hit rate: 95%+ for category queries
- First page load: -40% faster after warmup
- Documentation: +5 comprehensive guides"
```

**Phase 3 完成标准**:
- ✅ 5 份关键文档完成
- ✅ Database Schema 文档和 ER 图
- ✅ 性能优化指南
- ✅ API 集成文档更新
- ✅ 开发环境配置文档
- ✅ 分类树缓存实现
- ✅ 缓存预热任务
- ✅ 性能测试通过

---

## 📍 Phase 4: ViewComponent 参数重构 (第 4-5 周) - 5月26-6月8日

### 目标
重构 ViewComponent 设计系统，消除参数爆炸问题。

### Phase 4.1: 参数简化策略

#### 任务 4.1.1: Button 组件参数重构

**问题**: Ds::ButtonComponent - 9 参数，难以维护

```
优先级: 🔴 高
工作量: 2-3 小时
预期收益: 参数减半，可读性 +50%
验收标准:
  ✅ 参数从 9 个减至 5 个
  ✅ 所有变体组合仍可用
  ✅ 视图模板使用更清晰
  ✅ 所有相关视图测试通过
```

**重构方案**:

```ruby
# ❌ 当前 (9 个参数)
render(Ds::ButtonComponent.new(
  text: "Save",
  variant: :primary,
  size: :lg,
  icon: "check",
  icon_position: :left,
  disabled: false,
  loading: false,
  full_width: true,
  class_suffix: "custom"
))

# ✅ 改进方案 1: 选项哈希
render(Ds::ButtonComponent.new(
  text: "Save",
  variant: :primary,
  options: { 
    icon: "check",
    size: :lg,
    disabled: false
  }
))

# ✅ 改进方案 2: 工厂方法
render(Ds::PrimaryButtonComponent.new(
  text: "Save",
  icon: "check",
  size: :lg
))

# ✅ 改进方案 3: 配置对象
button_config = ButtonConfig.new(:primary, :lg)
render(Ds::ButtonComponent.new(text: "Save", config: button_config))
```

**实现代码**:

```ruby
# app/components/ds/button_component.rb

class Ds::ButtonComponent < ApplicationComponent
  # 配置常量
  VARIANTS = {
    primary: { bg: "bg-blue-600", text: "text-white" },
    secondary: { bg: "bg-gray-200", text: "text-gray-800" },
    danger: { bg: "bg-red-600", text: "text-white" }
  }.freeze

  SIZES = {
    sm: { padding: "px-2 py-1", text: "text-sm" },
    md: { padding: "px-4 py-2", text: "text-base" },
    lg: { padding: "px-6 py-3", text: "text-lg" }
  }.freeze

  attr_reader :text, :variant, :icon, :disabled, :loading, :size, :full_width

  def initialize(text:, variant: :secondary, size: :md, icon: nil, disabled: false, loading: false, full_width: false, **options)
    @text = text
    @variant = variant
    @size = size
    @icon = icon
    @disabled = disabled
    @loading = loading
    @full_width = full_width
    @options = options
  end

  def button_classes
    classes = [
      variant_classes,
      size_classes,
      full_width ? "w-full" : nil,
      disabled_classes,
      @options[:class]
    ]
    class_names(*classes.compact)
  end

  private

  def variant_classes
    VARIANTS[@variant]&.values&.join(' ')
  end

  def size_classes
    SIZES[@size]&.values&.join(' ')
  end

  def disabled_classes
    "opacity-50 cursor-not-allowed" if @disabled || @loading
  end
end
```

**相关文件**:
- app/components/ds/button_component.rb
- spec/components/ds/button_component_spec.rb

---

#### 任务 4.1.2: Card 组件参数重构

**问题**: Ds::CardComponent - 过多条件分支

```
优先级: 🟡 中
工作量: 1.5 小时
预期收益: 代码复杂度 -30%
验收标准:
  ✅ 消除 base_classes 中的 16 条语句
  ✅ 使用配置驱动方法
  ✅ 测试通过
```

**重构方案** (同 Button 模式)

**相关文件**:
- app/components/ds/card_component.rb

---

#### 任务 4.1.3: Dialog 和其他复杂组件

**问题**: DialogComponent - 11 个实例变量

```
优先级: 🟡 中
工作量: 3-4 小时
预期收益: 组件复杂度 -40%
验收标准:
  ✅ 参数简化，分离关注点
  ✅ 提取配置对象
  ✅ 所有视图测试通过
```

**策略**: 分解为更小的组件

```ruby
# ❌ 当前 (1 个大组件，11 个实例变量)
DialogComponent {
  header_block
  body_block
  actions_block
  body_options
  ...
}

# ✅ 改进 (组件组合)
DialogComponent {
  DialogHeaderComponent
  DialogBodyComponent
  DialogActionsComponent
}
```

---

### Phase 4.2: ViewComponent 测试补充

#### 任务 4.2.1: 补充组件变体组合测试

**问题**: ViewComponent 变体覆盖不足

```
优先级: 🟡 中
工作量: 3-4 小时
预期收益: 组件测试覆盖率 60% → 85%
验收标准:
  ✅ 为 10+ 组件添加组合测试
  ✅ 覆盖所有变体配置
  ✅ 测试渲染输出正确性
```

**测试模板**:

```ruby
# spec/components/ds/button_component_spec.rb

RSpec.describe 'Ds::ButtonComponent', type: :component do
  let(:text) { 'Click me' }

  it 'renders primary button' do
    render_inline(
      described_class.new(text:, variant: :primary)
    )
    
    expect(page).to have_css('.bg-blue-600')
    expect(page).to have_text('Click me')
  end

  describe 'variants' do
    %i[primary secondary danger].each do |variant|
      it "renders #{variant} variant" do
        render_inline(described_class.new(text:, variant:))
        # 断言
      end
    end
  end

  describe 'sizes' do
    %i[sm md lg].each do |size|
      it "renders #{size} size" do
        render_inline(described_class.new(text:, size:))
        # 断言
      end
    end
  end

  describe 'combinations' do
    it 'renders large primary button with icon' do
      render_inline(
        described_class.new(
          text:,
          variant: :primary,
          size: :lg,
          icon: 'check'
        )
      )
      # 断言
    end
  end

  describe 'disabled state' do
    it 'renders disabled button' do
      render_inline(
        described_class.new(text:, disabled: true)
      )
      expect(page).to have_css('.opacity-50.cursor-not-allowed')
    end
  end

  describe 'loading state' do
    it 'renders loading button' do
      render_inline(
        described_class.new(text:, loading: true)
      )
      expect(page).to have_css('.opacity-50')
    end
  end
end
```

---

### Phase 4.3: 验收和合并

#### 任务 4.3.1: Phase 4 验收检查清单

```bash
# 组件验证
✅ bin/rails test:components
✅ bin/rubocop app/components/  # 应 0 违规
✅ bin/reek app/components/ | grep -c "warning"  # 应 < 50

# 提交
git checkout -b "refactor/viewcomponent-optimization"
git commit -m "refactor: simplify ViewComponent parameters and improve maintainability

Changes:
- Refactor Ds::ButtonComponent: 9 params → 5 params
- Refactor Ds::CardComponent: 16 statements → 8 statements
- Refactor Ds::DialogComponent: 11 instance vars → 5 vars
- Extract style configurations into constants
- Decompose large components into smaller composable pieces

Testing:
- Add 50+ component combination tests
- Achieve 85% component test coverage
- All existing views pass

Metrics:
- Parameter count: -40%
- Code complexity: -35%
- Maintainability: +50%"
```

**Phase 4 完成标准**:
- ✅ 3+ 主要组件参数简化
- ✅ 配置驱动实现
- ✅ 50+ 新组件测试
- ✅ 所有视图测试通过
- ✅ Rubocop 0 违规

---

## 📍 Phase 5-7: 架构改进和长期优化 (第 6-8 周) - 6月9-29日

### Phase 5-7.0: 审查报告 P3 待办项 (低优先级)

#### 任务 5.0.1: Stimulus 控制器懒加载 ⏳ 待开始

**问题**: 59 个控制器 upfront 注册影响加载

```
优先级: 🟢 低 (P3)
工作量: 2 小时
状态: ⏳ 待开始
验收标准:
  ✅ 使用 stimulus-loading.js 按需加载
  ✅ 首屏只加载必要控制器
```

---

#### 任务 5.0.2: 大方法拆分 ⏳ 待开始

**问题**: 多个超长方法难以维护

```
优先级: 🟢 低 (P3)
工作量: 4 小时
状态: ⏳ 待开始
涉及方法:
  - Account#bill_cycles_with_statement (75 行)
  - Account#batch_bill_cycle_summary (65 行)
  - ReportsController#compute_sankey_data (93 行)
验收标准:
  ✅ 所有方法 < 50 行
  ✅ 单一职责原则
```

---

#### 任务 5.0.3: 错误处理增强 ⏳ 待开始

**问题**: 部分控制器缺少全面错误处理

```
优先级: 🟢 低 (P3)
工作量: 3 小时
状态: ⏳ 待开始
涉及文件:
  - TransactionsController#create (边界值处理)
  - BackupsController (WebDAV 错误)
验收标准:
  ✅ 所有异常场景有明确错误响应
  ✅ 添加对应测试
```

---

### Phase 5: 架构改进 (第 6 周)

#### 任务 5.1.1: Entry 模型拆分

```
优先级: 🟡 中
工作量: 4-5 小时
预期收益: 模型复杂度 -30%，测试运行时间 -10%
验收标准:
  ✅ Entry 模型 < 400 行
  ✅ 关键逻辑迁移到 Service
  ✅ 所有测试通过，覆盖率不下降
```

**拆分策略**:

```ruby
# app/services/entry_query_service.rb - 查询相关方法
class EntryQueryService
  def expenses_by_category(account)
    account.entries.transactions_only.expenses
      .group_by(&:category)
  end
end

# app/services/entry_calculation_service.rb - 计算相关
class EntryCalculationService
  def calculate_balance(account, as_of_date: Date.today)
    # 余额计算逻辑
  end
end
```

---

#### 任务 5.1.2: Category 递归查询优化

```
优先级: 🟡 中
工作量: 2-3 小时
预期收益: 分类查询 -50% 时间
验收标准:
  ✅ 使用 closure_tree 或 ancestry gem
  ✅ 递归查询性能测试通过
  ✅ 深度限制约束添加
```

**方案**:

```ruby
# Gemfile
gem 'ancestry'  # 提供 #descendants, #ancestors 方法

# app/models/category.rb
class Category < ApplicationRecord
  has_ancestry
end

# 使用
category.ancestors  # 高效查询祖先
category.descendants  # 高效查询子孙
```

---

### Phase 6: 缓存和并发优化 (第 7 周)

#### 任务 6.1.1: 用户统计缓存

```
优先级: 🟡 中
工作量: 1-2 小时
预期收益: 仪表盘响应时间 -60%
验收标准:
  ✅ 仪表盘统计缓存 (1 小时 TTL)
  ✅ 实时数据更新时清除缓存
```

#### 任务 6.1.2: 分布式锁机制

```
优先级: 🟢 低
工作量: 2-3 小时
预期收益: 并发安全性 +100%
验收标准:
  ✅ Redis 分布式锁实现
  ✅ 关键操作加锁 (余额更新、转账)
```

---

### Phase 7: 监控和性能基准 (第 8 周)

#### 任务 7.1.1: 性能基准建立

```
优先级: 🟢 低
工作量: 2-3 小时
预期收益: 性能衰退早期发现
验收标准:
  ✅ 建立性能基准测试
  ✅ CI/CD 集成
  ✅ 告警规则配置
```

**实现**:

```ruby
# spec/performance/baseline_spec.rb

RSpec.describe 'Performance Baseline' do
  it 'homepage loads in < 200ms' do
    expect { get '/' }.to perform_under(200).ms
  end

  it 'account list with 100 entries loads in < 300ms' do
    expect { 
      get account_path(account_with_entries)
    }.to perform_under(300).ms
  end
end
```

---

## 🎯 总体时间表和里程碑

### 周汇总

| 周 | 阶段 | 主要任务 | 交付物 |
|---|------|---------|--------|
| **W1 (5/5-5/11)** | Phase 1 | 安全修复、依赖更新 | 0 安全警告 |
| **W2 (5/12-5/18)** | Phase 2 | 代码质量、测试覆盖 | 82% 覆盖率 |
| **W3 (5/19-5/25)** | Phase 3 | 文档、性能基础 | 5 份新文档 |
| **W4-5 (5/26-6/8)** | Phase 4 | 组件重构、参数简化 | 3 个优化组件 |
| **W6 (6/9-6/15)** | Phase 5 | 架构改进、拆分 | Entry 服务化 |
| **W7 (6/16-6/22)** | Phase 6 | 缓存、并发优化 | 缓存系统完整 |
| **W8 (6/23-6/29)** | Phase 7 | 监控、验收、上线 | 性能基准就位 |

### 关键里程碑

```
🔴 5月11日 (周一) - Phase 1 完成
   ✅ 0 CVE 漏洞
   ✅ 0 SQL 注入警告
   ✅ Brakeman < 5 警告

🟡 5月18日 (周一) - Phase 2 完成
   ✅ 测试覆盖率 82%+
   ✅ xit 测试全部启用
   ✅ API 错误场景测试完善

🟢 5月25日 (周一) - Phase 3 完成
   ✅ 5 份关键文档完成
   ✅ 缓存预热就位
   ✅ 性能基线建立

🔵 6月8日 (周一) - Phase 4 完成
   ✅ 组件参数 -40%
   ✅ 组件测试覆盖率 85%
   ✅ 代码复杂度 -30%

🟣 6月29日 (周一) - 全部完成
   ✅ 综合评分 9.2/10
   ✅ 测试覆盖率 92%+
   ✅ 安全漏洞 0
```

---

## 📊 成功指标

### 代码质量指标

| 指标 | 当前 | 目标 | 衡量方式 |
|------|------|------|---------|
| Rubocop 违规 | 0 | 0 | CI 检查 |
| Brakeman 警告 | 17 | < 5 | 周期性扫描 |
| 代码复杂度 | - | avg < 10 | Flog 分析 |
| 代码坏味道 | 156 | < 80 | Reek 报告 |

### 测试质量指标

| 指标 | 当前 | 目标 | 衡量方式 |
|------|------|------|---------|
| 行覆盖率 | 80.48% | 92%+ | simplecov |
| 测试失败 | 0 | 0 | CI 报告 |
| 待办测试 | 11 | 0 | xit 计数 |
| 测试执行时间 | 10.43s | < 15s | CI 日志 |

### 文档完整度指标

| 指标 | 当前 | 目标 | 衡量方式 |
|------|------|------|---------|
| 文档数量 | 4 | 9+ | 文件计数 |
| 文档总行数 | - | 2000+ | wc -l |
| 代码注释 | 部分 | 全面 | 手工检查 |

### 性能指标

| 指标 | 当前 | 目标 | 衡量方式 |
|------|------|------|---------|
| 首页加载 | - | < 200ms | 性能测试 |
| 缓存命中率 | 0% | 95%+ | Rails.cache 监控 |
| N+1 查询 | 多个 | 0 | Bullet 检查 |

---

## 📋 执行检查清单

### 每周标准流程

```
周一:
  ☐ 回顾上周 PR 反馈
  ☐ 确认本周任务和优先级
  ☐ 分配 Story Point
  
周二-周四:
  ☐ 实现功能
  ☐ 编写测试
  ☐ 代码自审
  ☐ 本地验收标准检查
  
周五:
  ☐ 运行完整测试套件
  ☐ 代码审查 (peer review)
  ☐ 合并 PR
  ☐ 周报告 (完成度、问题、风险)
  
每日:
  ☐ 运行 CI/CD 流程
  ☐ 处理 CI 失败
  ☐ 日志和问题更新
```

### Phase 完成清单

```
完成前检查:
  ☐ 所有任务实现完毕
  ☐ 本地测试 100% 通过
  ☐ Rubocop / Brakeman / Reek 检查通过
  ☐ 新增测试覆盖率达到目标
  ☐ 代码审查通过
  ☐ 文档更新 (CHANGELOG, README)

合并前:
  ☐ CI/CD 全部通过
  ☐ 代码 Squash 整理
  ☐ 提交信息清晰完整
  ☐ PR 描述包含变更总结和验收标准
  ☐ 至少 2 个 Approval

合并后:
  ☐ 确认 main 分支部署成功
  ☐ 监控新部署的性能指标
  ☐ 记录里程碑完成
```

---

## 🚨 风险和缓解措施

### 风险识别

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| **时间超期** | 中 | 中 | 每周检查进度，优先级调整 |
| **回归问题** | 中 | 高 | 完整的自动化测试覆盖 |
| **依赖冲突** | 低 | 中 | 充分的本地测试，更新隔离 |
| **生产事故** | 低 | 高 | 分阶段发布，监控告警 |

### 应急方案

```
如果 Phase N 超期:
  1. 评估关键性: 是否影响后续 Phase
  2. 重新划分: 移除低优先级任务到 Phase N+1
  3. 并行化: 合并无依赖的任务

如果 CI 持续失败:
  1. 回滚最后一个 commit
  2. 本地隔离问题
  3. 修复后再提交

如果 QA 发现严重问题:
  1. 优先修复
  2. 补充相应的测试用例
  3. 继续推进
```

---

## 📞 沟通和反馈

### 每周同步会

**时间**: 每周五 10:00  
**参与**: 开发者、QA、PM  
**议程**:
1. Phase 进度汇报 (5 分钟)
2. 问题和风险讨论 (10 分钟)
3. 下周计划确认 (5 分钟)

### 问题上报机制

- **轻微问题**: GitHub Issue
- **紧急问题**: 即时沟通 (Slack)
- **架构问题**: 讨论会议

---

## 📈 总体预期成果

### 量化收益

| 维度 | 当前 | 目标 | 改善 |
|------|------|------|------|
| 代码质量评分 | 8.5/10 | 9.5/10 | +1.0 点 |
| 测试覆盖率 | 80.48% | 92% | +11.52% |
| 安全漏洞 | 17 | 0 | 100% 关闭 |
| 文档页数 | 4 | 9+ | +125% |
| 组件参数数 | 平均 7 | 平均 4 | -43% |
| 首页加载 | - | < 200ms | - |
| **综合评分** | **8.0/10** | **9.2/10** | **+1.2** |

### 定性收益

✅ **安全性**: 零 CVE，所有参数化查询，完整的权限检查  
✅ **可维护性**: 代码清晰，注释完善，文档全面  
✅ **性能**: 缓存策略到位，性能基准建立，N+1 消除  
✅ **测试**: 92%+ 覆盖率，自动化程度高，信心充足  
✅ **开发体验**: 文档齐全，新开发者启动快，调试工具完备  

---

**计划制定**: 2026-05-05  
**预计完成**: 2026-06-29  
**总投入**: ~200 小时  
**预期 ROI**: 代码质量和安全性显著提升，技术债 -60%
