# Tailwind CSS 双模式配置

## 配置方案 ✅

### 开发环境：使用 CDN

**优点**：
- ✅ 无需编译，即改即看
- ✅ 实时预览所有 Tailwind 类
- ✅ 开发速度快
- ✅ 无需本地 Node.js 环境

**配置**：
```erb
<!-- app/views/layouts/application.html.erb -->
<% if Rails.env.development? %>
  <script src="https://cdn.tailwindcss.com"></script>
  <script>
    tailwind.config = {
      darkMode: 'class',
      theme: {
        extend: <%= raw TailwindConfigHelper.theme_extensions.to_json %>
      }
    }
  </script>
<% end %>
```

### 生产环境：编译本地 CSS

**优点**：
- ✅ 性能优秀（JIT 编译，只包含使用的类）
- ✅ 无外部依赖
- ✅ 完全控制缓存
- ✅ 文件小（~60KB vs CDN 几 MB）

**配置**：
```dockerfile
# Dockerfile
RUN ./bin/build-css  # 编译 Tailwind
RUN rails assets:precompile
```

---

## 工作流程

### 本地开发（Development）

```
启动 Rails 服务器
    ↓
加载 application.html.erb
    ↓
检测到 Rails.env.development?
    ↓
加载 Tailwind CDN
    ↓
页面使用 CDN 提供的样式
    ↓
✅ 开发愉快！
```

**特点**：
- 修改视图立即看到效果
- 可以使用任何 Tailwind 类
- 控制台有 CDN 警告（预期行为）

### GitHub Actions / Docker 构建（Production）

```
Docker Build
    ↓
执行 bin/build-css
    ↓
编译 Tailwind CSS
    ├─ 扫描所有视图文件
    ├─ 提取使用的 Tailwind 类
    └─ 生成优化的 CSS
    ↓
合并 custom.css
    ↓
生成 application.css (~60KB)
    ↓
rails assets:precompile
    ↓
推送到 ghcr.io
    ↓
✅ 生产就绪！
```

**特点**：
- 只包含使用的类
- 无 CDN 依赖
- 性能最优
- 无控制台警告

---

## 文件结构

```
app/assets/stylesheets/
├── tailwind.css          # Tailwind 输入文件
├── custom.css            # 自定义样式（可选）
├── application.css       # 原始文件（开发环境不使用）
└── (编译后会在 Docker 中生成)

.github/workflows/
└── docker.yml            # GitHub Actions 配置

Dockerfile                # 包含编译步骤
bin/build-css            # 编译脚本
```

---

## 关键文件说明

### 1. tailwind.css

```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

**用途**：Tailwind 输入文件，告诉编译器包含哪些部分

**Git 状态**：✅ 已追踪

---

### 2. custom.css

```css
/* Custom styles - Add your custom CSS here */
```

**用途**：存放自定义样式，会与 Tailwind 合并

**Git 状态**：✅ 已追踪

**用法**：
```css
/* 例如添加自定义样式 */
.my-special-animation {
  animation: customFade 0.3s ease-in;
}

@keyframes customFade {
  from { opacity: 0; }
  to { opacity: 1; }
}
```

---

### 3. bin/build-css

```bash
#!/bin/bash
# 编译 Tailwind CSS
# 检查依赖、编译、合并
```

**用途**：Docker 构建时编译 Tailwind

**Git 状态**：✅ 已追踪

---

### 4. application.css (原始)

**用途**：保留原始样式文件

**Git 状态**：✅ 已追踪

**注意**：生产环境会被编译后的文件覆盖

---

## 开发指南

### 添加新样式

#### 方法 1: 使用 Tailwind 类（推荐）

```html
<div class="flex items-center gap-4 p-6 bg-white rounded-lg shadow">
  <!-- Tailwind 类会被 CDN（开发）和编译器（生产）识别 -->
