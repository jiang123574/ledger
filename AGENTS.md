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

## UI Components

### Pinyin Selector Component

带拼音筛选功能的选择器组件，支持中文和拼音首字母搜索。

**使用场景**：
- 账户选择
- 分类选择
- 任何需要拼音搜索的下拉选择

**详细文档**：参见 `app/views/shared/PINYIN_SELECTOR_GUIDE.md`

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