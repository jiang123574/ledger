# TODO

更新时间：2026-04-13
维护规则：本文件为项目唯一的活跃待办清单，所有新的待办、优化任务只更新本文件。
已完成任务请查看 DONE.md。

---

## P9 - 项目审查后续优化

### 9.3 安全加固

**优先级**: 中
**预估工期**: 1-2 天
**状态**: ⏳ 待优化

**问题描述**:
- 需要检查 CSRF 保护是否完整
- 需要验证 SQL 注入防护
- 需要检查 XSS 防护
- 需要添加 Content Security Policy (CSP)

**优化方案**:
1. 运行 Brakeman 安全扫描
2. 检查所有表单的 CSRF 令牌
3. 验证所有用户输入都经过适当转义
4. 添加 CSP 头

**验证清单**:
- [ ] Brakeman 扫描无高风险漏洞
- [ ] 所有表单有 CSRF 保护
- [ ] 用户输入适当转义
- [ ] CSP 头已配置

---

### 9.4 性能监控

**优先级**: 中
**预估工期**: 1 天
**状态**: ⏳ 待优化

**问题描述**:
- 缺乏生产环境性能监控
- 需要慢查询监控
- 需要 APM 工具

**优化方案**:
1. 添加 Skylight 或 New Relic APM
2. 配置慢查询日志
3. 设置性能警报

**验证清单**:
- [ ] APM 工具已安装配置
- [ ] 慢查询监控已启用
- [ ] 性能警报已设置

---

## P4 - 账单金额功能后续优化

### 10. 前端重构 - 账单相关全局函数改为 Stimulus controller

**优先级**: 中
**预估工期**: 2-3 小时
**状态**: ⏳ 待完成

**背景**:
- 当前账单相关功能使用全局函数污染命名空间
- `window.loadBillsWithCount`
- `window.showStatementInputModal`
- `window.saveStatementAmount`

**目标**:
- 封装为 Stimulus controller
- 与项目现有风格一致（参考 `entry_list_controller.js`）

**相关文件**:
- `app/views/accounts/index.html.erb`
- `app/javascript/controllers/bill_statement_controller.js`（新建）

---

### 11. 测试补充 - 账单金额功能测试

**优先级**: 中
**预估工期**: 3-4 小时
**状态**: ⏳ 待完成

**背景**:
- 账单金额功能缺少测试覆盖
- 需要验证正向/反向计算逻辑

**目标**:
- `test/models/bill_statement_test.rb` - 模型验证测试
- `test/controllers/accounts_controller_test.rb` - `create_bill_statement` action 测试
- `test/models/account_test.rb` - `bill_cycles_with_statement` 方法测试
  - 正向计算测试
  - 反向计算测试
  - 精度测试

---

### 12. 路由优化 - 改为 RESTful 风格

**优先级**: 低
**预估工期**: 1 小时
**状态**: ⏳ 待完成

**背景**:
- 当前路由命名不 RESTful
- `post :create_bill_statement`

**目标**:
```ruby
# 当前
post :create_bill_statement

# 建议
resources :bill_statements, only: [:create], controller: "accounts/bill_statements"
```

---

### 13. 模型验证错误消息国际化

**优先级**: 低
**预估工期**: 0.5 小时
**状态**: ⏳ 待完成

**背景**:
- `BillStatement` 模型验证缺少 i18n 错误消息

**目标**:
- 添加 `message:` 或使用 i18n

---

## 文档维护规则

1. **本文件（TODO.md）**：唯一的活跃待办清单
2. **DONE.md**：已完成任务历史记录
3. **AGENTS.md**：AI agent 运行必需配置，不可删除
4. **README.md**：项目标准说明，不可删除
5. **app/components/ds/README.md**：组件库文档，不可删除

---

**最后更新**: 2026-04-13
**维护者**: 开发团队