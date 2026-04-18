# TODO

更新时间：2026-04-17
维护规则：本文件为项目唯一的活跃待办清单，所有新的待办、优化任务只更新本文件。
已完成任务请查看 DONE.md。

---

## P1 - 移动端全面优化

### 评估背景

对项目进行了全面移动端评估，发现以下问题需要系统性修复。用户手机：小米 K80（Android），通过 Turbo Native WebView 访问。

### 问题概览

| 类别 | 问题数 | 严重程度 |
|------|--------|---------|
| Hover 效果在触摸设备失效 | 320 处 | 高 |
| 表格在小屏溢出 | 83 处 | 高 |
| 模态框小屏适配 | 198 处 | 中 |
| Fixed/Sticky 元素重叠 | 73 处 | 中 |
| Turbo Native Strada 缺失 | 全局 | 中 |
| 触摸目标尺寸不一致 | 多处 | 中 |

---

### 16. Hover 效果触摸设备兼容

**优先级**: 高
**预估工期**: 1-2 天
**状态**: ⏳ 待完成

**问题描述**:
- 全项目 320+ 处 `hover:` 类使用
- 移动端触摸后 hover 状态会"粘住"，需再次点击才能消除
- 部分交互依赖 hover 显示操作按钮（如删除按钮），移动端无法触发

**受影响页面** (按严重程度):
1. `accounts/index.html.erb` — 62 处 hover（交易卡片操作按钮依赖 hover 显示）
2. `budgets/index.html.erb` — 26 处
3. `dashboard/show.html.erb` — 15 处
4. `receivables/index.html.erb` — 14 处
5. `settings/_data_content.html.erb` — 13 处
6. `payables/index.html.erb` — 17 处

**优化方案**:
1. 为依赖 hover 显示的交互元素添加 `active:` 触摸状态
2. 将"hover 显示操作"改为"长按菜单"或"滑动操作"模式
3. 使用 `@media (hover: hover)` 媒体查询限制 hover 效果仅在支持的设备生效
4. 添加 `.group` + `group-hover:` 组合选择器，确保移动端有替代交互

**验证清单**:
- [ ] 所有交互元素在触摸设备上有可用的替代交互
- [ ] 触摸后无"粘住"的 hover 状态
- [ ] 操作按钮在移动端始终可见或有明确的触发方式

---

### 17. 表格小屏溢出修复

**优先级**: 高
**预估工期**: 1 天
**状态**: ⏳ 待完成

**问题描述**:
- 全项目 83 处 `<table>` 使用
- 多列表格在 360px 宽度屏幕（小米 K80）水平溢出
- `overflow-x-auto` 在部分页面缺失

**受影响页面**:
1. `dashboard/show.html.erb` — 30 处 table（报表区域）
2. `budgets/index.html.erb` — 11 处
3. `reports/show.html.erb` — 5 处
4. `settings/_categories_content.html.erb` — 4 处
5. `imports/pixiu.html.erb` — 4 处
6. `imports/preview.html.erb` — 3 处

**优化方案**:
1. 检查所有 table 容器是否包裹 `overflow-x-auto`
2. 对移动端隐藏非关键列（使用 `hidden sm:table-cell`）
3. 报表类页面考虑移动端改为卡片布局（参考已有 `accounts/index.html.erb` 的做法）
4. 添加横向滚动提示（可选）

**验证清单**:
- [ ] 所有表格在 360px 宽度下无水平溢出
- [ ] 关键数据列在移动端可见
- [ ] 非关键列有合理的隐藏/折叠策略

---

### 18. 模态框移动端适配

**优先级**: 中
**预估工期**: 1 天
**状态**: ⏳ 待完成

**问题描述**:
- 全项目 198 处 modal/dialog 使用
- 部分模态框内容过多，在小屏幕上溢出视口
- 底部操作按钮可能被虚拟键盘遮挡
- 全屏模态框与 mobile nav bar 层级冲突

**受影响页面**:
1. `accounts/index.html.erb` — 66 处（新建交易模态框）
2. `budgets/index.html.erb` — 20 处
3. `settings/_contacts_content.html.erb` — 15 处
4. `receivables/index.html.erb` — 15 处
5. `payables/index.html.erb` — 16 处

