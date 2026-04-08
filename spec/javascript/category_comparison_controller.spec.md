# CategoryComparisonController Test Specification

## 修复验证：Tailwind v4 重要性修饰符语法

### 修复背景
在 PR #63 的 Tailwind v4 迁移中，重要性修饰符 `!` 的位置从类名末尾（v3 语法 `class!`）改为开头（v4 语法 `!class`）。但此控制器中的代码仍然使用了 v3 语法，导致 Tailwind v4 编译器无法识别这些类名，样式重要性标志失效。

修复内容：
- 第 216 行：从 `'opacity-100!', 'h-1.5!'` 改为 `'!opacity-100', '!h-1.5'`
- 第 238 行：从 `'opacity-100!', 'h-1.5!'` 改为 `'!opacity-100', '!h-1.5'`

### 测试用例

#### TC-1: 选中行时应用高亮样式
```
输入：用户点击分类对比表格中的某一行
预期行为：
  1. 该行的背景色变为 surface-inset（或 dark:surface-dark-inset）
  2. 该行添加蓝色 ring 边框（ring-blue-500/30）
  3. 该行内的月度单元格（monthly-cell）中的高度条（.h-0.5 或 .h-1）样式变为：
     - opacity-100（完全不透明，使用 ! 重要性确保覆盖）
     - h-1.5（高度变为 1.5）
预期结果：
  - 样式应该正确应用且在其他 CSS 规则中不会被覆盖
  - 分类对比页面右侧标题更新为选中的分类名称
  - 折线图重新渲染显示该分类的趋势数据
验证方式：
  1. 打开浏览器 DevTools → Elements 标签
  2. 点击表格一行
  3. 检查该行对应的 DOM 节点：
     - 应该有 class="... bg-surface-inset ring-1 ring-blue-500/30 ..."
     - 内部的 .h-0.5 或 .h-1 元素应该有 class 包含 opacity-100 和 h-1.5
  4. 在 Styles 面板中验证：
     - opacity-100: { opacity: 1 } !important （或存在 !important）
     - height: 0.375rem （对应 h-1.5）
```

#### TC-2: 切换选中行时移除旧行样式
```
输入：用户先点击第一行，再点击第二行
预期行为：
  1. 第一行的高亮样式应该完全移除
  2. 第二行的新高亮样式应该应用
预期结果：
  - 第一行恢复原始样式
  - 第二行变为高亮状态
  - 没有样式重叠或冗余
验证方式：
  1. 在 DevTools Elements 面板中观察 class 属性的变化
  2. 确认 classList.remove() 和 classList.add() 都正确执行
```

#### TC-3: 深色模式兼容性
```
输入：用户在深色模式下使用分类对比
预期行为：
  - 高亮行背景色使用 dark:bg-surface-dark-inset
  - 其他样式与浅色模式保持一致
预期结果：
  - 无视觉冲突或样式未应用的情况
验证方式：
  1. 在系统设置中切换到深色模式
  2. 打开分类对比页面
  3. 点击表格行，观察样式应用
  4. 在即时检查（Inspect）中确认 dark:* 类名被识别
```

### 手动测试步骤（开发环境）

1. 启动开发服务器
   ```bash
   bin/dev
   ```

2. 在浏览器中进入"分类对比"页面（通常在报表 → 分类对比）

3. 打开浏览器 DevTools（F12）→ Elements 标签

4. 在分类列表表格中点击任意一行

5. 观察：
   - 该行背景色是否变为浅灰色（surface-inset）
   - 该行是否有细蓝色边框
   - 该行内的月度数据条是否从淡灰变为实心黑色/深灰

6. 在 DevTools 中选中任意高亮行的单元格，检查 Styles 面板：
   - 应该看到 `opacity: 1 !important`（或 CSS 中的 `!important` 标记）
   - 应该看到 `height: 0.375rem`（对应 h-1.5）

7. 点击另一行：
   - 第一行应该立即恢复原始样式
   - 新行应该变为高亮状态

### 深色模式测试

1. 打开浏览器开发者工具 → 右上角菜单（⋮）→ More tools → Rendering

2. 在 Rendering 面板中找到 "Emulate CSS media feature prefers-color-scheme"，选择 "dark"

3. 或直接在系统设置中切换深色模式

4. 重复手动测试步骤 4-7，确认样式在深色模式下也正确应用

### 自动化测试建议

如果项目后续添加 JavaScript 测试框架或集成测试，可以增加如下测试：

```javascript
describe('CategoryComparisonController', () => {
  describe('selectRow()', () => {
    it('applies correct classes with v4 syntax', () => {
      const row = document.createElement('tr');
      row.dataset.categoryId = 'test-id';
      
      // Mock the category data
      controller.categoriesValue = {
        'test-id': { kind: 'income', name: 'Salary' }
      };

      controller.selectRow(row);

      // Check that classList.add was called with correct v4 syntax
      expect(row.classList.contains('!opacity-100')).toBe(true);
      expect(row.classList.contains('!h-1.5')).toBe(true);
      expect(row.classList.contains('opacity-100!')).toBe(false); // Old v3 syntax
    });

    it('removes old row styles before applying new ones', () => {
      const row1 = document.createElement('tr');
      const row2 = document.createElement('tr');
      
      // Select row 1
      controller._selectedRow = row1;
      row1.classList.add('!opacity-100', '!h-1.5');
      
      // Select row 2
      controller.selectRow(row2);
      
      // Old row should have styles removed
      expect(row1.classList.contains('!opacity-100')).toBe(false);
      expect(row1.classList.contains('!h-1.5')).toBe(false);
      
      // New row should have styles added
      expect(row2.classList.contains('!opacity-100')).toBe(true);
      expect(row2.classList.contains('!h-1.5')).toBe(true);
    });
  });
});
```

---

## 验证检查清单

- [ ] 浅色模式：点击表格行，高亮样式正确应用
- [ ] 浅色模式：行内月度数据条显示为实心（不透明）
- [ ] 浅色模式：选中行的背景色为 surface-inset 灰色
- [ ] 浅色模式：选中行有蓝色 ring 边框
- [ ] 深色模式：背景色为 surface-dark-inset
- [ ] 切换选中行：旧行样式完全移除
- [ ] 切换选中行：新行样式正确应用
- [ ] Console：无关于 "opacity-100!" 或 "h-1.5!" 的错误
- [ ] 检查器：!opacity-100 和 !h-1.5 类名在最终 CSS 中正确解析

