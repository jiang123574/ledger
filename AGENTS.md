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