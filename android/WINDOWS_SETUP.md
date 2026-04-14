# Windows 编译环境搭建指南

## 1. 安装 JDK 21（必须，不要用更高版本）

> ⚠️ **JDK 25 不兼容 Gradle 8.5，会导致编译失败！必须用 JDK 21**

下载地址：https://adoptium.net/temurin/releases/

- 选择 **JDK 21**
- 操作系统：Windows
- 架构：x64
- 下载 `.msi` 安装包，安装时勾选 **"Add to PATH"**

安装后验证：
```powershell
java -version
# 应显示: openjdk version "21.x.x"
```

## 2. 安装 Android Studio

下载地址：https://developer.android.com/studio

安装后打开，首次启动会自动下载基础组件。

## 3. 安装 Android SDK 组件

打开 Android Studio → **More Actions** → **SDK Manager**

### SDK Platforms（勾选安装）
- [x] **Android 16.0 (API 36)** — `compileSdk = 36`

### SDK Tools（切换到 SDK Tools 标签页，勾选安装）
- [x] **Android SDK Build-Tools 36.1.0** — `buildToolsVersion = "36.1.0"`
- [x] **Android SDK Command-line Tools (latest)**
- [x] **Android SDK Platform-Tools**
- [x] **Android Emulator**（可选，如果要用模拟器）

点击 **Apply** 下载安装。

## 4. 配置环境变量

在 PowerShell（管理员）中执行：

```powershell
# 设置 ANDROID_HOME
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:LOCALAPPDATA\Android\Sdk", "User")

# 添加到 PATH
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$newPaths = "$env:LOCALAPPDATA\Android\Sdk\platform-tools;$env:LOCALAPPDATA\Android\Sdk\emulator;$env:LOCALAPPDATA\Android\Sdk\build-tools\36.1.0"
[System.Environment]::SetEnvironmentVariable("Path", "$newPaths;$currentPath", "User")
```

> ⚠️ **关闭并重新打开 PowerShell/Android Studio 使环境变量生效**

验证：
```powershell
echo $env:ANDROID_HOME
# 应显示: C:\Users\你的用户名\AppData\Local\Android\Sdk

adb --version
# 应显示版本信息
```

## 5. 克隆项目

```powershell
cd D:\
git clone https://github.com/jiang123574/ledger.git
cd ledger
git checkout feature/turbo-android
```

## 6. 在 Android Studio 中打开项目

1. **File → Open** → 选择 `D:\ledger\android` 文件夹
2. 等待 Gradle Sync 完成（首次会下载大量依赖，可能需要 5-10 分钟）
3. 如果 Sync 失败，点击 **Try Again**（可能是网络超时）

### Gradle Sync 常见问题

如果 sync 报错找不到依赖，在 Android Studio 的 **Terminal** 中执行：

```powershell
# 清理缓存重试
cd android
.\gradlew.bat clean
.\gradlew.bat assembleDebug --no-daemon
```

## 7. 编译 APK

### 方式 A：Android Studio（推荐）
1. 点击顶部绿色三角 ▶️ **Run** 按钮
2. 选择连接的手机或模拟器
3. 等待编译安装

### 方式 B：命令行
```powershell
cd D:\ledger\android
.\gradlew.bat assembleDebug
```

编译成功后 APK 位置：
```
D:\ledger\android\app\build\outputs\apk\debug\app-debug.apk
```

## 8. 连接真机调试

1. 手机开启 **USB 调试**
   - 小米 K80：设置 → 我的设备 → 全部参数与信息 → 连点「MIUI版本」7 次
   - 设置 → 更多设置 → 开发者选项 → 打开「USB调试」
2. USB 连接电脑，手机上点击 **允许调试**
3. 验证连接：
   ```powershell
   adb devices
   # 应显示: xxxxxx    device
   ```

## 9. 抓取崩溃日志

```powershell
# 清空旧日志
adb logcat -c

# 启动 app，抓取崩溃
adb logcat -s AndroidRuntime:E ActivityManager:E
```

---

## 版本清单

| 组件 | 版本 |
|------|------|
| JDK | 21.x.x（必须 21，不要用 25） |
| Gradle | 8.5 |
| Android Gradle Plugin | 8.2.2 |
| Kotlin | 1.9.22 |
| compileSdk | 36 |
| minSdk | 26 |
| targetSdk | 36 |
| buildToolsVersion | 36.1.0 |
