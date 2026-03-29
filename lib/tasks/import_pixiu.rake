#!/usr/bin/env ruby
# lib/tasks/import_pixiu.rake

namespace :import do
  desc "Import transactions from Pixiu CSV export"
  task pixiu: :environment do
    require 'csv'
    
    file_path = ENV['FILE'] || Rails.root.join('tmp/pixiu_export.csv')
    
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
      errors: 0
    }
    
    errors = []
    
    CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
      stats[:total] += 1
      
      begin
        # Skip header or empty rows
        next if row['日期'].blank?
        
        date = Date.parse(row['日期'])
        
        # Determine transaction type and amount
        income_amount = row['流入金额'].to_f
        expense_amount = row['流出金额'].to_f
        
        if income_amount > 0
          type = 'INCOME'
          amount = income_amount
        elsif expense_amount > 0
          type = 'EXPENSE'
          amount = expense_amount
        else
          stats[:skipped] += 1
          next
        end
        
        # Skip transfers
        if row['交易类型'] == '转账'
          stats[:skipped] += 1
          next
        end
        
        # Get account
        account_name = row['资金账户'].strip
        account = accounts_map[account_name]
        
        unless account
          stats[:skipped] += 1
          next
        end
        
        # Get category
        category_name = row['收支大类'].strip
        category_name = '其他' if category_name.blank?
        category = categories_map[category_name]
        
        unless category
          stats[:skipped] += 1
          next
        end
        
        # Build note
        note_parts = []
        note_parts << row['交易分类'].strip if row['交易分类'].present?
        note_parts << row['备注'].strip if row['备注'].present?
        note = note_parts.join(' - ')
        
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
      "系统收入" => { name: "系统收入", type: "INCOME" }
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
