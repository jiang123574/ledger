# Ledger Android App 发布指南

## 📋 发布流程概览

```
生成 Keystore → 配置签名 → 构建 AAB → 上传 Play Store → 填写信息 → 提交审核
```

## 🔐 第一步：生成签名 Keystore

```bash
# 在项目根目录运行
./scripts/generate_keystore.sh
```

按提示填写信息后，会生成：
- `android/app/keystore/ledger-release.jks` — 签名文件
- `android/keystore.properties` — Gradle 签名配置

⚠️ **Keystore 丢失 = 无法更新 App，请务必安全备份！**

## 🏗️ 第二步：构建

```bash
# 查看当前版本
./scripts/version.sh show

# 升级版本号（可选）
./scripts/version.sh bump minor  # 1.0.0 → 1.1.0

# 构建 Debug APK（测试用）
./scripts/build_android.sh debug

# 构建 Release APK（侧载分发用）
./scripts/build_android.sh release

# 构建 Release AAB（Play Store 用）
./scripts/build_android.sh bundle
```

## 🧪 第三步：测试

### 模拟器测试
```bash
# 启动模拟器后
cd android
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

### 真机测试
```bash
# 连接手机，开启 USB 调试
adb devices  # 确认设备已连接
./scripts/build_android.sh debug
adb install app/build/outputs/apk/debug/app-debug.apk
```

### 侧载分发（不通过 Play Store）
```bash
# 构建 Release APK
./scripts/build_android.sh release

# 直接发给测试人员安装
# 需要在手机设置中允许「安装未知来源应用」
```

## 📱 第四步：Google Play Console 配置

### 4.1 创建应用
1. 登录 [Google Play Console](https://play.google.com/console)
2. 点击「创建应用」
3. 填写：
   - 应用名称：记账本
   - 默认语言：简体中文
   - 应用或游戏：应用
   - 免费或付费：免费

### 4.2 填写商店信息
- **简短说明**：个人记账系统，简洁高效
- **完整说明**：（详细功能介绍）
- **应用图标**：512×512 PNG
- **功能图形**：1024×500 PNG
- **屏幕截图**：至少 2 张，手机截图
- **应用类别**：财务
- **联系方式**：邮箱

### 4.3 内容分级
1. 进入「内容分级」问卷
2. 选择「财务」类别
3. 回答问题（无暴力/赌博内容）
4. 获取分级结果

### 4.4 目标受众和内容
- 目标年龄段：18+
- 隐私政策 URL（必需）：需要部署一个隐私政策页面

## 🚀 第五步：发布

### 内部测试
1. Play Console → 测试 → 内部测试
2. 上传 AAB 文件
3. 添加测试人员邮箱
4. 分享测试链接

### 正式发布
1. Play Console → 发布 → 生产环境
2. 上传 AAB 文件
3. 填写版本说明
4. 选择国家/地区
5. 提交审核（通常 1-7 天）

## 📐 App 图标规范

| 用途 | 尺寸 | 格式 |
|------|------|------|
| Play Store 图标 | 512×512 | PNG (32-bit, 带 Alpha) |
| 自适应图标 | 108×108 (432×432 原图) | XML (已配置) |
| 功能图形 | 1024×500 | PNG 或 JPG |
| 截图 | 16:9 或 9:16 | PNG 或 JPG |

## 📝 版本说明模板

```
v1.0.0 - 首次发布

✨ 新功能：
• 账户管理 - 多账户、多货币
• 交易记录 - 收入/支出/转账
• 分类预算 - 层级分类、月度预算
• 应收应付 - 报销/结算追踪
• 报表统计 - 年度/月度报表

🔧 技术特性：
• Turbo Native 原生体验
• 生物识别登录
• 文件选择（拍照记账）
• 离线支持
```

## ⚠️ 常见问题

### APK 安装失败
- 检查 `minSdk` 版本是否兼容目标设备
- Debug APK 和 Release APK 签名不同，需先卸载再安装

### Play Store 审核被拒
- 缺少隐私政策 → 需要部署隐私政策页面
- 权限声明不完整 → 检查 AndroidManifest.xml
- 内容分级不正确 → 重新填写分级问卷

### 版本号管理
- `versionCode`：每次发布必须递增（整数）
- `versionName`：用户可见的版本号（语义化版本）
- Play Store 要求每次上传的 `versionCode` 必须大于当前线上版本
