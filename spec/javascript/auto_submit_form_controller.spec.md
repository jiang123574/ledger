# AutoSubmitFormController Test Specification

## 修复验证：blur 事件正确性

### 测试背景
此控制器用于在表单输入框失焦或内容改变时自动提交表单。在 PR #63 中，`getEventType()` 方法误将 DOM 事件名 "blur" 改为 Tailwind CSS 类名 "blur-sm"，导致功能完全失效。

修复内容：
- 第 24 行：`blur-sm` → `blur`
- 第 38 行：`blur-sm` → `blur`

### 测试用例

#### TC-1: TextInput 类型触发 blur 事件
```
输入：<input type="text" data-action="auto-submit-form#handleInput" />
预期行为：用户在文本框输入内容，按 Tab 键移出焦点
预期结果：触发 "blur" 事件，表单自动提交
验证方式：
  1. 检查浏览器 DevTools → Network tab，确认有 POST 请求
  2. 检查 JavaScript console，无 "blur-sm" 相关错误
```

#### TC-2: TextArea 类型触发 blur 事件
```
输入：<textarea data-action="auto-submit-form#handleInput"></textarea>
预期行为：用户在文本区输入内容，按 Ctrl+Tab 或点击外部移出焦点
预期结果：触发 "blur" 事件，表单自动提交
验证方式：
  1. 检查浏览器 DevTools → Network tab，确认有 POST 请求
  2. 检查 JavaSc console，无 "blur-sm" 相关错误
```

#### TC-3: 其他输入类型触发正确事件
```
输入：<input type="email" /> 或 <input type="number" /> 等
预期行为：
  - email/search → "blur" 事件
  - number/date → "change" 事件
  - checkbox/radio → "change" 事件
验证方式：在浏览器 DevTools 中打开 Events 面板，确认事件类型正确
```

### 手动测试步骤（开发环境）

1. 启动开发服务器
   ```bash
   bin/dev
   ```

2. 在浏览器中打开包含自动提交表单的页面（如交易编辑页面）

3. 打开浏览器 DevTools（F12）→ Console 标签

4. 在文本输入框中输入内容，按 Tab 移出焦点

5. 观察：
   - 表单应该自动提交（页面可能刷新或显示成功消息）
   - Console 中不应该有错误信息
   - Network tab 应该显示新请求

### 自动化测试建议

如果项目后续添加 JavaScript 测试框架（如 Jest），可以增加如下测试：

```javascript
describe('AutoSubmitFormController', () => {
  describe('getEventType()', () => {
    it('returns "blur" for text input', () => {
      const input = document.createElement('input');
      input.type = 'text';
      const result = controller.getEventType(input);
      expect(result).toBe('blur');
    });

    it('returns "blur" for email input', () => {
      const input = document.createElement('input');
      input.type = 'email';
      const result = controller.getEventType(input);
      expect(result).toBe('blur');
    });

    it('returns "blur" for textarea', () => {
      const textarea = document.createElement('textarea');
      const result = controller.getEventType(textarea);
      expect(result).toBe('blur');
    });

    it('returns "change" for number input', () => {
      const input = document.createElement('input');
      input.type = 'number';
      const result = controller.getEventType(input);
      expect(result).toBe('change');
    });
  });
});
```

---

## 验证检查清单

- [ ] 文本框输入后失焦，表单自动提交
- [ ] 文本区输入后失焦，表单自动提交
- [ ] 浏览器 Console 中无 "blur-sm" 错误
- [ ] Network tab 显示正确的 POST 请求
- [ ] 数字、日期等其他输入类型的事件触发正确

