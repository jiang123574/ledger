# Ledger 移动端响应式设计

## 概述

本次更新借鉴 Sure 项目的移动端设计，实现了完整的移动端响应式支持。

## 核心特性

### 1. Safe Area 支持

为 iPhone X 及以上设备的刘海屏和底部 Home Indicator 提供完整支持：

```html
<!-- 顶部安全区域 -->
<div class="pt-[calc(env(safe-area-inset-top)+0.5rem)]">

<!-- 底部安全区域 -->
<div class="pb-[calc(0.5rem+env(safe-area-inset-bottom))]">

<!-- 主内容区域 -->
<main class="pt-[calc(3.5rem+env(safe-area-inset-top))] pb-[calc(5rem+env(safe-area-inset-bottom))]">
```

### 2. 触摸友好设计

所有交互元素的最小点击区域为 44px × 44px（iOS 人机界面指南推荐）：

```css
.tap-target {
  min-width: 44px;
  min-height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
}
```

### 3. 移动端侧边栏

- 从左侧滑入的侧边栏
- 全屏遮罩层
- 平滑过渡动画（300ms）
- 支持滑动手势关闭
- 支持 ESC 键关闭
- 打开时锁定 body 滚动

### 4. 响应式断点

使用 Tailwind CSS 的 `lg:` 断点（1024px）区分桌面和移动端：

```html
<!-- 仅在桌面端显示 -->
<div class="hidden lg:block">...</div>

<!-- 仅在移动端显示 -->
<div class="lg:hidden">...</div>
```

## 文件结构

```
app/
├── views/
│   └── layouts/
│       ├── application.html.erb    # 主布局（已更新）
│       ├── _sidebar.html.erb       # 桌面侧边栏（已更新）
│       └── _mobile_nav.html.erb    # 移动端底部导航（已更新）
├── javascript/
│   ├── application.js              # 主 JS 文件（已更新）
│   └── controllers/
│       └── mobile_layout_controller.js  # 移动端布局控制器（新增）
├── assets/
│   └── stylesheets/
│       └── application.css         # 样式文件（已更新）
└── helpers/
    └── application_helper.rb       # Helper 方法（已更新）
```

## 使用方法

### 打开/关闭侧边栏

```html
<!-- 打开按钮 -->
<button data-action="click->mobile-layout#openSidebar">
  打开菜单
</button>

<!-- 关闭按钮 -->
<button data-action="click->mobile-layout#closeSidebar">
  关闭
</button>
```

### 手势支持

- **从左边缘右滑**：打开侧边栏
- **向左滑动**：关闭侧边栏

### 键盘支持

- **ESC**：关闭侧边栏

## CSS 工具类

```css
/* Safe Area */
.safe-area-top { padding-top: env(safe-area-inset-top); }
.safe-area-bottom { padding-bottom: env(safe-area-inset-bottom); }

/* 触摸友好 */
.tap-target { min-width: 44px; min-height: 44px; }

/* 移动端卡片 */
.mobile-card { background: #fff; border-radius: 0.75rem; }

/* 移动端列表项 */
.mobile-list-item { min-height: 60px; padding: 1rem; }

/* 移动端输入框 */
.mobile-input { font-size: 16px; min-height: 44px; }
```

## 测试建议

1. **iPhone X 及以上设备**：测试刘海屏和底部 Home Indicator
2. **不同屏幕尺寸**：测试 320px - 768px 范围
3. **触摸交互**：确保所有按钮可轻松点击
4. **侧边栏手势**：测试滑动手势是否流畅
5. **横竖屏切换**：确保布局正确响应

## 浏览器兼容性

- iOS Safari 11.2+（Safe Area 支持）
- Chrome Android 69+
- Samsung Internet 8.2+
- Desktop browsers (responsive breakpoints)

## 后续优化建议

1. **PWA 支持**：添加 manifest.json 和 service worker
2. **离线缓存**：实现关键页面的离线访问
3. **触摸反馈**：添加 haptic feedback 支持
4. **动画优化**：使用 CSS transform 替代 top/left
5. **性能监控**：添加 Core Web Vitals 监控