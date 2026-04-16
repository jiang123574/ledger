# AGENTS Configuration

## Ruby Environment

This project uses Ruby 3.3.10 installed via Homebrew.

### Ruby Path
```
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/ruby
```

### Bundle Path
```
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/bundle
```

### Rails Path
```
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails
```

## Development Setup

To run Rails commands with the correct Ruby version:

```bash
# Run migrations
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails db:migrate

# Run Rails runner
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails runner "Account.bulk_update_cache"

# Start Rails server
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails server
```

Or add to your shell PATH:

```bash
export PATH="/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin:$PATH"
```

## Project-specific Commands

### Database Migrations
After creating new migrations, run:
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails db:migrate
```

### Update Account Cache
To update counter cache for all accounts:
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails runner "Account.bulk_update_cache"
```

### Testing
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails test
```

### Linting
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/bundle exec rubocop
```

### Start Rails Server
Rails 服务需绑定 `0.0.0.0` 以允许局域网设备（手机、Android）访问：
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails server -b 0.0.0.0 -p 3000
```

## JavaScript 规范

### 变量声明
- 使用 `const` 或 `let`，禁止使用 `var`（已完成 PR #78 统一）
- `const`：不会被重新赋值的变量
- `let`：循环中或需要重新赋值的变量

### Inline Script 与 Turbo 兼容
Turbo 页面替换会重新执行 inline `<script>` 标签，导致顶层 `const`/`let` 重复声明报错。
解决方案：用 IIFE 包裹整个 script 块，通过作用域隔离避免冲突：
```erb
<script>
(function() {
  const myVar = 'value';
  function myFunc() { /* ... */ }

  // inline handler 需要的函数暴露到 window
  window.myFunc = myFunc;
})();
</script>
```
`<script type="module">` 天然有独立作用域，无需 IIFE。

## UI Components

### Pinyin Selector Component

带拼音筛选功能的选择器组件，支持中文和拼音首字母搜索。

**使用场景**：
- 账户选择
- 分类选择
- 任何需要拼音搜索的下拉选择

**详细文档**：参见 `docs/PINYIN_SELECTOR_GUIDE.md`

**快速参考**：
```erb
<!-- 1. 数据源 script 标签 -->
<script id="my-selector-data" type="application/json">
  <%= raw @items.map { |i| { id: i.id, name: i.name, pinyin: PinYin.abbr(i.name).downcase } }.to_json %>
</script>

<!-- 2. HTML 结构 -->
<input type="text" id="my-search" class="... cursor-pointer" placeholder="选择项目" autocomplete="off" readonly>
<input type="hidden" name="item[id]" id="my-id">
<div id="my-dropdown" class="hidden absolute z-50 ...">
  <input type="text" id="my-filter" placeholder="筛选...">
  <div id="my-options"></div>
</div>

<!-- 3. JavaScript 初始化 -->
<script type="module">
import { initSelectorWithData } from 'selectors';
initSelectorWithData({
  searchInputId: 'my-search',
  dropdownId: 'my-dropdown',
  filterInputId: 'my-filter',
  optionsId: 'my-options',
  hiddenInputId: 'my-id',
  dataSource: JSON.parse(document.getElementById('my-selector-data').textContent),
  noMatchText: '无匹配项'
});
</script>
```


Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.