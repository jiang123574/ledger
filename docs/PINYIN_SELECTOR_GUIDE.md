# Pinyin Selector Component Guide

带拼音筛选功能的选择器组件，支持中文和拼音首字母搜索。

## 使用场景

- 账户选择（Accounts）
- 分类选择（Categories）
- 任何需要拼音搜索的下拉选择

## 特性

- ✅ 支持中文搜索
- ✅ 支持拼音首字母搜索（如 "zg" 匹配 "工资"）
- ✅ 支持拼音全拼搜索
- ✅ 支持自定义空选项
- ✅ 响应式设计
- ✅ 深色模式支持

## 实现步骤

### 1. 准备数据源（Controller）

在 controller 中准备数据：

```ruby
# app/controllers/example_controller.rb
def index
  @accounts = Account.visible.order(:name)
  @categories = Category.active.order(:name)
end
```

### 2. 添加数据源 script 标签（View）

在视图中添加数据源，使用 JSON 格式，**必须包含 `pinyin` 字段**：

```erb
<!-- 账户数据源 -->
<script id="accounts-data" type="application/json">
  <%= raw @accounts.map { |a| { id: a.id, name: a.name, pinyin: PinYin.abbr(a.name).downcase } }.to_json %>
</script>

<!-- 分类数据源（支持层级） -->
<script id="categories-data" type="application/json">
  <%= raw @categories.map { |c| 
    full_name = build_full_name_in_memory(c, parent_map)
    { 
      id: c.id, 
      name: c.name, 
      full_name: full_name, 
      pinyin: PinYin.abbr(full_name).downcase 
    } 
  }.to_json %>
</script>
```

**重要字段说明**：
- `id`: 项目 ID（必须）
- `name`: 项目名称（必须）
- `full_name`: 完整路径名称（可选，用于层级分类）
- `pinyin`: 拼音首字母，小写（必须，用于拼音搜索）

### 3. 添加 HTML 结构（View）

#### 基本结构

```erb
<div class="relative">
  <!-- 搜索输入框（显示选中项） -->
  <input type="text" 
         id="account-search" 
         class="w-full px-3 py-1.5 text-sm rounded-lg border border-border dark:border-border-dark bg-white dark:bg-container-dark text-primary dark:text-primary-dark focus:ring-2 focus:ring-blue-500 cursor-pointer"
         placeholder="选择账户"
         autocomplete="off"
         readonly>
  
  <!-- 隐藏的 ID 输入框 -->
  <input type="hidden" name="account_id" id="account-id">
  
  <!-- 下拉箭头图标 -->
  <svg class="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-secondary dark:text-secondary-dark pointer-events-none" 
       fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
  </svg>
  
  <!-- 下拉菜单 -->
  <div id="account-dropdown" 
       class="hidden absolute z-50 w-full mt-1 bg-white dark:bg-container-dark rounded-lg border border-border dark:border-border-dark shadow-lg max-h-60 overflow-y-auto">
    <!-- 筛选输入框 -->
    <div class="p-2 border-b border-border dark:border-border-dark">
      <input type="text" 
             id="account-filter" 
             class="w-full px-2 py-1 text-sm rounded border border-border dark:border-border-dark bg-white dark:bg-container-dark text-primary dark:text-primary-dark focus:ring-2 focus:ring-blue-500"
             placeholder="筛选..."
             autocomplete="off">
    </div>
    <!-- 选项容器 -->
    <div id="account-options" class="py-1"></div>
  </div>
</div>
```

#### 带空选项的结构

适用于"不设置分类"等场景：

```erb
<!-- 初始化时添加 emptyOption 参数 -->
initSelectorWithData({
  ...
  emptyOption: { label: '不设置分类', value: '', display: '' },
  ...
});
```

### 4. 添加 JavaScript 初始化（View）

使用 ES6 模块方式初始化：

