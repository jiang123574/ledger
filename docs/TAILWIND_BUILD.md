# Tailwind CSS 编译说明

## 当前状态

CDN依赖已被移除，需要编译本地CSS文件以获得完整样式。

## 快速修复（推荐）

### 方案 1: 重新编译 Tailwind CSS（长期解决方案）

```bash
# 1. 安装依赖
npm install --save-dev tailwindcss postcss autoprefixer

# 2. 创建 Tailwind 输入文件
cat > app/assets/stylesheets/tailwind.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

# 3. 编译
npx tailwindcss -i ./app/assets/stylesheets/tailwind.css \
    -o ./app/assets/stylesheets/tailwind_compiled.css \
    --minify

# 4. 合并到 application.css
# （注意：需要先备份当前的 application.css）
mv app/assets/stylesheets/application.css app/assets/stylesheets/application.css.backup
cat app/assets/stylesheets/tailwind_compiled.css > app/assets/stylesheets/application.css

# 5. 重启 Rails 服务器
```

### 方案 2: 临时使用备用 CDN

如果编译遇到问题，可以临时在 `app/views/layouts/application.html.erb` 中添加备用CDN：

```erb
<!-- 在 <%= stylesheet_link_tag :application %> 之前添加 -->
<script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
```

## 为什么移除 CDN？

1. **性能问题**: CDN连接失败导致页面加载缓慢
2. **可靠性**: 某些网络环境无法访问特定CDN
3. **最佳实践**: 生产环境应使用本地编译的CSS

## 当前 CSS 文件说明

- `application.css`: 自定义样式（23KB）
- 缺少: Tailwind CSS 基础样式（需要编译）

## importmap CDN 改进

已将以下依赖改为使用更可靠的 esm.sh CDN:

- ✅ Chart.js: `esm.sh/chart.js@4.4.0`
- ✅ Floating UI: `esm.sh/@floating-ui/*`
- ✅ Hotwired: `esm.sh/@hotwired/*`

## 验证

编译完成后，检查：
```bash
# CSS 文件大小应显著增加（> 1MB）
ls -lh app/assets/stylesheets/application.css

# 页面样式正常显示
curl http://localhost:3000/dashboard
```