# Turbo Android 开发计划

创建时间：2026-04-13
分支：feature/turbo-android
状态：📋 计划阶段

---

## 概述

将 Ledger 记账应用封装为 Android 原生应用，使用 Turbo Native for Android 框架。
基于现有的 Hotwire (Turbo + Stimulus) 技术栈，以最小改动实现 Android App。

---

## 架构设计

```
┌─────────────────────────────────────────┐
│           Android 原生壳                  │
│  ┌──────────┐ ┌──────────┐ ┌─────────┐  │
│  │ 原生导航  │ │ 原生Tab  │ │ 原生桥接 │  │
│  │ Toolbar  │ │ BottomNav│ │ Camera  │  │
│  └──────────┘ └──────────┘ └─────────┘  │
│  ┌──────────────────────────────────┐   │
│  │         Turbo WebView            │   │
│  │    加载你现有的 Rails 页面         │   │
│  │    Hotwire/Stimulus 全部生效      │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
              ↕ HTTP/WebSocket
┌─────────────────────────────────────────┐
│         Rails 服务端 (现有)               │
│  + Turbo Native 路由适配                 │
└─────────────────────────────────────────┘
```

---

## 开发阶段

### Phase 1: Rails 端 Turbo Native 适配
**预估工期：2-3 天**

#### 1.1 Turbo Native 检测
- [ ] 创建 `turbo_native_helper.rb`，提供 `turbo_native_app?` 方法
- [ ] 从 User-Agent 检测 Turbo Native 客户端
- [ ] 在 `ApplicationController` 中注入 Turbo Native 标识

```ruby
# app/helpers/turbo_native_helper.rb
module TurboNativeHelper
  def turbo_native_app?
    request.user_agent.to_s.include?("Turbo Native")
  end
end
```

#### 1.2 路由适配
- [ ] 为 Turbo Native 添加专属路径前缀
- [ ] 确认所有页面支持 Turbo Drive 导航
- [ ] 检查重定向是否使用 `status: :see_other`（303）

#### 1.3 视图适配
- [ ] 移除/隐藏对 App 无意义的元素（下载链接、PWA 提示）
- [ ] 调整导航结构适配原生 Toolbar
- [ ] 确保所有页面有正确的 `<turbo-frame>` 标签

#### 1.4 Meta 标签
- [ ] 为每个页面添加 `turbo-native-control` meta 标签
- [ ] 配置原生导航行为（标题、按钮、动作）

```erb
<% if turbo_native_app? %>
  <meta name="turbo-native-control" content="...">
<% end %>
```

---

### Phase 2: Android 工程搭建
**预估工期：3-5 天**

#### 2.1 工程初始化
- [ ] 创建 Android 工程目录 `android/`
- [ ] 配置 Gradle 依赖（turbo, kotlin）
- [ ] 配置 minSdk 26, targetSdk 34
- [ ] 配置包名（如 `com.ledger.app`）

```kotlin
// build.gradle.kts (Module)
dependencies {
    implementation("dev.hotwire:turbo:7.1.0")
    implementation("androidx.webkit:webkit:1.9.0")
}
```

#### 2.2 核心 Activity
- [ ] `MainActivity` — 主入口，持有 Turbo Session
- [ ] `TurboWebViewFragment` — 页面渲染容器
- [ ] 配置 Turbo Session 初始化

```kotlin
class MainActivity : AppCompatActivity(), TurboActivity {
    lateinit var turboSession: TurboSession
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        // 初始化 Turbo Session
        turboSession = TurboSession(this, findViewById(R.id.web_view))
        turboSession.visit("https://your-ledger-url.com")
    }
}
```

#### 2.3 导航架构
- [ ] 底部 Tab 导航（账户、分类、统计、设置）
- [ ] 使用 `NavHostFragment` 管理导航
- [ ] 配置 Deep Link 支持

```
Navigation Graph:
├── Tab 1: 账户首页 → /accounts
├── Tab 2: 预算管理 → /budgets
├── Tab 3: 报表统计 → /reports
└── Tab 4: 设置     → /settings
```

#### 2.4 原生 UI 组件
- [ ] 原生 Toolbar（从页面 meta 获取标题）
- [ ] 原生返回按钮
- [ ] Loading 指示器
- [ ] 错误页面（网络不可用）

---

### Phase 3: 原生功能桥接
**预估工期：2-3 天**

#### 3.1 文件选择（发票/导入）
- [ ] 桥接原生文件选择器
- [ ] 支持图片选择（拍发票）
- [ ] 支持 CSV/Excel 文件导入
- [ ] 将文件传给 WebView 的 input[type=file]

