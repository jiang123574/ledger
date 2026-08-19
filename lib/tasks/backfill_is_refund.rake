# frozen_string_literal: true

namespace :db do
  namespace :refund do
    desc "Backfill is_refund flag based on amount sign convention (dry run)"
    task backfill_dry_run: :environment do
      expense_refunds = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
        .where(entryable_type: "Entryable::Transaction")
        .where(entryable_transactions: { kind: "expense", is_refund: false })
        .where("entries.amount > 0")
        .where(transfer_id: nil)

      income_refunds = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
        .where(entryable_type: "Entryable::Transaction")
        .where(entryable_transactions: { kind: "income", is_refund: false })
        .where("entries.amount < 0")
        .where(transfer_id: nil)

      puts "=" * 60
      puts "退款标记回填 - 预览 (Dry Run)"
      puts "=" * 60
      puts
      puts "买家退款 (支出类 + 正金额): #{expense_refunds.count} 笔"
      puts "卖家退款 (收入类 + 负金额): #{income_refunds.count} 笔"
      puts "总计: #{expense_refunds.count + income_refunds.count} 笔"
      puts

      if expense_refunds.limit(5).any?
        puts
        puts "--- 买家退款示例 (前5笔) ---"
        expense_refunds.limit(5).each do |e|
          puts "  #{e.date} | ¥#{e.amount} | #{e.name}"
        end
      end

      if income_refunds.limit(5).any?
        puts
        puts "--- 卖家退款示例 (前5笔) ---"
        income_refunds.limit(5).each do |e|
          puts "  #{e.date} | ¥#{e.amount} | #{e.name}"
        end
      end

      puts
      puts "确认无误后执行: rake db:refund:backfill"
    end

    desc "Backfill is_refund flag based on amount sign convention"
    task backfill: :environment do
      count = 0

      ActiveRecord::Base.transaction do
        # 买家退款: kind=expense + amount > 0 → is_refund=true
        expense_ids = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
          .where(entryable_type: "Entryable::Transaction")
          .where(entryable_transactions: { kind: "expense", is_refund: false })
          .where("entries.amount > 0")
          .where(transfer_id: nil)
          .pluck("entryable_transactions.id")

        Entryable::Transaction.where(id: expense_ids).update_all(is_refund: true)
        count += expense_ids.size

        # 卖家退款: kind=income + amount < 0 → is_refund=true
        income_ids = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
          .where(entryable_type: "Entryable::Transaction")
          .where(entryable_transactions: { kind: "income", is_refund: false })
          .where("entries.amount < 0")
          .where(transfer_id: nil)
          .pluck("entryable_transactions.id")

        Entryable::Transaction.where(id: income_ids).update_all(is_refund: true)
        count += income_ids.size
      end

      puts "回填完成！共标记 #{count} 笔退款记录"
      puts "买家退款: #{Entryable::Transaction.where(kind: 'expense', is_refund: true).count} 笔"
      puts "卖家退款: #{Entryable::Transaction.where(kind: 'income', is_refund: true).count} 笔"
    end
  end
end
