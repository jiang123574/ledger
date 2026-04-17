# ADR-003: Turbo Native 移动端适配

**日期**: 2026-04-12
**状态**: 已完成

## 背景

项目需要移动端支持，但不想维护独立的 iOS/Android 应用。选择 Turbo Native 方案，用 Rails + Hotwire 构建原生移动应用的 WebView 容器。

## 决策

使用 Turbo Native + Strada 框架：

- Android 端使用 Turbo Android SDK
- Web 端通过 Turbo 检测原生环境，调用 Strada 桥接原生功能
- 页面使用 `<turbo-frame>` 实现局部刷新，避免全页重载

## 关键技术点

1. **JS 兼容**：Turbo 替换 body 时 inline script 重新执行，需用 IIFE 包裹避免 `const`/`let` 重复声明
2. **事件重绑定**：局部刷新后需在 `reinitializePageScripts` 中重新绑定事件
3. **BASE_URL**：URL 必须带尾部斜杠，Java `URL.getPath()` 对无尾部斜杠 URL 返回 null

## 影响

- 复用现有 Rails 视图，无额外维护成本
- 部分页面需特殊处理（如选择器、模态框）
- Android SDK 初始化需注意 fragment 生命周期

## 相关文件

- `app/javascript/controllers/`
- `config/importmap.rb`
- Android 项目（独立仓库）