#### 3.2 通知
- [ ] 集成 Firebase Cloud Messaging（FCM）
- [ ] 账单到期提醒
- [ ] 定期交易提醒
- [ ] Rails 端添加推送通知接口

#### 3.3 生物识别
- [ ] 原生指纹/面部识别登录
- [ ] 通过 JavaScript Bridge 与 WebView 通信
- [ ] 替代 Session 登录流程

#### 3.4 分享
- [ ] 原生分享功能（报表截图、数据导出）
- [ ] 接收其他 App 分享的数据

---

### Phase 4: 打包与发布
**预估工期：1-2 天**

#### 4.1 签名配置
- [ ] 生成 Release Keystore
- [ ] 配置 Gradle 签名
- [ ] 配置 ProGuard/R8 混淆

#### 4.2 资源配置
- [ ] App 图标（多分辨率）
- [ ] 启动页（Splash Screen）
- [ ] App 名称、描述

#### 4.3 构建与测试
- [ ] Debug 构建测试
- [ ] Release 构建测试
- [ ] 不同 Android 版本兼容测试（API 26-34）

#### 4.4 发布
- [ ] Google Play Console 配置
- [ ] 上传 AAB
- [ ] 或内部测试分发（APK 侧载）

---

## 技术选型

| 项目 | 选择 | 理由 |
|------|------|------|
| 语言 | Kotlin | Android 官方推荐，Java 互操作 |
| 框架 | Turbo Native 7.x | 与 Rails Hotwire 天然配合 |
| 构建 | Gradle (Kotlin DSL) | 现代 Android 标准 |
| 最低版本 | Android 8.0 (API 26) | 覆盖 95%+ 设备 |
| 推送 | Firebase Cloud Messaging | 免费，Google 官方 |
| 导航 | Jetpack Navigation | Tab + 页面导航标准方案 |

---

## 目录结构

```
android/
├── app/
│   ├── src/main/
│   │   ├── java/com/ledger/app/
│   │   │   ├── MainActivity.kt
│   │   │   ├── navigation/
│   │   │   │   ├── MainNavHost.kt
│   │   │   │   └── TabFragment.kt
│   │   │   ├── turbo/
│   │   │   │   ├── TurboWebViewFragment.kt
│   │   │   │   └── TurboSessionNavHostFragment.kt
│   │   │   ├── bridge/
│   │   │   │   ├── NativeBridge.kt
│   │   │   │   ├── FilePickerBridge.kt
│   │   │   │   └── BiometricBridge.kt
│   │   │   └── notification/
│   │   │       └── FCMService.kt
│   │   ├── res/
│   │   │   ├── layout/
│   │   │   ├── values/
│   │   │   ├── drawable/
│   │   │   └── navigation/
│   │   └── AndroidManifest.xml
│   └── build.gradle.kts
├── build.gradle.kts
├── settings.gradle.kts
└── gradle.properties
```

---

## Rails 端需要改动的文件

| 文件 | 改动 |
|------|------|
| `app/helpers/turbo_native_helper.rb` | 新建，Turbo Native 检测 |
| `app/controllers/application_controller.rb` | 引入 helper |
| `app/views/layouts/application.html.erb` | 条件渲染 App 专属元素 |
| `config/routes.rb` | 可能加 API 端点 |
| `app/controllers/api/external/` | 推送通知端点 |

---

## 里程碑

| 阶段 | 目标 | 验收标准 |
|------|------|----------|
| M1 | Rails 适配完成 | 所有页面支持 Turbo Native 访问 |
| M2 | Android 壳完成 | 能在手机上打开 App，浏览所有页面 |
| M3 | 原生功能完成 | 文件选择、推送、生物识别可用 |
| M4 | 发布就绪 | Release 包可安装，功能完整 |

---

## 风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| Turbo Native 文档较少 | 开发速度慢 | 参考示例项目 + 源码 |
| WebView 性能 | 页面加载慢 | 预加载 + 缓存策略 |
| Android 版本碎片化 | 兼容性问题 | minSdk 26 覆盖面够广 |
| 推送服务配置复杂 | 延期 | 可以放到最后做 |

---

## 参考资料

- [Turbo Android 官方文档](https://github.com/hotwired/turbo-android)
- [Turbo Native 文档](https://turbo.hotwired.dev/handbook/native)
- [Hey.com Android 实现参考](https://github.com/basecamp/hey/tree/main/android)
- [Kamal 部署配置](https://kamal-deploy.org)
