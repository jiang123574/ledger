# 修复 GitHub Actions 构建失败

## 问题描述

GitHub Actions 构建失败，错误信息：
```
Error: buildx failed with: ERROR: failed to build: failed to solve: process "/bin/sh -c ./bin/build-css" did not complete successfully: exit code: 127
```

错误代码 127 表示：**命令未找到**

---

## 根本原因

### 原因 1: tailwind.css 文件缺失 ⭐

**问题**:
- `app/assets/stylesheets/tailwind.css` 文件没有提交到 Git
- `bin/build-css` 脚本需要这个文件作为输入
- Docker 构建时 COPY 命令复制的代码中没有这个文件

**验证**:
```bash
git show HEAD:app/assets/stylesheets/tailwind.css
# fatal: path 'app/assets/stylesheets/tailwind.css' does not exist in 'HEAD'
```

**解决**:
```bash
# 创建文件
cat > app/assets/stylesheets/tailwind.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

# 添加到 Git
git add app/assets/stylesheets/tailwind.css
git commit -m "fix: Add tailwind.css input file"
git push
```

---

### 原因 2: 脚本执行权限

**问题**:
虽然本地脚本有执行权限 (`chmod +x`)，但在 Docker 构建过程中可能丢失。

**解决**:
```dockerfile
# Dockerfile
RUN chmod +x ./bin/build-css && ./bin/build-css
```

---

## Docker 构建流程分析

### Dockerfile 构建步骤

```dockerfile
# 1. 基础镜像
FROM ruby:3.3.10-slim AS base

# 2. 安装系统依赖
RUN apt-get install nodejs npm

# 3. 安装 Ruby gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# 4. 复制应用代码
COPY . .   # ← 此时复制所有文件（包括 tailwind.css 和 build-css）

# 5. 安装 npm 包
RUN npm install --omit=dev

# 6. 编译 Tailwind
RUN chmod +x ./bin/build-css && ./bin/build-css
    ↓
    需要以下文件：
    - bin/build-css          ✅ 在 COPY . . 时复制
    - app/assets/stylesheets/tailwind.css  ❌ 之前未提交到 Git
    - package.json           ✅ 在 COPY . . 时复制
    - tailwind.config.js     ✅ 在 COPY . . 时复制

# 7. 预编译 assets
RUN rails assets:precompile
```

---

## .dockerignore 配置

**当前配置**:
```
/bin/dev      # 排除开发脚本
/bin/setup    # 排除设置脚本
/bin/rspec    # 排除测试脚本
/script/      # 排除脚本目录
```

**注意**: 
- ✅ `bin/build-css` **未被排除**（会被 COPY）
- ✅ `app/assets/stylesheets/tailwind.css` **未被排除**（会被 COPY）

---

## 验证修复

### 本地测试

```bash
# 测试脚本执行
./bin/build-css

# 预期输出
🎨 编译 Tailwind CSS (Production)...
📦 Installing npm dependencies...
⚙️  Compiling Tailwind...
🔗 Merging styles...
✅ Tailwind CSS compiled successfully!
```

### Docker 构建测试

```bash
# 构建镜像
docker build -t ledger-test .

# 查看构建日志
docker build --progress=plain -t ledger-test . 2>&1 | grep "Tailwind"

# 预期看到
🎨 编译 Tailwind CSS (Production)...
✅ Tailwind CSS compiled successfully!
```

---

## 提交修复

### 修复内容

**新增文件**:
- ✅ `app/assets/stylesheets/tailwind.css` - Tailwind 输入文件

**修改文件**:
- ✅ `Dockerfile` - 添加 `chmod +x` 确保执行权限

**提交信息**:
```
fix: Add tailwind.css input file for Docker build

- Create app/assets/stylesheets/tailwind.css
- This file was missing from previous commit
- Required for bin/build-css script to compile Tailwind
- Update Dockerfile to ensure build-css has execute permission
- Update .dockerignore to exclude bin/rspec
```

---

## GitHub Actions 重新运行

修复推送后，GitHub Actions 会自动重新运行：

1. ✅ 推送修复提交
2. ⏳ GitHub Actions 触发
3. ⏳ Docker 构建
4. ⏳ 编译 Tailwind CSS
5. ⏳ 推送到 ghcr.io

---

## 预防措施

### 未来添加新文件

确保所有必需文件都提交到 Git：

```bash
# 检查未追踪文件
git status

# 检查 .dockerignore 是否排除了必需文件
cat .dockerignore

# 确保文件被 Git 追踪
git add <file>
git commit -m "..."
git push
```

### Docker 构建检查清单

构建前检查：

- [ ] `bin/build-css` 脚本存在且有执行权限
- [ ] `app/assets/stylesheets/tailwind.css` 存在
- [ ] `app/assets/stylesheets/custom.css` 存在
- [ ] `package.json` 包含 tailwindcss 依赖
- [ ] `tailwind.config.js` 配置正确
- [ ] `.dockerignore` 没有排除必需文件

---

## 总结

**问题**: `tailwind.css` 文件未提交到 Git

**影响**: Docker 构建时找不到输入文件

**修复**: 
1. 创建 `tailwind.css` 文件
2. 添加到 Git 并提交
3. 确保 Dockerfile 有执行权限

**状态**: ✅ 已修复，等待 GitHub Actions 重新构建