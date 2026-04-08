# TODO

## 优化任务

### [低优先级] entry_card_renderer.js 双模板重构

**当前状态**：
- 桌面端和移动端使用两套独立的 HTML 模板
- 数据字段不一致（`data-field="date"` vs `data-field="date-mobile"`）
- 增加维护成本

**建议方案**：
- 使用 CSS 响应式替代双模板
- 统一数据字段命名
- 通过 Tailwind 的响应式类控制显示/隐藏

**相关文件**：
- `app/javascript/entry_card_renderer.js`（第 3-49 行 ENTRY_CARD_TEMPLATE）
- `app/views/accounts/index.html.erb`（静态渲染模板）

**优先级**：低
**影响**：不影响功能，仅优化代码可维护性