**优化方案**:
1. 模态框内容区域添加 `max-h-[80vh] overflow-y-auto`
2. 表单类模态框在移动端改为底部抽屉（bottom sheet）样式
3. 虚拟键盘弹出时自动调整模态框位置
4. 确认模态框 z-index 高于 mobile nav bar（当前 z-50）

**验证清单**:
- [ ] 所有模态框在 360px 宽度下内容完整可见
- [ ] 表单输入时虚拟键盘不遮挡操作按钮
- [ ] 模态框可正常滚动

---

### 19. Fixed/Sticky 元素层级与重叠

**优先级**: 中
**预估工期**: 0.5 天
**状态**: ⏳ 待完成

**问题描述**:
- 全项目 73 处 `fixed`/`sticky` 元素
- 当前 z-index 层级: header z-30, sidebar z-50, mobile nav z-50, modal z-50
- 多个 z-50 元素可能导致层级冲突
- 部分页面的 sticky 表头在小屏遮挡内容

**当前层级**:
| 元素 | z-index |
|------|---------|
| Mobile Top Header | z-30 |
| Mobile Sidebar Overlay | z-40 |
| Mobile Sidebar | z-50 |
| Mobile Bottom Nav | z-50 |
| Modal (推测) | z-50 |

**优化方案**:
1. 统一 z-index 方案: nav 50, sidebar 60, modal 70, toast 80
2. 检查所有 sticky 表头，移动端取消 sticky 或缩小高度
3. 确保 mobile header + bottom nav 不遮挡页面内容

**验证清单**:
- [ ] 无元素层级冲突
- [ ] 页面内容不被 fixed 元素遮挡
- [ ] 滚动时 sticky 表头表现正常

---

### 20. Turbo Native Strada 桥接适配

**优先级**: 中
**预估工期**: 2-3 天
**状态**: ⏳ 待完成

**问题描述**:
- 项目已配置 Turbo Native，但未实现 Strada bridge adapter
- Android 端无法调用原生能力（相机、文件选择、分享等）
- 部分 Web 功能在 WebView 中受限

**缺失能力**:
1. 文件上传（导入功能无法选择本地文件）
2. 分享功能（无法分享报表）
3. 原生导航标题同步
4. 返回键处理

**优化方案**:
1. 实现 Strada Bridge adapter（Android 端）
2. Web 端添加 Strada 组件检测和调用
3. 文件选择器 fallback 到 Web 方案
4. 处理 Android 返回键（Turbo 历史导航）

**验证清单**:
- [ ] Android 端文件选择器可用
- [ ] 返回键正确导航
- [ ] 原生标题与页面标题同步

---

### 21. 触摸目标尺寸与可访问性

**优先级**: 中
**预估工期**: 0.5 天
**状态**: ⏳ 待完成

**问题描述**:
- Apple 推荐最小触摸目标 44×44px，Android 推荐 48×48dp
- 部分图标按钮、文本链接触摸目标过小
- 密集排列的操作按钮容易误触

**优化方案**:
1. 所有可点击元素添加 `min-w-[44px] min-h-[44px]`（已有部分应用，需补齐）
2. 列表项增加行高和内边距
3. 关键操作按钮间距加大

**验证清单**:
- [ ] 所有可交互元素触摸目标 ≥ 44px
- [ ] 密集操作区域无误触问题

---

### 22. `[class*="hover:bg-"]` 选择器优化

**优先级**: 低
**来源**: PR #119 code review
**状态**: ⏳ 待完成

**问题**: CSS 选择器 `[class*="hover:bg-"]` 偏宽泛，任何 class 名包含 `hover:bg-` 的元素都会被选中（含组内嵌套的 `group-hover:bg-*`）。当前模板中未出现此类嵌套，风险低但不够精确。

**优化方案**: 改为逐个类名硬编码排除，或改用 `[class^="hover:bg-"]` + `[class*=" hover:bg-"]` 组合。

---

### 23. `button.p-1` 触摸目标尺寸覆盖

