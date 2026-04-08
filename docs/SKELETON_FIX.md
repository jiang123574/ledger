# 生产环境 Skeleton 空白问题修复

## 问题描述

**症状**: 使用 GitHub Actions 编译的 Docker 镜像部署后，页面顶部显示大段空白区域。

**HTML 代码**:
```html
<div class="page-skeleton" data-page-skeleton-target="overlay" aria-hidden="true">
  <!-- skeleton 内容 -->
</div>
```

**问题**: skeleton 元素应该有 `page-skeleton-hidden` 类来隐藏，但没有生效。

---

## 根本原因

### 构建流程问题

**bin/build-css 脚本的逻辑**:
```bash
# 1. 编译 Tailwind CSS
tailwindcss -i tailwind.css -o tailwind_output.css --minify

# 2. 合并样式
cat tailwind_output.css custom.css > application.css
```

**问题所在**:
- `custom.css` 几乎是空的（只有 9 行注释）
- `tailwind_output.css` 只包含 Tailwind 工具类
- **原始的 `application.css`（1029 行自定义样式）被覆盖了！**

### 丢失的内容

包括但不限于：
- ❌ Skeleton loading 样式 (`.page-skeleton`, `.page-skeleton-hidden`)
- ❌ Button 样式
- ❌ Tooltip 样式
- ❌ Pull indicator 样式
- ❌ CSS 变量定义
- ❌ 所有自定义样式

### 为什么开发环境正常？

开发环境使用 Tailwind CDN：
```erb
<% if Rails.env.development? %>
  <script src="https://cdn.tailwindcss.com"></script>
<% end %>
```

同时加载原始 `application.css`，所以自定义样式都在。

---

## 修复方案

### 解决方法

将原始 `application.css` 的内容复制到 `custom.css`：

```bash
cat app/assets/stylesheets/application.css > app/assets/stylesheets/custom.css
```

### 文件结构

**修复前**:
```
app/assets/stylesheets/
├── tailwind.css        # Tailwind 输入 (3 行)
├── custom.css          # 几乎为空 (9 行) ❌
└── application.css     # 原始自定义样式 (1029 行)
```

**修复后**:
```
app/assets/stylesheets/
├── tailwind.css        # Tailwind 输入 (3 行)
├── custom.css          # 原始自定义样式 (1029 行) ✅
└── application.css     # 原始自定义样式 (1029 行) - Docker 构建时会被覆盖
```

### 构建流程（修复后）

```bash
# 1. 编译 Tailwind CSS
tailwindcss -i tailwind.css -o tailwind_output.css --minify
# 输出: ~40KB Tailwind 工具类

# 2. 合并样式
cat tailwind_output.css custom.css > application.css
# 输出: Tailwind 工具类 + 自定义样式 ✅
```

---

## 提交信息

```
commit c4a30ac
fix: Preserve custom styles in custom.css for production build

- Copy original application.css content to custom.css
- This ensures custom styles (skeleton, buttons, etc.) are included in Docker build
- Fix skeleton overlay not hiding in production deployment
```

---

## 验证修复

### 1. 本地验证

```bash
# 测试编译脚本
./bin/build-css

# 检查输出
ls -lh app/assets/stylesheets/application.css
# 应该 > 60KB（包含 Tailwind + 自定义样式）

# 检查内容
grep "page-skeleton" app/assets/stylesheets/application.css
# 应该找到 skeleton 样式定义
```

### 2. Docker 构建验证

```bash
# 构建镜像
docker build -t ledger-test .

# 检查镜像中的 CSS
docker run --rm ledger-test \
  cat /rails/app/assets/stylesheets/application.css | grep "page-skeleton"

# 应该输出:
# .page-skeleton {
# .page-skeleton-hidden {
```

### 3. 部署验证

部署后检查：
- ✅ Skeleton 元素正确隐藏
- ✅ 页面无空白区域
- ✅ 所有自定义样式生效

---

## 样式文件说明

### tailwind.css

**用途**: Tailwind CSS 输入文件

**内容**:
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

**Git 状态**: ✅ 已追踪

---

### custom.css

**用途**: 自定义样式（Docker 构建时合并）

**内容**: 原始 `application.css` 的所有自定义样式（1029 行）

**包含**:
- CSS 变量定义
- Skeleton loading 样式
- Button 样式
- Tooltip 样式
- Pull indicator 样式
- 所有其他自定义样式

**Git 状态**: ✅ 已追踪

---

### application.css

**用途**: 最终输出文件

**开发环境**: 原始自定义样式（1029 行）

**生产环境**: Tailwind 工具类 + 自定义样式（编译后）

**Git 状态**: ✅ 已追踪（源文件）

**注意**: Docker 构建时会覆盖此文件

---

## 经验教训

### 问题根源

1. **双模式配置的复杂性**: 开发用 CDN，生产用编译
2. **文件覆盖问题**: 构建脚本覆盖源文件
3. **缺少验证**: 没有验证生产构建是否包含所有样式

### 改进建议

#### 1. 文件命名更清晰

```
app/assets/stylesheets/
├── tailwind.input.css      # Tailwind 输入
├── custom.styles.css       # 自定义样式
└── application.css         # 最终输出（构建时生成）
```

#### 2. 添加构建验证

在 `bin/build-css` 中添加验证：

```bash
# 验证输出文件包含关键样式
if ! grep -q "page-skeleton" app/assets/stylesheets/application.css; then
  echo "❌ Error: custom styles not included!"
  exit 1
fi
```

#### 3. 不覆盖源文件

修改构建流程，输出到不同文件：

```bash
# 输出到 application.build.css
cat tailwind_output.css custom.css > app/assets/stylesheets/application.build.css
```

---

## 相关文件

- `bin/build-css` - 构建脚本
- `app/assets/stylesheets/tailwind.css` - Tailwind 输入
- `app/assets/stylesheets/custom.css` - 自定义样式
- `app/assets/stylesheets/application.css` - 最终输出

---

## 相关文档

- `docs/TAILWIND_FINAL_CONFIG.md` - Tailwind 双模式配置
- `docs/GITHUB_ACTIONS_COMPLETE.md` - GitHub Actions 构建

---

## 总结

**问题**: 生产构建丢失自定义样式
**原因**: `custom.css` 为空，构建时覆盖了源文件
**修复**: 将原始样式复制到 `custom.css`
**结果**: 生产环境样式完整，skeleton 正确隐藏 ✅

---

**更新时间**: 2026-04-08  
**修复提交**: c4a30ac