</div>
```

#### 方法 2: 自定义 CSS

```css
/* app/assets/stylesheets/custom.css */
.my-custom-component {
  @apply flex items-center gap-4; /* 使用 Tailwind 的 @apply */
  background: linear-gradient(to right, #667eea, #764ba2);
}
```

---

### 测试样式

#### 本地测试（开发环境）

```bash
# 启动服务器
rails server

# 访问 http://localhost:3000
# ✅ 使用 CDN，实时预览
```

#### 生产测试（Docker）

```bash
# 构建镜像
docker build -t ledger-test .

# 运行容器
docker run -p 3000:80 ledger-test

# 访问 http://localhost:3000
# ✅ 使用编译后的 CSS
```

---

## 性能对比

### 开发环境（CDN）

| 指标 | 值 |
|------|-----|
| 首次加载 | ~2MB（完整 Tailwind） |
| 后续访问 | 缓存后快 |
| 样式更新 | 即时 |
| 文件数量 | 1（CDN） |

### 生产环境（编译）

| 指标 | 值 |
|------|-----|
| 文件大小 | ~60KB（只包含使用的类） |
| 加载速度 | ⚡ 极快 |
| 缓存控制 | ✅ 完全控制 |
| 外部依赖 | ❌ 无 |

---

## GitHub Actions 自动化

### 触发条件

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

### 构建步骤

```yaml
- Build Docker Image
  ├─ Install dependencies
  ├─ Install npm packages
  ├─ ✨ Run bin/build-css
  ├─ Precompile assets
  └─ Push to ghcr.io
```

### 验证日志

查看 GitHub Actions 日志，应该看到：

```
🎨 编译 Tailwind CSS (Production)...
📦 Installing npm dependencies...
⚙️  Compiling Tailwind...
🔗 Merging styles...
✅ Tailwind CSS compiled successfully!
   Output: app/assets/stylesheets/application.css
```

---

## 故障排查

### 问题 1: 开发环境样式不对

**检查**：
```bash
# 确认是开发环境
rails runner "puts Rails.env"
# 应该输出: development

# 检查 CDN 是否加载
curl -s http://localhost:3000 | grep "cdn.tailwindcss.com"
# 应该看到 CDN 引用
```

**解决**：确保 `Rails.env.development?` 为 true

---

### 问题 2: 生产环境样式丢失

**检查**：
```bash
# 在容器中检查
docker run --rm ledger-test \
  ls -lh /rails/app/assets/stylesheets/application.css

# 查看内容
docker run --rm ledger-test \
  head -1 /rails/app/assets/stylesheets/application.css
# 应该看到: /*! tailwindcss v3.4.1 | MIT License
```

**解决**：确保 Dockerfile 执行了 `./bin/build-css`

---

### 问题 3: 自定义样式不生效

**开发环境**：需要在 `custom.css` 中定义，CDN 不支持 `@apply`

**生产环境**：
```bash
# 检查 custom.css 是否被合并
docker run --rm ledger-test \
  cat /rails/app/assets/stylesheets/application.css | grep "my-custom"
```

---

## 最佳实践

### 1. 样式优先级

```
Tailwind 工具类 > 自定义 CSS > 覆盖样式
```

### 2. 添加新样式流程

```bash
# 1. 在视图中使用 Tailwind 类
# 2. 本地测试（开发环境，CDN）
# 3. 如果需要自定义样式，添加到 custom.css
# 4. 推送代码，GitHub Actions 自动编译
# 5. 部署后自动使用编译版本
```

### 3. 保持同步

```bash
# 定期检查 tailwind.config.js 是否与 CDN 配置一致
# TailwindConfigHelper.theme_extensions 应该匹配 tailwind.config.js
```

---

## 总结

✅ **开发环境**：
- 使用 CDN
- 即改即看
- 快速开发
- 控制台有警告（正常）

✅ **生产环境**：
- 编译本地 CSS
- 性能优化
- 无外部依赖
- 生产就绪

✅ **自动化**：
- GitHub Actions 自动编译
- Docker 构建包含完整样式
- 无需手动干预

**两全其美的方案：开发快速 + 生产高性能！** 🎉