```erb
<script type="module">
import { initSelectorWithData } from 'selectors';

// 解析数据源
var accountsData = JSON.parse(document.getElementById('accounts-data').textContent);

// 如果是分类数据，需要转换格式
var categoriesData = JSON.parse(document.getElementById('categories-data').textContent);
var categorySelectorData = categoriesData.map(function(cat) {
  return {
    id: cat.id || cat.name,
    name: cat.name,
    full_name: cat.full_name || cat.name,
    pinyin: cat.pinyin || ''
  };
});

// 初始化账户选择器
initSelectorWithData({
  searchInputId: 'account-search',
  dropdownId: 'account-dropdown',
  filterInputId: 'account-filter',
  optionsId: 'account-options',
  hiddenInputId: 'account-id',
  dataSource: accountsData,
  noMatchText: '无匹配账户'
});

// 初始化分类选择器（带空选项）
initSelectorWithData({
  searchInputId: 'category-search',
  dropdownId: 'category-dropdown',
  filterInputId: 'category-filter',
  optionsId: 'category-options',
  hiddenInputId: 'category-id',
  dataSource: categorySelectorData,
  emptyOption: { label: '不设置分类', value: '', display: '' },
  noMatchText: '无匹配分类'
});

// 如果是在弹窗中使用，需要暴露函数到全局作用域
window.openModal = function() {
  // 重置表单
  // 初始化选择器（同上）
  // 显示弹窗
};
</script>
```

### 5. 在弹窗中使用

在弹窗中使用时，需要每次打开弹窗时初始化选择器：

```erb
<script type="module">
import { initSelectorWithData } from 'selectors';

var accountsData = JSON.parse(document.getElementById('accounts-data').textContent);

function openModal() {
  var form = document.getElementById('modal-form');
  if (form) {
    form.reset();
  }
  
  // 初始化选择器
  initSelectorWithData({
    searchInputId: 'modal-account-search',
    dropdownId: 'modal-account-dropdown',
    filterInputId: 'modal-account-filter',
    optionsId: 'modal-account-options',
    hiddenInputId: 'modal-account-id',
    dataSource: accountsData,
    noMatchText: '无匹配账户'
  });
  
  // 显示弹窗
  document.getElementById('modal').classList.remove('hidden');
}

// 暴露到全局作用域（供 onclick 调用）
window.openModal = openModal;
</script>
```

## 参数说明

### initSelectorWithData 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `searchInputId` | String | ✅ | 搜索输入框 ID（显示选中项） |
| `dropdownId` | String | ✅ | 下拉菜单容器 ID |
| `filterInputId` | String | ✅ | 筛选输入框 ID（在下拉菜单内） |
| `optionsId` | String | ✅ | 选项容器 ID |
| `hiddenInputId` | String | ✅ | 隐藏的 ID 输入框 ID |
| `dataSource` | Array | ✅ | 数据源数组，每个对象需包含 `id`, `name`, `pinyin` 字段 |
| `noMatchText` | String | ✅ | 无匹配项时的提示文本 |
| `emptyOption` | Object | ❌ | 空选项配置，如 `{ label: '不设置分类', value: '', display: '' }` |

### 数据源对象格式

#### 基本格式

```javascript
{
  id: 1,                    // 项目 ID（必须）
  name: "工资",              // 项目名称（必须）
  pinyin: "gz"              // 拼音首字母，小写（必须）
}
```

#### 带层级格式

```javascript
{
  id: 1,
  name: "工资",
  full_name: "收入 > 工资", // 完整路径名称（可选）
  pinyin: "srgz"           // 完整路径的拼音首字母（必须）
}
```

## 完整示例

### 示例 1：账户选择器

```erb
<!-- 数据源 -->
<script id="accounts-data" type="application/json">
  <%= raw @accounts.map { |a| { id: a.id, name: a.name, pinyin: PinYin.abbr(a.name).downcase } }.to_json %>
</script>

<!-- 表单 -->
<form>
  <div class="relative">
    <input type="text" id="account-search" 
           class="w-full px-3 py-1.5 text-sm rounded-lg border border-border dark:border-border-dark bg-white dark:bg-container-dark text-primary dark:text-primary-dark focus:ring-2 focus:ring-blue-500 cursor-pointer"
           placeholder="选择账户"
           autocomplete="off"
           readonly>
    <input type="hidden" name="account_id" id="account-id">
    <svg class="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-secondary dark:text-secondary-dark pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
    </svg>
    <div id="account-dropdown" class="hidden absolute z-50 w-full mt-1 bg-white dark:bg-container-dark rounded-lg border border-border dark:border-border-dark shadow-lg max-h-60 overflow-y-auto">
      <div class="p-2 border-b border-border dark:border-border-dark">
        <input type="text" id="account-filter" class="w-full px-2 py-1 text-sm rounded border border-border dark:border-border-dark bg-white dark:bg-container-dark text-primary dark:text-primary-dark focus:ring-2 focus:ring-blue-500" placeholder="筛选..." autocomplete="off">
      </div>
      <div id="account-options" class="py-1"></div>
    </div>
  </div>
</form>

<!-- 初始化 -->
<script type="module">
import { initSelectorWithData } from 'selectors';
initSelectorWithData({
  searchInputId: 'account-search',
  dropdownId: 'account-dropdown',
  filterInputId: 'account-filter',
  optionsId: 'account-options',
  hiddenInputId: 'account-id',
  dataSource: JSON.parse(document.getElementById('accounts-data').textContent),
  noMatchText: '无匹配账户'
});
</script>
```

