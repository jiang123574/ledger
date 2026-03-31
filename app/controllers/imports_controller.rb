class ImportsController < ApplicationController
  def pixiu
    @current_step = params[:step].to_i || 1
    
    case @current_step
    when 1
      # Upload step
    when 2
      # Preview step
      if session[:pixiu_file_path].blank?
        redirect_to pixiu_imports_path(step: 1), alert: "请先上传文件"
        return
      end
      load_preview_data
    when 3
      # Configure mapping
      if session[:pixiu_file_path].blank?
        redirect_to pixiu_imports_path(step: 1), alert: "请先上传文件"
        return
      end
      load_mapping_data
    when 4
      # Complete
      @import_result = session[:import_result] || {}
    end
  end

  def pixiu_upload
    file = params[:file]
    
    unless file.present?
      redirect_to pixiu_imports_path(step: 1), alert: "请选择文件"
      return
    end

    # Validate file
    unless file.content_type == 'text/csv' || file.original_filename.end_with?('.csv')
      redirect_to pixiu_imports_path(step: 1), alert: "请上传 CSV 文件"
      return
    end

    # Save file temporarily
    temp_path = Rails.root.join('tmp', "pixiu_#{Time.current.to_i}.csv")
    FileUtils.cp(file.tempfile.path, temp_path)

    session[:pixiu_file_path] = temp_path.to_s
    session[:pixiu_file_name] = file.original_filename

    redirect_to pixiu_imports_path(step: 2)
  end

  def pixiu_confirm
    file_path = session[:pixiu_file_path]
    
    unless file_path.present? && File.exist?(file_path)
      redirect_to pixiu_imports_path(step: 1), alert: "文件已过期，请重新上传"
      return
    end

    accounts_map = build_accounts_map(params[:accounts])
    categories_map = build_categories_map(params[:categories])

    result = import_transactions(file_path, accounts_map, categories_map)

    session[:import_result] = result
    session.delete(:pixiu_file_path)
    session.delete(:pixiu_file_name)

    File.delete(file_path) if File.exist?(file_path)

    Rails.cache.clear

    redirect_to pixiu_imports_path(step: 4)
  end

  private

  def load_preview_data
    file_path = session[:pixiu_file_path]
    
    @stats = {
      total: 0,
      valid: 0,
      transfers: 0,
      invalid: 0
    }
    
    @sample_data = []

    CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
      @stats[:total] += 1
      
      next if row['日期'].blank?
      
      # 交易分类 = 父分类（转账、缴纳保费等）
      transaction_category = row['交易分类']&.strip
      transaction_type_detail = row['交易类型']&.strip
      
      # 判断是否为转账
      is_transfer = transaction_category == '转账' || transaction_type_detail&.start_with?('转账')
      
      if is_transfer
        @stats[:transfers] += 1
        
        if @sample_data.size < 10
          # 解析转账账户
          # 格式1: 资金账户 = "账户A → 账户B"
          # 格式2: 交易类型 = "转账 / 转到中信1622" 或 "转账 / 中信1622转入"
          account_str = row['资金账户']&.strip
          
          if account_str&.include?('→')
            parts = account_str.split('→').map(&:strip)
            from_account = parts[0]
            to_account = parts[1]
          elsif transaction_type_detail&.include?('/')
            # 解析 "转账 / 转到中信1622" 格式
            parts = transaction_type_detail.split('/').map(&:strip)
            if parts.length > 1
              account_info = parts[1]
              if account_info.include?('转到') || account_info.include?('转出')
                # 转出：从当前账户转到目标账户
                to_account = account_info.sub(/转到|转出/, '').strip
                from_account = "支付宝余额"
              elsif account_info.include?('转入')
                # 转入：从源账户转入当前账户
                from_account = account_info.sub('转入', '').strip
                to_account = "支付宝余额"
              else
                from_account = "支付宝余额"
                to_account = account_info
              end
            end
          end
          
          amount = row['流入金额'].to_f > 0 ? row['流入金额'].to_f : row['流出金额'].to_f
          
          if from_account && to_account
            @sample_data << {
              date: row['日期'],
              category: '转账',
              account: "#{from_account} → #{to_account}",
              type: 'TRANSFER',
              amount: amount,
              note: transaction_type_detail || "转账"
            }
          end
        end
        next
      end

      income = row['流入金额'].to_f
      expense = row['流出金额'].to_f

      if income > 0 || expense > 0
        @stats[:valid] += 1
        
        if @sample_data.size < 10
          parent = row['收支大类']&.strip.presence
          transaction_category = row['交易分类']&.strip
          if parent.blank? && transaction_category.present? && !%w[日常收入 日常支出 转账].include?(transaction_category)
            parent = transaction_category
          end
          parent ||= '-'
          @sample_data << {
            date: row['日期'],
            category: "#{parent} - #{row['交易类型']}",
            account: row['资金账户'],
            type: income > 0 ? 'INCOME' : 'EXPENSE',
            amount: income > 0 ? income : expense,
            note: row['备注'].present? ? row['备注'] : ''
          }
        end
      else
        @stats[:invalid] += 1
      end
    end
  end

  def load_mapping_data
    file_path = session[:pixiu_file_path]
    
    # Collect all unique account and category names
    accounts_set = Set.new
    parent_categories_set = Set.new
    child_categories_map = {}  # { parent_name => [child_names] }
    parent_category_types = {} # { parent_name => 'INCOME'/'EXPENSE' } 根据"交易分类"判断

    CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
      next if row['日期'].blank?
      
      account_str = row['资金账户']&.strip
      transaction_category = row['交易分类']&.strip
      transaction_type_detail = row['交易类型']&.strip
      
      # 处理转账：分离出两个账户
      if account_str&.include?('→')
        parts = account_str.split('→').map(&:strip)
        accounts_set << parts[0]
        accounts_set << parts[1]
      elsif transaction_type_detail&.include?('/') && transaction_category == '转账'
        # 解析 "转账 / 转到中信1622" 格式
        parts = transaction_type_detail.split('/').map(&:strip)
        if parts.length > 1
          account_info = parts[1]
          if account_info.include?('转到') || account_info.include?('转出')
            to_account = account_info.sub(/转到|转出/, '').strip
            accounts_set << to_account
          elsif account_info.include?('转入')
            from_account = account_info.sub('转入', '').strip
            accounts_set << from_account
          else
            accounts_set << account_info
          end
        end
        accounts_set << "支付宝余额" # 默认账户
      elsif account_str
        accounts_set << account_str
      end
      
      # 收支大类 = 父分类，当为空时使用交易分类
      parent_name = row['收支大类']&.strip
      transaction_category = row['交易分类']&.strip
      child_name = row['交易类型']&.strip
      
      # 跳过转账记录（不需要分类）
      next if transaction_category == '转账'
      
      # 当收支大类为空时，优先使用交易分类
      if parent_name.blank?
        if transaction_category.present?
          parent_name = transaction_category
        elsif child_name.present?
          parent_name = child_name
          child_name = nil
        end
      elsif parent_name == '无'
        # 收支大类为"无"时，使用交易类型作为父分类
        if child_name.present?
          parent_name = child_name
          child_name = nil
        end
      end
      
      if parent_name.present?
        parent_categories_set << parent_name
        
        # 定义交易分类类型映射
        income_categories = %w[日常收入 余额调整 收款 报销 物品售出 借入 理财赎回]
        expense_categories = %w[日常支出 垫付 借出 物品购入 缴纳保费 理财申购 还款 债务坏账 债权坏账 应付款 物品批量购入]
        
        # 根据交易分类判断分类类型
        if income_categories.include?(transaction_category)
          parent_category_types[parent_name] = 'INCOME'
        elsif expense_categories.include?(transaction_category)
          parent_category_types[parent_name] = 'EXPENSE'
        end
        
        # 当收支大类有值时，交易类型 = 子分类
        if parent_name != row['收支大类']&.strip || parent_name == '无'
          # 收支大类为空或"无"时，不创建子分类
        elsif child_name.present?
          child_categories_map[parent_name] ||= Set.new
          child_categories_map[parent_name] << child_name
        end
      end
    end

    # Create default mappings
    @accounts_map = {}
    accounts_set.each do |name|
      account = Account.find_or_create_by(name: name) { |a| a.sort_order = 0 }
      @accounts_map[name] = account
    end

    @categories_map = {}
    parent_categories_set.each do |parent_name|
      # 根据"交易分类"确定类型，默认为 EXPENSE
      category_type = parent_category_types[parent_name] || 'EXPENSE'
      
      parent_category = Category.find_or_create_by(name: parent_name, parent_id: nil) do |c|
        c.type = category_type
        c.active = true
      end
      @categories_map[parent_name] = parent_category
      
      # 如果类型不匹配，更新
      if parent_category.type != category_type
        parent_category.update!(type: category_type)
      end
      
      # 创建子分类
      if child_categories_map[parent_name]
        child_categories_map[parent_name].each do |child_name|
          # 先查询，如果不存在再创建
          child_category = Category.find_by(name: child_name, parent_id: parent_category.id)
          unless child_category
            begin
              child_category = Category.create!(
                name: child_name,
                parent_id: parent_category.id,
                type: category_type,
                active: true
              )
            rescue ActiveRecord::RecordNotUnique
              # 如果因为全局唯一性约束失败，尝试找到现有的同名分类
              # 这种情况下，我们使用现有的分类（即使它不是子分类）
              child_category = Category.find_by(name: child_name)
            end
          end
        end
      end
    end
  end

  def build_accounts_map(params_accounts)
    result = {}
    params_accounts&.each do |pixiu_name, account_id|
      account = Account.find(account_id)
      result[pixiu_name] = account
    end
    result
  end

  def build_categories_map(params_categories)
    result = {}
    params_categories&.each do |pixiu_name, category_id|
      category = Category.find(category_id)
      result[pixiu_name] = category
    end
    result
  end

  def import_transactions(file_path, accounts_map, categories_map)
    result = {
      imported: 0,
      skipped: 0,
      errors: 0,
      transfers: 0
    }

    CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
      begin
        next if row['日期'].blank?

        date = Date.parse(row['日期'])
        income = row['流入金额'].to_f
        expense = row['流出金额'].to_f

        # Handle transfers: "账户A → 账户B" 或 "转账 / 转到中信1622"
        transaction_category = row['交易分类']&.strip
        transaction_type_detail = row['交易类型']&.strip
        account_str = row['资金账户']&.strip
        
        # 判断是否为转账类型
        transfer_categories = %w[转账 信用卡还款]
        non_transfer_types = %w[优惠抵扣 手续费]
        is_non_transfer = non_transfer_types.any? { |t| transaction_type_detail&.include?(t) }
        
        is_transfer = (transfer_categories.include?(transaction_category) || transaction_type_detail&.start_with?('转账')) && !is_non_transfer
        
        if is_transfer
          from_account = nil
          to_account = nil
          
          if account_str&.include?('→')
            parts = account_str.split('→').map(&:strip)
            from_account_name = parts[0]
            to_account_name = parts[1]
            from_account = accounts_map[from_account_name]
            to_account = accounts_map[to_account_name]
          elsif transaction_type_detail&.include?('/')
            parts = transaction_type_detail.split('/').map(&:strip)
            if parts.length > 1
              account_info = parts[1]
              if account_info.include?('转到') || account_info.include?('转出')
                to_account_name = account_info.sub(/转到|转出/, '').strip
                from_account_name = "支付宝余额"
              elsif account_info.include?('转入')
                from_account_name = account_info.sub('转入', '').strip
                to_account_name = "支付宝余额"
              else
                from_account_name = "支付宝余额"
                to_account_name = account_info
              end
              from_account = accounts_map[from_account_name]
              to_account = accounts_map[to_account_name]
            end
          end
          
          if from_account && to_account && (income > 0 || expense > 0)
            amount = income > 0 ? income : expense
            
            Transaction.create_transfer!(
              from_account: from_account,
              to_account: to_account,
              amount: amount,
              date: date,
              note: transaction_type_detail || "转账: #{from_account_name} → #{to_account_name}"
            )
            
            result[:transfers] += 1
            result[:imported] += 1
          else
            result[:skipped] += 1
          end
          next
        end

        # Handle regular transactions
        transaction_category = row['交易分类']&.strip
        
        # 定义交易分类类型映射
        income_categories = %w[日常收入 余额调整 收款 报销 物品售出 借入 理财赎回]
        expense_categories = %w[日常支出 垫付 借出 物品购入 缴纳保费 理财申购 还款 债务坏账 债权坏账 应付款 物品批量购入]
        
        if income_categories.include?(transaction_category)
          if expense > 0
            type = 'EXPENSE'
            amount = expense
          else
            type = 'INCOME'
            amount = income > 0 ? income : expense
          end
        elsif expense_categories.include?(transaction_category)
          if income > 0
            type = 'INCOME'
            amount = income
          else
            type = 'EXPENSE'
            amount = expense
          end
        else
          # 其他类型，根据金额判断
          if income > 0
            type = 'INCOME'
            amount = income
          elsif expense > 0
            type = 'EXPENSE'
            amount = expense
          else
            result[:skipped] += 1
            next
          end
        end

        account_name = row['资金账户'].strip
        account = accounts_map[account_name]
        
        unless account
          result[:skipped] += 1
          next
        end

        # 使用子分类（交易类型）作为分类
        parent_name = row['收支大类']&.strip
        transaction_category = row['交易分类']&.strip
        child_name = row['交易类型']&.strip
        
        # 当收支大类为空时，优先使用交易分类
        if parent_name.blank?
          if transaction_category.present? && transaction_category != '转账'
            parent_name = transaction_category
          elsif child_name.present?
            parent_name = child_name
            child_name = nil
          end
        elsif parent_name == '无'
          # 收支大类为"无"时，使用交易类型作为父分类
          if child_name.present?
            parent_name = child_name
            child_name = nil
          end
        end
        
        # 优先使用子分类，如果没有则使用父分类
        if child_name.present? && parent_name.present?
          parent_category = categories_map[parent_name]
          child_category = parent_category&.children&.find_by(name: child_name)
          category = child_category || parent_category
        else
          parent_name = parent_name.presence || '其他'
          category = categories_map[parent_name]
        end

        unless category
          # 如果分类不存在，尝试查找或创建
          category = Category.find_or_create_by(name: parent_name, parent_id: nil) do |c|
            c.type = type
            c.active = true
          end
          categories_map[parent_name] ||= category
        end

        note_parts = []
        note_parts << row['交易类型'].strip if row['交易类型'].present?
        note_parts << row['备注'].strip if row['备注'].present?
        note = note_parts.join(' - ')

        Transaction.create!(
          date: date,
          type: type,
          amount: amount,
          account: account,
          category: category,
          note: note
        )

        result[:imported] += 1

      rescue => e
        result[:errors] += 1
        Rails.logger.error("Import error: #{e.message}")
      end
    end

    result
  end
end
