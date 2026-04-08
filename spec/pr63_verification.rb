#!/usr/bin/env ruby
# Test verification script for PR #63 fixes
# Usage: ruby spec/pr63_verification.rb

require_relative '../config/environment'

puts "=" * 80
puts "  PR #63 修复验证脚本"
puts "=" * 80

# 测试 1: auto_submit_form_controller.js
puts "\n[TEST 1] auto_submit_form_controller.js - blur 事件正确性"
puts "-" * 80

controller_code = File.read('app/javascript/controllers/auto_submit_form_controller.js')

tests_passed = 0
tests_total = 2

# 检查第 24 行是否返回 "blur" 而非 "blur-sm"
if controller_code.include?('case "text"') && controller_code.include?('case "email"')
  lines = controller_code.split("\n")
  text_case_idx = lines.find_index { |l| l.include?('case "text"') }
  next_lines = lines[(text_case_idx)..(text_case_idx + 2)]
  
  if next_lines.join.include?('return "blur"') && !next_lines.join.include?('return "blur-sm"')
    puts "✅ 第 24 行: text/email/search 事件类型为 'blur'"
    tests_passed += 1
  else
    puts "❌ 第 24 行: text/email/search 事件类型不正确"
  end
else
  puts "❌ 无法找到查询的 case 语句"
end
tests_total += 1

# 检查第 38 行是否返回 "blur" 而非 "blur-sm"
if controller_code.include?('case "textarea"')
  lines = controller_code.split("\n")
  textarea_case_idx = lines.find_index { |l| l.include?('case "textarea"') }
  return_line = lines[textarea_case_idx + 1].to_s
  
  if return_line.include?('return "blur"') && !return_line.include?('return "blur-sm"')
    puts "✅ 第 39 行: textarea 事件类型为 'blur'"
    tests_passed += 1
  else
    puts "❌ 第 39 行: textarea 事件类型不正确"
  end
else
  puts "❌ 无法找到 textarea 的 case 语句"
end

puts "\n✨ 结果: #{tests_passed}/#{tests_total} 通过"

# 测试 2: category_comparison_controller.js
puts "\n[TEST 2] category_comparison_controller.js - Tailwind v4 语法"
puts "-" * 80

category_code = File.read('app/javascript/controllers/category_comparison_controller.js')

cat_tests_passed = 0
cat_tests_total = 2

# 检查是否使用 v4 语法 (!class)
if !category_code.include?("'opacity-100!'") && !category_code.include?('"opacity-100!"')
  puts "✅ 不存在旧的 v3 语法 'opacity-100!'"
  cat_tests_passed += 1
else
  puts "❌ 发现旧的 v3 语法 'opacity-100!'"
end
cat_tests_total += 1

if !category_code.include?("'h-1.5!'") && !category_code.include?('"h-1.5!"')
  puts "✅ 不存在旧的 v3 语法 'h-1.5!'"
  cat_tests_passed += 1
else
  puts "❌ 发现旧的 v3 语法 'h-1.5!'"
end

# 检查是否使用 v4 语法
if category_code.include?("'!opacity-100'") || category_code.include?('"!opacity-100"')
  puts "✅ 使用新的 v4 语法 '!opacity-100'"
  cat_tests_passed += 1
else
  puts "❌ 未找到新的 v4 语法 '!opacity-100'"
end
cat_tests_total += 1

if category_code.include?("'!h-1.5'") || category_code.include?('"!h-1.5"')
  puts "✅ 使用新的 v4 语法 '!h-1.5'"
  cat_tests_passed += 1
else
  puts "❌ 未找到新的 v4 语法 '!h-1.5'"
end

puts "\n✨ 结果: #{cat_tests_passed}/#{cat_tests_total} 通过"

# 测试 3: tailwind.css
puts "\n[TEST 3] tailwind.css - @safelist 配置"
puts "-" * 80

tailwind_code = File.read('app/assets/stylesheets/tailwind.css')

tw_tests_passed = 0
tw_tests_total = 2

# 检查是否移除了无效的 @source inline()
if !tailwind_code.include?('@source inline')
  puts "✅ 已移除无效的 @source inline() 语法"
  tw_tests_passed += 1
else
  puts "❌ 仍然存在 @source inline() 语法"
end
tw_tests_total += 1

# 检查是否使用了有效的 @safelist
if tailwind_code.include?('@safelist') && tailwind_code.include?('grid-cols-[2fr_3fr_2fr_2fr_2fr_2fr_1fr]')
  puts "✅ 使用有效的 @safelist 语法声明动态类名"
  tw_tests_passed += 1
else
  puts "❌ 未正确配置 @safelist"
end

puts "\n✨ 结果: #{tw_tests_passed}/#{tw_tests_total} 通过"

# 汇总
puts "\n" + "=" * 80
total_passed = tests_passed + cat_tests_passed + tw_tests_passed
total_tests = tests_total + cat_tests_total + tw_tests_total

if total_passed == total_tests
  puts "🎉 所有测试通过！"
  puts "   ✅ auto_submit_form_controller.js - #{tests_passed}/#{tests_total}"
  puts "   ✅ category_comparison_controller.js - #{cat_tests_passed}/#{cat_tests_total}"
  puts "   ✅ tailwind.css - #{tw_tests_passed}/#{tw_tests_total}"
  puts "\n准备就绪可以提交 PR！"
  exit 0
else
  puts "⚠️  部分测试未通过"
  puts "   #{tests_passed}/#{tests_total} auto_submit_form_controller.js"
  puts "   #{cat_tests_passed}/#{cat_tests_total} category_comparison_controller.js"
  puts "   #{tw_tests_passed}/#{tw_tests_total} tailwind.css"
  puts "\n请修复后重试"
  exit 1
end