### 示例 2：分类选择器（带空选项）

```erb
<!-- 数据源 -->
<script id="categories-data" type="application/json">
  <%= raw @categories.map { |c| fn = build_full_name_in_memory(c, parent_map); { name: c.name, full_name: fn, pinyin: PinYin.abbr(fn).downcase } }.to_json %>
</script>

<!-- 表单 -->
<div class="relative">
  <input type="text" id="category-search" class="... cursor-pointer" placeholder="选择分类" autocomplete="off" readonly>
  <input type="hidden" name="category" id="category-id">
  <svg class="...">...</svg>
  <div id="category-dropdown" class="hidden absolute z-50 ...">
    <div class="p-2 border-b ...">
      <input type="text" id="category-filter" class="..." placeholder="筛选..." autocomplete="off">
    </div>
    <div id="category-options" class="py-1"></div>
  </div>
</div>

<!-- 初始化 -->
<script type="module">
import { initSelectorWithData } from 'selectors';

var categoriesData = JSON.parse(document.getElementById('categories-data').textContent);
var categorySelectorData = categoriesData.map(function(cat) {
  return {
    id: cat.name,
    name: cat.name,
    full_name: cat.full_name || cat.name,
    pinyin: cat.pinyin || ''
  };
});

initSelectorWithData({
  searchInputId: 'category-search',
  dropdownId: 'category-dropdown',
  filterInputId: 'category-filter',
  optionsId: 'category-options',
  hiddenInputId: 'category-id',
  dataSource: categorySelectorData,
  emptyOption: { label: '不设置分类', value: '', display: '' },
  noMatchText: '无匹配分类'
});
</script>
```

### 示例 3：弹窗中的选择器

参见 `app/views/accounts/index.html.erb` 中的应收款/报销弹窗实现。

## 注意事项

### 1. readonly 属性

搜索输入框**必须**添加 `readonly` 属性，否则：
- 用户可以直接输入文字
- 输入框可能遮挡下拉菜单
- 移动设备可能弹出虚拟键盘

```erb
<!-- ✅ 正确 -->
<input type="text" ... readonly>

<!-- ❌ 错误 -->
<input type="text" ... >
```

### 2. cursor-pointer 类

搜索输入框应添加 `cursor-pointer` 类，提升用户体验：

```erb
<input type="text" class="... cursor-pointer" ...>
```

### 3. z-index 值

下拉菜单使用 `z-50`，确保不被其他元素遮挡：

```erb
<div id="dropdown" class="... z-50 ...">
```

### 4. ES6 模块

使用 `<script type="module">` 确保正确加载依赖：

```erb
<script type="module">
import { initSelectorWithData } from 'selectors';
// ...
</script>
```

### 5. 函数暴露到全局作用域

在弹窗中使用时，需要暴露函数到全局作用域供 onclick 调用：

```javascript
window.openModal = openModal;
```

### 6. 拼音字段小写

拼音字段必须转换为小写：

```ruby
PinYin.abbr(name).downcase
```

## 常见问题

### Q: 下拉菜单被输入框遮挡？

A: 检查搜索输入框是否添加了 `readonly` 属性。

### Q: 拼音搜索不工作？

A: 检查数据源是否包含 `pinyin` 字段，且值为小写。

### Q: 下拉菜单 z-index 冲突？

A: 使用 `z-50`，确保与弹窗（`z-50`）一致，不会被弹窗遮挡。

### Q: 在弹窗中无法打开选择器？

A: 确保每次打开弹窗时重新初始化选择器。

## 参考实现

- `app/views/receivables/index.html.erb` - receivables 页面选择器
- `app/views/payables/index.html.erb` - payables 页面选择器
- `app/views/accounts/index.html.erb` - accounts 页面弹窗选择器（快捷键 'd'/'b'）
- `app/javascript/selectors.js` - 核心实现

## 核心实现

选择器的核心实现在 `app/javascript/selectors.js` 的 `initSelectorWithData` 函数中。

主要功能：
- 搜索输入框点击打开下拉菜单
- 筛选输入框实时过滤选项（支持中文、拼音首字母、拼音全拼）
- 点击选项更新选中值
- 点击外部关闭下拉菜单
- 键盘导航支持（上/下箭头、Enter、Esc）