#!/usr/bin/env ruby
# lib/tasks/import_pixiu.rake

namespace :import do
  desc "Import transactions from Pixiu CSV export"
  task pixiu: :environment do
    require "csv"

    file_path = ENV["FILE"] || Rails.root.join("tmp/pixiu_export.csv")

    unless File.exist?(file_path)
      puts "❌ File not found: #{file_path}"
      exit 1
    end

    puts "📥 Starting import from #{file_path}..."

    # Step 1: Create/Map Accounts
    puts "\n📋 Setting up accounts..."
    accounts_map = create_accounts_map
    puts "✅ #{accounts_map.size} accounts ready"

    # Step 2: Create/Map Categories
    puts "\n📂 Setting up categories..."
    categories_map = create_categories_map
    puts "✅ #{categories_map.size} categories ready"

    # Step 3: Import Transactions
    puts "\n📊 Importing transactions..."
    stats = {
      total: 0,
      imported: 0,
      skipped: 0,
      errors: 0,
      transfers: 0
    }

    errors = []

    # Get transfer category
    transfer_category = Category.find_or_create_by(name: "转账", category_type: "TRANSFER") { |c| c.active = true }

    CSV.foreach(file_path, headers: true, encoding: "UTF-8") do |row|
      stats[:total] += 1

      begin
        # Skip header or empty rows
        next if row["日期"].blank?

        date = Date.parse(row["日期"])

        # Determine transaction type and amount
        income_amount = row["流入金额"].to_f
        expense_amount = row["流出金额"].to_f

        # Handle transfers
        transaction_category = row["交易分类"]&.strip || ""
        transaction_type_detail = row["交易类型"]&.strip || ""

        is_transfer = transaction_category == "转账" || transaction_type_detail.start_with?("转账")

        if is_transfer
          account_str = row["资金账户"]&.strip || ""
          from_account = nil
          to_account = nil
          from_account_name = nil
          to_account_name = nil

          if account_str.include?("→")
            parts = account_str.split("→").map(&:strip)
            from_account_name = parts[0]
            to_account_name = parts[1]
          elsif transaction_type_detail.include?("/")
            parts = transaction_type_detail.split("/").map(&:strip)
            if parts.length > 1
              account_info = parts[1]
              if account_info.include?("转到") || account_info.include?("转出")
                to_account_name = account_info.sub(/转到|转出/, "").strip
                from_account_name = "支付宝余额"
              elsif account_info.include?("转入")
                from_account_name = account_info.sub("转入", "").strip
                to_account_name = "支付宝余额"
              else
                from_account_name = "支付宝余额"
                to_account_name = account_info
              end
            end
          end

          if from_account_name && to_account_name
            from_account = accounts_map[from_account_name]
            to_account = accounts_map[to_account_name]
          end

          if from_account && to_account && (income_amount > 0 || expense_amount > 0)
            amount = income_amount > 0 ? income_amount : expense_amount
            note = transaction_type_detail || "转账: #{from_account_name} → #{to_account_name}"

            # 对于支付宝余额流水，只创建一条转账记录
            # create_transfer! 会创建两条记录（outflow + inflow），这里我们只需要一条
            Transaction.create!(
              date: date,
              type: "TRANSFER",
              amount: amount,
              account: from_account,
              target_account: to_account,
              category: transfer_category,
              note: note
            )

            stats[:transfers] += 1
            stats[:imported] += 1
          else
            stats[:skipped] += 1
          end
          next
        end

        # Handle regular transactions
        if income_amount > 0
          type = "INCOME"
          amount = income_amount
        elsif expense_amount > 0
          type = "EXPENSE"
          amount = expense_amount
        else
          stats[:skipped] += 1
          next
        end

        # Get account
        account_name = row["资金账户"]&.strip || "支付宝余额"
        account = accounts_map[account_name]

        unless account
          stats[:skipped] += 1
          next
        end

        # Get category - 优先使用交易类型，如果没有则使用交易分类
        category_name = row["交易类型"]&.strip
        if category_name.blank? || %w[日常支出 日常收入 转账].include?(category_name)
          category_name = row["交易分类"]&.strip || "其他"
        end

        # 如果是日常支出/日常收入，使用交易类型作为分类
        if row["交易分类"]&.strip == "日常支出" || row["交易分类"]&.strip == "日常收入"
          category_name = row["交易类型"]&.strip || "其他"
        end

        category = categories_map[category_name]

        # 如果分类不存在，尝试查找或创建
        unless category
          category = Category.find_by(name: category_name)
          if category
            categories_map[category_name] = category
          else
            category = Category.create!(
              name: category_name,
              type: type,
              active: true
            )
            categories_map[category_name] = category
          end
        end

        # Build note
        note_parts = []
        note_parts << row["交易类型"]&.strip if row["交易类型"].present?
        note_parts << row["备注"]&.strip if row["备注"].present?
        note = note_parts.join(" - ")

        # Create transaction
        transaction = Transaction.create!(
          date: date,
          type: type,
          amount: amount,
          account: account,
          category: category,
          note: note
        )

        stats[:imported] += 1

        # Progress indicator
        if stats[:imported] % 100 == 0
          puts "  ✓ #{stats[:imported]} transactions imported..."
        end

      rescue => e
        stats[:errors] += 1
        errors << "Row #{stats[:total]}: #{e.message}"
        # Debug: print the row that caused the error
        if stats[:errors] <= 5
          puts "  Debug - Row content: #{row.to_h.inspect[0..200]}"
        end
      end
    end

    # Print summary
    puts "\n" + "="*50
    puts "📈 Import Summary"
    puts "="*50
    puts "Total rows:     #{stats[:total]}"
    puts "Imported:       #{stats[:imported]} ✅"
    puts "Skipped:        #{stats[:skipped]} ⏭️"
    puts "Errors:         #{stats[:errors]} ❌"
    puts "="*50

    if errors.any?
      puts "\n⚠️  Errors encountered:"
      errors.first(10).each { |e| puts "  - #{e}" }
      puts "  ... and #{errors.size - 10} more" if errors.size > 10
    end

    puts "\n✨ Import complete!"
  end

  private

  def create_accounts_map
    # Map from Pixiu account names to Ledger accounts
    mapping = {
      "支付宝余额" => "支付宝",
      "微信零钱" => "微信",
      "农行7110" => "农行7110",
      "农行2917" => "农行2917",
      "京东" => "京东",
      "中信1622" => "中信1622",
      "中信7431" => "中信7431",
      "花呗" => "花呗",
      "京东白条" => "京东白条",
      "拼多多" => "拼多多",
      "支付宝消费" => "支付宝",
      "余利宝" => "余利宝",
      "中信7431" => "中信7431",
      "现金" => "现金",
      "加油卡" => "加油卡",
      "美团支付" => "美团",
      "亚马逊" => "亚马逊",
      "网商银行" => "网商银行",
      "建行1924" => "建行1924",
      "平安3702" => "平安3702",
      "工商4630" => "工商4630",
      "交通9835" => "交通9835",
      "招商5063" => "招商5063",
      "京东小号" => "京东",
      "小号支付宝" => "支付宝",
      "抖音" => "抖音",
      "云闪付" => "云闪付",
      "丰收互联" => "丰收互联",
      "闪英" => "闪英",
      "晴天日记" => "其他",
      "套现" => "套现",
      "进货" => "进货",
      "电网" => "电网",
      "垫" => "垫付"
    }

    result = {}
    mapping.each do |pixiu_name, ledger_name|
      account = Account.find_or_create_by(name: ledger_name) do |a|
        a.sort_order = 0
      end
      result[pixiu_name] = account
    end

    result
  end

  def create_categories_map
    # Map from Pixiu categories to Ledger categories
    mapping = {
      "吃的" => { name: "饮食", type: "EXPENSE" },
      "蚁巢成本" => { name: "业务成本", type: "EXPENSE" },
      "闲鱼售出" => { name: "销售收入", type: "INCOME" },
      "生活缴费" => { name: "生活缴费", type: "EXPENSE" },
      "汽车相关" => { name: "交通出行", type: "EXPENSE" },
      "装修" => { name: "装修", type: "EXPENSE" },
      "育儿" => { name: "育儿", type: "EXPENSE" },
      "穿的" => { name: "服装", type: "EXPENSE" },
      "休闲娱乐" => { name: "娱乐", type: "EXPENSE" },
      "数码产品" => { name: "数码", type: "EXPENSE" },
      "其他收入" => { name: "其他收入", type: "INCOME" },
      "日用耗品" => { name: "日用品", type: "EXPENSE" },
      "物品购入" => { name: "购物", type: "EXPENSE" },
      "房贷" => { name: "房贷", type: "EXPENSE" },
      "无" => { name: "其他", type: "EXPENSE" },
      "垫付" => { name: "垫付", type: "EXPENSE" },
      "余额调整" => { name: "调整", type: "INCOME" },
      "药品医疗" => { name: "医疗", type: "EXPENSE" },
      "人情往来" => { name: "人情", type: "EXPENSE" },
      "家居用品" => { name: "家居", type: "EXPENSE" },
      "系统收入" => { name: "系统收入", type: "INCOME" },
      "缴纳保费" => { name: "保险支出", type: "EXPENSE" },
      "物品售出" => { name: "销售收入", type: "INCOME" }
    }

    result = {}
    mapping.each do |pixiu_name, category_info|
      category = Category.find_or_create_by(
        name: category_info[:name],
        category_type: category_info[:type]
      ) do |c|
        c.active = true
      end
      result[pixiu_name] = category
    end

    # Create default "其他" category if not exists
    result["其他"] ||= Category.find_or_create_by(
      name: "其他",
      category_type: "EXPENSE"
    ) { |c| c.active = true }

    result
  end
end
