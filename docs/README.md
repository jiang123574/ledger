# 项目文档

本文件夹包含项目的详细技术文档。

## 文档索引

### Entry 模型（交易记录系统）

- **[ENTRY_MODEL_GUIDE.md](./ENTRY_MODEL_GUIDE.md)** - Entry 模型完整指南
- **[ENTRY_MODEL_SUMMARY.md](./ENTRY_MODEL_SUMMARY.md)** - Entry 模型总结
- **[ENTRY_IMPLEMENTATION_REPORT.md](./ENTRY_IMPLEMENTATION_REPORT.md)** - 实现报告
- **[ENTRY_QUICK_START.md](./ENTRY_QUICK_START.md)** - 快速开始

### Tailwind CSS 相关

- **[TAILWIND_FINAL_CONFIG.md](./TAILWIND_FINAL_CONFIG.md)** - Tailwind CSS 双模式配置（推荐阅读）
  - 开发环境使用 CDN
  - 生产环境编译本地 CSS
  - 完整配置说明

- **[TAILWIND_DUAL_MODE.md](./TAILWIND_DUAL_MODE.md)** - 双模式详细说明
  - 开发/生产环境对比
  - 工作流程图解
  - 最佳实践

- **[TAILWIND_COMPILE_SUCCESS.md](./TAILWIND_COMPILE_SUCCESS.md)** - 编译成功报告
- **[TAILWIND_BUILD.md](./TAILWIND_BUILD.md)** - 编译指南
- **[LOCAL_TAILWIND_STATUS.md](./LOCAL_TAILWIND_STATUS.md)** - 本地编译状态说明

### CDN 和资源加载

- **[CDN_FIX_SUMMARY.md](./CDN_FIX_SUMMARY.md)** - CDN 问题修复总结
  - CDN 加载失败问题
  - importmap 优化
  - 性能改进

### GitHub Actions 和部署

- **[GITHUB_ACTIONS_COMPLETE.md](./GITHUB_ACTIONS_COMPLETE.md)** - GitHub Actions 完整配置
  - 自动编译流程
  - Docker 构建步骤
  - 验证方法

- **[GITHUB_ACTIONS_DOCKER_BUILD.md](./GITHUB_ACTIONS_DOCKER_BUILD.md)** - Docker 构建详解
  - 构建流程图
  - 故障排查
  - 多平台支持

### Bug 修复

- **[DRAG_REORDER_FIX.md](./DRAG_REORDER_FIX.md)** - 拖动排序 Bug 修复
  - sort_order 逻辑问题
  - 刷新后顺序颠倒

- **[ALL_TRANSACTIONS_DRAG_FIX.md](./ALL_TRANSACTIONS_DRAG_FIX.md)** - 所有交易页面拖动功能
  - 跨账户排序限制
  - dragEnabled 参数控制

- **[CONSOLE_WARNINGS_FIX.md](./CONSOLE_WARNINGS_FIX.md)** - 控制台警告修复
  - JavaScript 可选链操作符误用
  - Tailwind CDN 警告处理

- **[CONSOLE_INFO_EXPLANATION.md](./CONSOLE_INFO_EXPLANATION.md)** - 控制台信息说明
  - WebVitals 性能指标
  - 浏览器扩展日志
  - 正常 vs 异常信息

- **[FIX_REPORT.md](./FIX_REPORT.md)** - 修复报告
- **[CODE_REVIEW_REPORT.md](./CODE_REVIEW_REPORT.md)** - 代码审查报告

### 数据迁移

- **[MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)** - 数据迁移指南
- **[OPTIMIZATION_SUMMARY.md](./OPTIMIZATION_SUMMARY.md)** - 优化总结

### 项目指南

- **[PROJECT_GUIDE.md](./PROJECT_GUIDE.md)** - 项目开发指南

---

## 快速导航

### 我是开发者，想了解...

**Entry 模型**:
→ [ENTRY_MODEL_GUIDE.md](./ENTRY_MODEL_GUIDE.md)

**Tailwind CSS 配置**:
→ [TAILWIND_FINAL_CONFIG.md](./TAILWIND_FINAL_CONFIG.md)

**部署到生产**:
→ [GITHUB_ACTIONS_COMPLETE.md](./GITHUB_ACTIONS_COMPLETE.md)

**修复拖动排序问题**:
→ [DRAG_REORDER_FIX.md](./DRAG_REORDER_FIX.md)

**控制台有警告**:
→ [CONSOLE_INFO_EXPLANATION.md](./CONSOLE_INFO_EXPLANATION.md)

---

## 文档编写规范

后续添加文档时，请：

1. **命名规范**: 使用大写蛇形命名（UPPER_SNAKE_CASE.md）
2. **位置**: 放在本 `docs/` 文件夹下
3. **更新索引**: 在本 README.md 中添加文档链接
4. **清晰分类**: 放在合适的分类下，或创建新分类

### 文档模板

```markdown
# 文档标题

## 问题/背景

简要描述问题或背景。

## 解决方案

详细说明解决方案。

## 验证

如何验证解决方案有效。

## 相关文件

列出修改的相关文件。

## 参考

相关链接或参考资料。
```

---

## 文档维护

- **创建日期**: 2026-04-07
- **最后更新**: 2026-04-07
- **维护者**: 开发团队

如果发现文档过时或有误，请及时更新或删除。