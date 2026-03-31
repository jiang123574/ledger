namespace :verify do
  desc "验证账户导入数据与CSV的一致性"
  task :account, [:account_id] => :environment do |t, args|
    account_id = args[:account_id]
    raise "请提供账户ID: rails verify:account[账户ID]" unless account_id
    
    account = Account.find_by(id: account_id)
    raise "账户不存在: #{account_id}" unless account
    
    csv_path = Rails.root.join('貔貅记账.csv')
    raise "CSV文件不存在: #{csv_path}" unless File.exist?(csv_path)
    
    puts "=" * 60
    puts "账户: #{account.name} (ID: #{account.id})"
    puts "=" * 60
    puts
    
    # 数据库统计
    db_income = Transaction.where(account_id: account.id, type: 'INCOME')
    db_expense = Transaction.where(account_id: account.id, type: 'EXPENSE')
    db_transfer_out = Transaction.where(account_id: account.id, type: 'TRANSFER')
    db_transfer_in = Transaction.where(target_account_id: account.id, type: 'TRANSFER')
    
    db_stats = {
      income: { count: db_income.count, sum: db_income.sum(:amount) },
      expense: { count: db_expense.count, sum: db_expense.sum(:amount) },
      transfer_out: { count: db_transfer_out.count, sum: db_transfer_out.sum(:amount) },
      transfer_in: { count: db_transfer_in.count, sum: db_transfer_in.sum(:amount) }
    }
    
    # CSV统计
    csv_stats = { income: { count: 0, sum: 0 }, expense: { count: 0, sum: 0 },
                  transfer_out: { count: 0, sum: 0 }, transfer_in: { count: 0, sum: 0 } }
    
    # 导出数据库记录用于比对
    db_records = {
      income: {},
      expense: {},
      transfer_out: {},
      transfer_in: {}
    }
    
    db_income.find_each { |t| key = "#{t.date.strftime('%Y-%m-%d')}_#{t.amount}"; db_records[:income][key] ||= 0; db_records[:income][key] += 1 }
    db_expense.find_each { |t| key = "#{t.date.strftime('%Y-%m-%d')}_#{t.amount}"; db_records[:expense][key] ||= 0; db_records[:expense][key] += 1 }
    db_transfer_out.find_each { |t| key = "#{t.date.strftime('%Y-%m-%d')}_#{t.amount}_#{t.target_account&.name}"; db_records[:transfer_out][key] ||= 0; db_records[:transfer_out][key] += 1 }
    db_transfer_in.find_each { |t| key = "#{t.date.strftime('%Y-%m-%d')}_#{t.amount}_#{t.account&.name}"; db_records[:transfer_in][key] ||= 0; db_records[:transfer_in][key] += 1 }
    
    # 记录CSV中的详细数据用于找出差异
    csv_records = {
      income: [],
      expense: [],
      transfer_out: [],
      transfer_in: []
    }
    
    CSV.foreach(csv_path, headers: true, encoding: 'UTF-8').with_index do |row, idx|
      line_num = idx + 2
      account_str = row['资金账户']&.strip
      next unless account_str&.include?(account.name)
      
      date = row['日期']
      category = row['交易分类']&.strip
      type_detail = row['交易类型']&.strip
      in_amt = row['流入金额'].to_f
      out_amt = row['流出金额'].to_f
      
      # 判断是否为真正的转账（与导入逻辑一致）
      transfer_categories = %w[转账 信用卡还款]
      non_transfer_types = %w[优惠抵扣 手续费]
      is_non_transfer = non_transfer_types.any? { |t| type_detail&.include?(t) }
      is_real_transfer = transfer_categories.include?(category) && !is_non_transfer
      
      if account_str == account.name
        # 非转账记录才计入收入/支出
        unless is_real_transfer
          if in_amt > 0
            csv_stats[:income][:count] += 1
            csv_stats[:income][:sum] += in_amt
            csv_records[:income] << { line: line_num, date: date, amount: in_amt }
          end
          if out_amt > 0
            csv_stats[:expense][:count] += 1
            csv_stats[:expense][:sum] += out_amt
            csv_records[:expense] << { line: line_num, date: date, amount: out_amt }
          end
        end
      elsif account_str.include?('→')
        parts = account_str.split('→').map(&:strip)
        amount = in_amt > 0 ? in_amt : out_amt
        
        if parts[0] == account.name
          csv_stats[:transfer_out][:count] += 1
          csv_stats[:transfer_out][:sum] += amount
          csv_records[:transfer_out] << { line: line_num, date: date, amount: amount, to: parts[1] }
        elsif parts[1] == account.name
          csv_stats[:transfer_in][:count] += 1
          csv_stats[:transfer_in][:sum] += amount
          csv_records[:transfer_in] << { line: line_num, date: date, amount: amount, from: parts[0] }
        end
      end
    end
    
    # 打印对比
    puts sprintf("%-15s %15s %15s %15s", "", "CSV", "数据库", "差异")
    puts "-" * 60
    
    [:income, :expense, :transfer_out, :transfer_in].each do |type|
      csv_count = csv_stats[type][:count]
      db_count = db_stats[type][:count]
      csv_sum = csv_stats[type][:sum]
      db_sum = db_stats[type][:sum]
      
      count_diff = csv_count - db_count
      sum_diff = csv_sum - db_sum
      
      type_name = type.to_s.gsub('_', ' ')
      puts sprintf("%-15s %5d %12.2f %5d %12.2f %+5d %+12.2f", 
                   type_name + ':', csv_count, csv_sum, db_count, db_sum, count_diff, sum_diff)
    end
    
    puts
    puts "余额对比:"
    csv_balance = csv_stats[:income][:sum] - csv_stats[:expense][:sum] - csv_stats[:transfer_out][:sum] + csv_stats[:transfer_in][:sum]
    db_balance = account.current_balance
    puts sprintf("  CSV余额:   %.2f", csv_balance)
    puts sprintf("  数据库余额: %.2f", db_balance)
    puts sprintf("  差异:       %.2f", csv_balance - db_balance)
    
    # 找出具体差异
    puts
    puts "=" * 60
    puts "详细差异分析"
    puts "=" * 60
    
    # 检查每种类型的差异
    [:transfer_out, :transfer_in, :income, :expense].each do |type|
      csv_list = csv_records[type]
      db_hash = db_records[type].dup
      
      missing = []
      extra = []
      
      # 检查CSV有但数据库没有的
      csv_list.each do |csv_rec|
        key = if type == :transfer_out
                "#{csv_rec[:date]}_#{csv_rec[:amount]}_#{csv_rec[:to]}"
              elsif type == :transfer_in
                "#{csv_rec[:date]}_#{csv_rec[:amount]}_#{csv_rec[:from]}"
              else
                "#{csv_rec[:date]}_#{csv_rec[:amount]}"
              end
        
        if db_hash[key].nil? || db_hash[key] == 0
          missing << csv_rec
        else
          db_hash[key] -= 1
        end
      end
      
      # 检查数据库有但CSV没有的（多余记录）
      db_hash.each do |key, count|
        count.times do
          parts = key.split('_')
          date_str = parts[0]
          amount = parts[1].to_f
          target = parts[2] || ''
          extra << { date: date_str, amount: amount, target: target }
        end
      end
      
      if missing.any? || extra.any?
        puts
        puts "#{type.to_s.gsub('_', ' ').capitalize}:"
        if missing.any?
          puts "  CSV有但数据库没有: #{missing.size} 笔"
          missing.first(10).each do |rec|
            if type == :transfer_out
              puts "    行#{rec[:line]} | #{rec[:date]} | #{rec[:amount]} | → #{rec[:to]}"
            elsif type == :transfer_in
              puts "    行#{rec[:line]} | #{rec[:date]} | #{rec[:amount]} | ← #{rec[:from]}"
            else
              puts "    行#{rec[:line]} | #{rec[:date]} | #{rec[:amount]}"
            end
          end
          puts "    ..." if missing.size > 10
        end
        if extra.any?
          puts "  数据库有但CSV没有: #{extra.size} 笔"
          extra.first(10).each do |rec|
            if type == :transfer_out
              puts "    #{rec[:date]} | #{rec[:amount]} | → #{rec[:target]}"
            elsif type == :transfer_in
              puts "    #{rec[:date]} | #{rec[:amount]} | ← #{rec[:target]}"
            else
              puts "    #{rec[:date]} | #{rec[:amount]}"
            end
          end
          puts "    ..." if extra.size > 10
        end
      else
        puts
        puts "#{type.to_s.gsub('_', ' ').capitalize}: 一致 ✓"
      end
    end
    
    puts
    puts "=" * 60
    puts "验证完成"
    puts "=" * 60
  end
  
  desc "验证所有账户"
  task all: :environment do
    csv_path = Rails.root.join('貔貅记账.csv')
    
    # 从CSV收集所有账户
    csv_accounts = Set.new
    CSV.foreach(csv_path, headers: true, encoding: 'UTF-8') do |row|
      account_str = row['资金账户']&.strip
      next unless account_str
      
      if account_str.include?('→')
        parts = account_str.split('→').map(&:strip)
        csv_accounts << parts[0]
        csv_accounts << parts[1]
      else
        csv_accounts << account_str
      end
    end
    
    puts "CSV中发现的账户: #{csv_accounts.size} 个"
    puts
    
    mismatched = []
    
    csv_accounts.sort.each do |name|
      account = Account.find_by(name: name)
      next unless account
      
      # 快速检查
      db_income = Transaction.where(account_id: account.id, type: 'INCOME').count
      db_expense = Transaction.where(account_id: account.id, type: 'EXPENSE').count
      db_transfer_out = Transaction.where(account_id: account.id, type: 'TRANSFER').count
      db_transfer_in = Transaction.where(target_account_id: account.id, type: 'TRANSFER').count
      
      # 统计CSV
      csv_income = 0; csv_expense = 0; csv_transfer_out = 0; csv_transfer_in = 0
      
      CSV.foreach(csv_path, headers: true, encoding: 'UTF-8') do |row|
        account_str = row['资金账户']&.strip
        category = row['交易分类']&.strip
        type_detail = row['交易类型']&.strip
        in_amt = row['流入金额'].to_f
        out_amt = row['流出金额'].to_f
        
        # 判断是否为真正的转账（与导入逻辑一致）
        transfer_categories = %w[转账 信用卡还款]
        non_transfer_types = %w[优惠抵扣 手续费]
        is_non_transfer = non_transfer_types.any? { |t| type_detail&.include?(t) }
        is_real_transfer = transfer_categories.include?(category) && !is_non_transfer
        
        if account_str == name
          unless is_real_transfer
            csv_income += 1 if in_amt > 0
            csv_expense += 1 if out_amt > 0
          end
        elsif account_str&.include?('→')
          parts = account_str.split('→').map(&:strip)
          csv_transfer_out += 1 if parts[0] == name
          csv_transfer_in += 1 if parts[1] == name
        end
      end
      
      count_diff = (csv_income - db_income).abs + (csv_expense - db_expense).abs + 
                   (csv_transfer_out - db_transfer_out).abs + (csv_transfer_in - db_transfer_in).abs
      
      if count_diff > 0
        mismatched << { name: name, id: account.id, diff: count_diff }
      end
    end
    
    if mismatched.any?
      puts "发现 #{mismatched.size} 个账户有差异:"
      mismatched.sort_by { |a| -a[:diff] }.each do |a|
        puts sprintf("  %-20s (ID: %d) 差异: %d 笔", a[:name], a[:id], a[:diff])
      end
      puts
      puts "运行以下命令查看详情:"
      mismatched.first(5).each do |a|
        puts "  rails verify:account[#{a[:id]}]"
      end
    else
      puts "所有账户数据一致!"
    end
  end
end