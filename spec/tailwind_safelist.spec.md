# Tailwind.css Safelist Configuration Test

## 修复背景
在 PR #63 的 Tailwind CSS v4 迁移中，动态类名的 safelist 配置使用了无效的 `@source inline()` 语法。Tailwind v4 中应该使用标准的 `@safelist` 指令声明需要保留的动态类名，否则在生产构建中会被 tree-shake 移除。

### 修复内容
将 `tailwind.css` 中的以下配置：
```css
@source inline('grid-cols-[2fr_3fr_2fr_2fr_2fr_2fr_1fr]');
@source inline('hover:bg-surface-hover');
@source inline('hover:bg-surface-dark-hover');
@source inline('dark:hover:bg-surface-dark-hover');
```

改为标准 v4 语法：
```css
@safelist [
  'grid-cols-[2fr_3fr_2fr_2fr_2fr_2fr_1fr]',
  'hover:bg-surface-hover',
  'hover:bg-surface-dark-hover',
  'dark:hover:bg-surface-dark-hover'
];
```

### 测试用例

#### TC-1: 开发环境编译成功
```
测试：运行 dev 环境的 Tailwind watch
命令：bin/dev
预期结果：
  - Tailwind 编译过程无警告或错误
  - Console 输出显示 "@safelist" 被正确识别
  - CSS 输出包含所有 safelist 中的类名
验证方式：
  1. 开启两个终端，一个运行 bin/dev
  2. 另一个终端观察 Tailwind 输出
  3. 搜索警告信息，如 "Unknown directive: @source inline"
```

#### TC-2: 生产构建包含动态类名
```
测试：运行生产资源编译
命令：RAILS_ENV=production bin/rails assets:precompile
预期结果：
  - 编译成功，无错误
  - 最终 css 文件（在 public/assets/）包含所有 safelist 类名
验证方式：
  1. 运行编译命令
  2. 查看生成的 CSS 文件大小（应该包含预期的类名）
  3. 使用命令搜索确认类名存在：
     \`\`\`bash
     grep "grid-cols-\\[2fr_3fr" public/assets/application-*.css
     grep "hover:bg-surface-hover" public/assets/application-*.css
     \`\`\`
  4. 确认搜索结果非空（表示类名被保留）
```

#### TC-3: 动态类名在分类对比表中生效
```
测试场景：分类对比表格在 Rails 视图中动态设置 grid-cols-[2fr_3fr_2fr_2fr_2fr_2fr_1fr]
预期行为：
  - 生产环境中访问分类对比页面
  - 表格列布局应该正确应用（2:3:2:2:2:2:1 的列宽比例）
  - 不应该有样式丢失或布局混乱
预期结果：
  - 表格各列宽度按设计显示
  - 无浏览器 DevTools 警告（如未应用的规则）
验证方式：
  1. 构建生产资源
  2. 在生产模式启动 Rails（\`RAILS_ENV=production rails s\`）
  3. 打开分类对比页面
  4. 检查表格布局是否符合预期
  5. 在 DevTools → Styles 中查找 grid-cols 规则，确认已应用
```

#### TC-4: hover 样式在表格行上生效
```
测试场景：用户滑动鼠标在分类比较表的行上
预期行为：
  - 行背景色应该变为 hover:bg-surface-hover（浅色模式）或 hover:bg-surface-dark-hover（深色模式）
  - 样式应该在生产环境中正确显示
预期结果：
  - 悬停时行高亮显示
  - 无样式缺失
验证方式：
  1. 在生产模式下打开分类对比页面
  2. 用鼠标悬停到表格行上
  3. 观察背景色变化
  4. 在 DevTools 中选中行元素，查看 Styles：
     3.1. 当鼠标不悬停时，应该没有 hover:* 样式
     3.2. 当鼠标悬停时，应该应用 bg-surface-hover
```

### 自动化验证脚本

在 CI/CD 流程中可以添加以下检查：

```bash
#!/bin/bash
# 检查 safelist 是否存在于最终 CSS 中

SAFELIST_CLASSES=(
  'grid-cols-\\\[2fr_3fr_2fr_2fr_2fr_2fr_1fr\\\]'
  'hover:bg-surface-hover'
  'hover:bg-surface-dark-hover'
  'dark:hover:bg-surface-dark-hover'
)

CSS_FILE=$(find public/assets -name "application-*.css" | head -1)

if [ -z "$CSS_FILE" ]; then
  echo "❌ No compiled CSS found"
  exit 1
fi

ALL_FOUND=true

for CLASS in "${SAFELIST_CLASSES[@]}"; do
  if grep -q "$CLASS" "$CSS_FILE"; then
    echo "✅ Found: $CLASS"
  else
    echo "❌ Missing: $CLASS"
    ALL_FOUND=false
  fi
done

if $ALL_FOUND; then
  echo "✅ All safelist classes present in compiled CSS"
  exit 0
else
  echo "❌ Some safelist classes missing from compiled CSS"
  exit 1
fi
```

### Tailwind 编译验证

1. **开发环境检查**：
   ```bash
   bin/dev
   # 在另一个终端中查看输出，确认 @safelist 被识别
   ```

2. **查看编译后的 CSS 结构**：
   ```bash
   # 检查开发 CSS 中是否包含 safelist 类名
   grep "grid-cols-\[2fr_3fr" app/assets/builds/tailwind.css
   ```

3. **生产构建验证**：
   ```bash
   RAILS_ENV=production bin/rails assets:precompile
   grep "grid-cols-\[2fr_3fr" public/assets/application-*.css
   ```

### 检查未来 Tailwind 更新

- 如果项目升级 Tailwind CSS 版本，需要验证 `@safelist` 指令是否仍然有效
- 检查 Tailwind 官方文档中 safelist 的最新语法

---

## 验证检查清单

- [ ] 开发环境 `bin/dev` 运行时无关于 @safelist 的编译警告
- [ ] 开发环境 CSS 包含所有 safelist 类名
- [ ] 生产构建成功完成（`rails assets:precompile`）
- [ ] 生产 CSS 文件包含 `grid-cols-[2fr_3fr_2fr_2fr_2fr_2fr_1fr]`
- [ ] 生产 CSS 文件包含 `hover:bg-surface-hover`
- [ ] 生产环境分类对比页面表格布局正确
- [ ] 生产环境表格行 hover 样式生效
- [ ] DevTools 中无样式未应用的警告

