# 修复 kind 与分类类型不匹配的交易记录
#
# 问题：部分交易的 kind（income/expense）与分类的 category_type 不一致
#
# 修复规则（退款约定：金额符号不变，只改 kind）：
#   1. kind=income + EXPENSE分类 → 改为 kind=expense，金额不变（买家退款）
#   2. kind=expense + INCOME分类 → 改为 kind=income，金额不变（卖家退款）
#
# 两边余额变化均为 0
#
# 用法：
#   bin/rake fix_transaction_kinds:dry_run    # 预览，不修改
#   bin/rake fix_transaction_kinds:run         # 执行修复
#
namespace :fix_transaction_kinds do
  desc "预览：显示需要修复的交易（不修改数据）"
  task dry_run: :environment do
    puts "=" * 60
    puts "交易 Kind 修复 - 预览模式"
    puts "=" * 60

    result_1 = scan("income", "EXPENSE", "买家退款")
    result_2 = scan("expense", "INCOME", "卖家退款")

    puts "\n" + "=" * 60
    puts "汇总"
    puts "  income→expense: #{result_1} 条, 余额变化: 0"
    puts "  expense→income: #{result_2} 条, 余额变化: 0"
    puts "  净余额变化: 0"
    puts "✅ 预览完成，数据未修改"
    puts "执行修复: bin/rails fix_transaction_kinds:run"
  end

  desc "执行：修复 kind 与分类类型不匹配的交易"
  task run: :environment do
    puts "=" * 60
    puts "交易 Kind 修复 - 执行模式"
    puts "=" * 60

    ActiveRecord::Base.transaction do
      fixed_1 = fix("income", "EXPENSE")
      fixed_2 = fix("expense", "INCOME")
      CacheBuster.bump(:entries)
      CacheBuster.bump(:accounts)
      puts "\n✅ 修复完成: 共 #{fixed_1 + fixed_2} 条记录，缓存已刷新"
    end
  end

  private

  def scan(from_kind, to_cat_type, label)
    target_kind = from_kind == "income" ? "expense" : "income"

    scope = Entryable::Transaction
      .joins(:entry, :category)
      .where(kind: from_kind)
      .where(categories: { type: to_cat_type })

    count = scope.count
    total = scope.sum("entries.amount")

    puts "\n[#{from_kind}→#{target_kind}] #{label} (分类是 #{to_cat_type} 类型)"
    puts "    数量: #{count} 条"
    puts "    金额总和: #{total}"
    puts "    操作: 只改 kind，金额不变 → 余额变化: 0"

    scope.includes(:entry, :category).limit(5).each do |t|
      puts "    样本: ID=#{t.id} kind=#{t.kind}→#{target_kind} amount=#{t.entry.amount}(不变) #{t.entry.name&.truncate(30)}"
    end
    puts "    ..." if count > 5

    count
  end

  def fix(from_kind, to_cat_type)
    target_kind = from_kind == "income" ? "expense" : "income"

    scope = Entryable::Transaction
      .joins(:entry, :category)
      .where(kind: from_kind)
      .where(categories: { type: to_cat_type })

    count = scope.count
    fixed = 0

    scope.find_each do |t|
      t.update!(kind: target_kind)
      fixed += 1
      puts "    [#{fixed}/#{count}] ID=#{t.id} kind=#{from_kind}→#{target_kind} (金额不变)" if fixed <= 10
    end
    puts "    ..." if fixed > 10
    puts "\n  #{from_kind}→#{target_kind}: #{fixed} 条已修复，余额不变"

    fixed
  end
end
