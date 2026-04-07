# TODO - 可选优化项

本文档记录了 PR #62 中识别出的可选优化项，这些优化不影响核心功能，但可以提升性能或减少资源占用。

---

## 🔧 优化项列表

### 1. 清理 Docker 镜像中的 devDependencies

**优先级**: 中

**问题描述**:
- Dockerfile 使用 `npm install` 安装所有依赖（包括 devDependencies）
- Tailwind CSS 编译后，devDependencies 不再需要
- 增加镜像大小约 5-10MB

**优化方案**:
```dockerfile
# 在 bin/build-css 执行后清理
RUN npm install && npm cache clean --force
RUN ./bin/build-css
RUN npm prune --production  # 清理开发依赖
```

**影响**:
- 减少镜像大小 5-10MB
- 无功能影响

**文件位置**:
- `Dockerfile:56-57`

**相关文档**:
- `docs/PR_REVIEW_VERIFICATION.md` 问题 7

---

### 2. 优化 `sort_by!` 性能（O(n²) → O(n)）

**优先级**: 低

**问题描述**:
```ruby
# 当前实现 - O(n²)
entries.sort_by! { |e| entry_ids.index(e.id) }
```

**影响**:
- 每页 15-50 条记录时，性能足够快
- 如果支持更大分页（如 200 条），可能需要优化

**优化方案**:
```ruby
# 优化为 O(n)
entry_id_to_index = entry_ids.each_with_index.to_h
entries.sort_by! { |e| entry_id_to_index[e.id] }
```

**性能对比**:
```
当前: O(50²) = 2,500 次操作
优化后: O(50) = 50 次操作
```

**文件位置**:
- `app/controllers/accounts_controller.rb:85-86`
- `app/controllers/accounts_controller.rb:172-173`

**相关文档**:
- `docs/PR_REVIEW_VERIFICATION.md` 问题 3

---

### 3. 移除缓存 key 中的冗余 `sort_direction`

**优先级**: 低

**问题描述**:
```ruby
# build_filter_cache_key (line 575-577)
"#{...}_#{sort_direction}"

# build_entries_query (line 612-614)
sort_direction = params[:sort_direction]&.downcase || "desc"
```

两处都处理了 `sort_direction`，存在冗余。

**优化方案**:

**方案 1**: 从缓存 key 中移除 sort_direction
```ruby
def build_filter_cache_key
  "#{params[:account_id]}_#{params[:type]}_#{params[:period_type]}_#{params[:period_value]}_#{params[:search]}_#{Array(params[:category_ids]).sort.join(',')}"
  # 移除 sort_direction
end
```

**方案 2**: 统一在一处处理
```ruby
# 只在 build_entries_query 中处理排序
# build_filter_cache_key 不需要包含 sort_direction
```

**影响**:
- 减少代码冗余
- 略微减少缓存 key 数量
- 无功能影响

**文件位置**:
- `app/controllers/accounts_controller.rb:575-577`
- `app/controllers/accounts_controller.rb:612-614`

**相关文档**:
- `docs/PR_REVIEW_VERIFICATION.md` 问题 4

---

## 📊 优先级说明

### 中优先级
- **清理 devDependencies**: 减少镜像大小，改善部署效率

### 低优先级
- **性能优化**: 当前性能足够，仅在更大规模时需要
- **代码清理**: 功能正常，仅改善代码可维护性

---

## 🎯 实施建议

### 何时实施

1. **清理 devDependencies**: 可以在下次部署前实施
2. **性能优化**: 当支持更大分页（>100条）时实施
3. **代码清理**: 在重构或维护时顺带处理

### 实施顺序

1. 先实施 **清理 devDependencies**（影响最大）
2. 再实施 **代码清理**（最简单）
3. 最后实施 **性能优化**（需要测试）

---

## ✅ 验证清单

实施优化后需要验证：

### devDependencies 清理
- [ ] Docker 构建成功
- [ ] Tailwind CSS 正常编译
- [ ] 镜像大小减少
- [ ] 功能无影响

### 性能优化
- [ ] 排序结果正确
- [ ] 分页正常工作
- [ ] 性能提升（可测量）
- [ ] 无副作用

### 代码清理
- [ ] 缓存功能正常
- [ ] 排序方向正确
- [ ] 无功能回归

---

## 📝 相关链接

- **PR**: https://github.com/jiang123574/ledger/pull/62
- **验证报告**: docs/PR_REVIEW_VERIFICATION.md
- **Tailwind 文档**: docs/TAILWIND_FINAL_CONFIG.md

---

## 🔄 更新日志

- **2026-04-07**: 初始创建，记录 PR #62 的可选优化项