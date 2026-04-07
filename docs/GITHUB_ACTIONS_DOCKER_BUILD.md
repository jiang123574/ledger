# GitHub Actions Docker 构建流程说明

## 构建流程 ✅

### GitHub Actions 工作流

`.github/workflows/docker.yml` 会执行以下步骤：

```yaml
1. Checkout 代码
2. 设置 Docker Buildx
3. 构建 Docker 镜像（多平台：amd64, arm64）
4. 推送到 GitHub Container Registry
```

### Dockerfile 构建步骤

`Dockerfile` 在构建阶段执行：

```dockerfile
1. 安装系统依赖
2. 安装 Node.js 和 npm
3. 安装 Ruby gems
4. 安装 npm 包 (npm install --omit=dev)
5. 编译 bootsnap
6. ✨ 编译 Tailwind CSS (./bin/build-css)  ← 新增
7. 预编译 assets (rails assets:precompile)
8. 清理不必要的文件
```

## Tailwind CSS 编译流程

### bin/build-css 脚本

```bash
#!/bin/bash
# 1. 检查 Node.js
# 2. 安装 npm 依赖（如果需要）
# 3. 编译 Tailwind CSS
./node_modules/.bin/tailwindcss \
    -i ./app/assets/stylesheets/tailwind.css \
    -o ./app/assets/stylesheets/tailwind_output.css \
    --minify

# 4. 合并样式文件
cat tailwind_output.css custom.css > application.css
```

### 关键文件

| 文件 | 用途 | Git 状态 |
|------|------|---------|
| package.json | npm 依赖定义 | ✅ 已追踪 |
| tailwind.config.js | Tailwind 配置 | ✅ 已追踪 |
| tailwind.css | Tailwind 输入文件 | ✅ 已追踪 |
| custom.css | 自定义样式 | ✅ 已追踪 |
| tailwind_output.css | 编译输出 | ⚠️ 不追踪（生成文件）|
| application.css | 最终合并文件 | ⚠️ 不追踪（生成文件）|

### .gitignore 更新

```gitignore
# Tailwind CSS 编译输出（不追踪）
app/assets/stylesheets/tailwind_output.css
app/assets/stylesheets/application.css
!app/assets/stylesheets/custom.css
```

## 验证构建

### 本地测试

```bash
# 1. 执行编译
./bin/build-css

# 2. 检查输出
ls -lh app/assets/stylesheets/application.css

# 3. 测试 Docker 构建
docker build -t ledger-test .

# 4. 检查镜像大小
docker images ledger-test
```

### Docker 构建测试

```bash
# 构建并查看日志
docker build --progress=plain -t ledger-test . 2>&1 | grep "Tailwind"
# 应该看到：🎨 编译 Tailwind CSS...
#          ✅ Tailwind CSS 编译完成！
```

### 运行容器测试

```bash
# 运行容器
docker run --rm -p 3000:80 ledger-test

# 访问测试
curl http://localhost:3000

# 检查 CSS 是否加载
curl -I http://localhost:3000/assets/application-*.css
```

## GitHub Actions 验证

### 查看构建日志

1. 访问 GitHub 仓库
2. 点击 Actions 标签
3. 查看最新的 workflow run
4. 展开 "Build and push Docker image" 步骤
5. 查找 Tailwind 编译日志：
   ```
   🎨 编译 Tailwind CSS...
   ⚙️  编译 Tailwind...
   🔗 合并样式文件...
   ✅ Tailwind CSS 编译完成！
   ```

### 构建输出

成功构建后，应该看到：

```
#13 [build 6/8] RUN ./bin/build-css
#13 0.123 🎨 编译 Tailwind CSS...
#13 0.456 ⚙️  编译 Tailwind...
#13 2.789 🔗 合并样式文件...
#13 2.890 ✅ Tailwind CSS 编译完成！

#14 [build 7/8] RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile
#14 2.123 I, [2026-04-07T14:00:00.000000 #1]  INFO -- : Writing public/assets/application-xxx.css
```

## 故障排查

### 问题1: Node.js 未安装

**错误**:
```
❌ 错误: Node.js 未安装
```

**解决**: 检查 Dockerfile 第 38-41 行是否安装了 Node.js

### 问题2: npm 包未安装

**错误**:
```
./bin/build-css: line 8: ./node_modules/.bin/tailwindcss: No such file
```

**解决**: 检查 Dockerfile 第 55-57 行是否执行了 `npm install`

### 问题3: tailwind.css 文件缺失

**错误**:
```
Error: Can't find './app/assets/stylesheets/tailwind.css'
```

**解决**: 确保 `tailwind.css` 已提交到 Git:
```bash
git add app/assets/stylesheets/tailwind.css
git commit -m "Add Tailwind CSS input file"
git push
```

### 问题4: 编译成功但样式丢失

**检查**:
```bash
# 在容器内检查
docker run --rm ledger-test cat /rails/app/assets/stylesheets/application.css | wc -l
# 应该 > 1000 行

# 检查是否包含 Tailwind 基础样式
docker run --rm ledger-test head -1 /rails/app/assets/stylesheets/application.css
# 应该看到: /*! tailwindcss v3.4.1 | MIT License
```

## 多平台支持

Docker 构建支持两个平台：

- ✅ `linux/amd64` (x86_64)
- ✅ `linux/arm64` (Apple Silicon, AWS Graviton)

Tailwind 编译是纯 JavaScript，跨平台兼容，无需额外配置。

## 镜像大小优化

### 清理策略

Dockerfile 第 66-78 行会清理：

```bash
rm -rf node_modules          # 删除 node_modules（已在编译后）
rm -rf .git .github          # 删除 Git 相关
rm -rf test spec             # 删除测试文件
rm -rf *.md                  # 删除文档
```

### 最终镜像大小

预估：
- 基础镜像: ~150MB
- Rails 应用: ~200MB
- 编译后的 assets: ~5-10MB
- **总计**: ~350-400MB

## CI/CD 流程图

```
GitHub Push (main)
    ↓
GitHub Actions 触发
    ↓
Docker Build (多平台)
    ├─ 安装依赖
    ├─ 编译 Tailwind CSS ← 新增
    ├─ 预编译 assets
    └─ 清理文件
    ↓
推送到 ghcr.io
    ↓
部署就绪 ✅
```

## 总结

✅ **GitHub Actions 会自动编译 Tailwind CSS**

关键点：
1. ✅ Dockerfile 第 65 行添加了 `./bin/build-css`
2. ✅ 构建脚本完整且经过测试
3. ✅ 所有必要文件已提交到 Git
4. ✅ 多平台支持（amd64, arm64）
5. ✅ 镜像优化（清理 node_modules）

**无需额外配置，推送代码后会自动构建包含完整 Tailwind CSS 的 Docker 镜像！**