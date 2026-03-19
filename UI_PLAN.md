# UI 改造计划 - 基于 Sure 项目设计模式

## 目标

将 Sure 项目的设计系统模式应用到 Ledger 项目，提升 UI/UX 体验。

## 当前状态 vs 目标状态

| 模块 | 当前 | 目标 |
|------|------|------|
| 配色 | 默认 Tailwind | 自定义语义配色 (surface, container, primary, secondary) |
| 布局 | 简单顶部导航 | 响应式侧边栏 + 底部导航 |
| 组件 | 原生 HTML | Design System 组件库 |
| 交易列表 | 简单列表 | 12列网格 + 复选框 + 分类徽章 |
| Dashboard | 基础卡片 | 可拖拽/折叠区块 |

---

## 第一阶段：设计系统基础

### 1.1 配色系统
- [ ] 更新 `tailwind.config.js` 添加语义颜色
- [ ] 添加 surface, container, primary, secondary 等 CSS 变量
- [ ] 更新全局样式

### 1.2 DS 基础组件
- [ ] 创建 `app/components/ds/button_component.rb` - 按钮组件
- [ ] 创建 `app/components/ds/link_component.rb` - 链接组件
- [ ] 创建 `app/components/ds/icon_component.rb` - 图标组件 (使用 Heroicons)
- [ ] 创建 `app/components/ds/badge_component.rb` - 徽章组件
- [ ] 创建 `app/components/ds/dialog_component.rb` - 对话框组件
- [ ] 创建 `app/components/ds/tabs_component.rb` - 标签页组件
- [ ] 创建 `app/components/ds/card_component.rb` - 卡片组件

---

## 第二阶段：响应式布局

### 2.1 布局架构
- [ ] 创建 `app/views/layouts/_sidebar.html.erb` - 桌面端侧边栏
- [ ] 创建 `app/views/layouts/_mobile_nav.html.erb` - 移动端底部导航
- [ ] 更新 `application.html.erb` 使用新布局架构
- [ ] 添加布局 JavaScript 控制器

### 2.2 导航
- [ ] 更新顶部导航使用新设计
- [ ] 添加侧边栏导航项
- [ ] 添加移动端底部导航

---

## 第三阶段：核心页面改造

### 3.1 Dashboard
- [ ] 更新 Dashboard 布局为网格系统
- [ ] 创建仪表盘卡片组件
- [ ] 添加月份导航器
- [ ] 改进统计卡片显示

### 3.2 交易列表
- [ ] 更新交易列表使用 12 列网格
- [ ] 添加复选框批量选择
- [ ] 添加分类徽章显示
- [ ] 改进交易行组件
- [ ] 添加搜索和筛选功能

### 3.3 账户页面
- [ ] 更新账户卡片设计
- [ ] 改进余额显示
- [ ] 添加账户类型标签

### 3.4 分类页面
- [ ] 更新分类卡片设计
- [ ] 添加类型筛选标签

---

## 第四阶段：交互优化

### 4.1 表单
- [ ] 更新交易表单设计
- [ ] 添加交易类型切换 (支出/收入/转账)
- [ ] 改进金额输入

### 4.2 空状态
- [ ] 为各页面添加统一空状态组件

### 4.3 加载状态
- [ ] 添加骨架屏加载效果

---

## 第五阶段：收尾

### 5.1 测试
- [ ] 测试响应式布局
- [ ] 测试所有页面功能

### 5.2 文档
- [ ] 更新 AGENTS.md 添加 UI 组件使用规范

---

## 实施顺序

1. **配色系统** - 基础中的基础
2. **图标组件** - 其他组件依赖
3. **按钮/链接组件** - 快速见效
4. **卡片组件** - Dashboard 和列表使用
5. **布局架构** - 整体框架
6. **导航组件** - 页面跳转
7. **Dashboard 改造** - 核心页面
8. **交易列表改造** - 核心功能
9. **其他页面改造** - 账户、分类、预算
10. **表单和状态优化** - 细节打磨

---

## 预期效果

- 统一的视觉设计语言
- 良好的移动端体验
- 可复用的组件库
- 现代化的界面风格