**优先级**: 低
**来源**: PR #119 code review
**状态**: ⏳ 待完成

**问题**: 全局 CSS `button.p-1 { min-width: 44px; min-height: 44px; }` 会覆盖所有 `p-1` 按钮的尺寸，可能影响桌面端紧凑图标的布局。`p-1` 在 Tailwind 中是 padding 4px，意味着 icon-only 按钮也会被强制 44px。

**优化方案**: 限制在移动端视口内生效（`@media (max-width: 640px)`），或改为给具体页面按钮类加触摸目标尺寸，而非全局覆盖。

---

### 24. `overflow-hidden` 改 `overflow-x-auto` 圆角边界

**优先级**: 低
**来源**: PR #119 code review
**状态**: ⏳ 待完成

**问题**: 将 `.rounded-lg` + `overflow-hidden` 改为 `overflow-x-auto` 后，横向滚动内容会溢出圆角边界。视觉上有轻微毛刺。

**优化方案**: 在外层保留 `overflow-hidden` 圆角容器，内层用独立的 `overflow-x-auto` 容器包裹表格。

---

### 25. 移动端/桌面端模板代码重复

**优先级**: 低
**来源**: PR #119 code review
**状态**: ⏳ 待完成

**问题**: 应收款/应付款页面桌面端和移动端条目渲染逻辑完全独立（`_entry_list.html.erb` vs `_entry_mobile.html.erb`），DOM 结构差异大，维护成本高。后续新增字段需两边同步修改。

**优化方案**: 考虑用共享 partial + 布局参数（`locals: { layout: :mobile }`）统一桌面/移动端渲染逻辑，减少重复代码。当前模式与项目已有惯例一致，非紧急。

---

### 26. `@category_parent_map` 只加载一层父级

**优先级**: 低
**来源**: PR #127 code review
**状态**: ⏳ 待完成

**问题**: PlansController 中 `@category_parent_map` 只加载直接父级。`build_full_name_in_memory` 递归查找 parent_map 构建 full_name，如果未来有 level 2+ 的分类（孙级），map 中找不到祖先会返回 nil。

**优化方案**: 改用 `Category.all.index_by(&:id)` 加载全部分类，或在 `build_full_name_in_memory` 中做安全检查。当前数据只有一层父子关系，非紧急。

---

### 27. `openEditPlanModal` 参数过多

**优先级**: 低
**来源**: PR #127 code review
**状态**: ⏳ 待完成

**问题**: `openEditPlanModal` 已有 14 个参数，随着功能增加会继续膨胀。模板中的 onclick 调用也越来越长，可读性差。

**优化方案**: 改为传对象参数 `openEditPlanModal({id, name, type, ...})`，或用 data 属性存储参数。非本次引入的问题，可与其他 modal 统一处理。

---

## P2 - 图表功能增强 ✅ 已完成

### 28. 数据可视化图表优化

**优先级**: 中
**预估工期**: 2-3 天
**状态**: ✅ 已完成

**已完成图表**:
- [x] Dashboard 近6个月收支柱状图 (`bar_chart_controller.js`)
- [x] Dashboard 净资产趋势折线图 (`net_worth_trend_controller.js`)
- [x] Reports 日历热力图 (`calendar_heatmap_controller.js`)
- [x] Reports 瀑布图 (`waterfall_chart_controller.js`)
- [x] Reports 桑基图 (已修复数据生成 bug)
- [x] 删除 Dashboard "最近交易" 和 "预算仪表盘" 区块

**技术细节**:
- Chart.js UMD 放在 `vendor/assets/javascripts/`
- Stimulus controller 注册在 `app/javascript/controllers/index.js` + `config/importmap.rb`

---

## 文档维护规则

1. **本文件（TODO.md）**：唯一的活跃待办清单
2. **DONE.md**：已完成任务历史记录
3. **AGENTS.md**：AI agent 运行必需配置，不可删除
4. **README.md**：项目标准说明，不可删除
5. **app/components/ds/README.md**：组件库文档，不可删除

---

**最后更新**: 2026-04-16
**维护者**: 开发团队
