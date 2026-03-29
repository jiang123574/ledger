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

    # Get mapping from params
    accounts_map = build_accounts_map(params[:accounts])
    categories_map = build_categories_map(params[:categories])

    # Import transactions
    result = import_transactions(file_path, accounts_map, categories_map)

    session[:import_result] = result
    session.delete(:pixiu_file_path)
    session.delete(:pixiu_file_name)

    # Clean up temp file
    File.delete(file_path) if File.exist?(file_path)

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
      
      # 交易分类 = 交易类型（日常支出、日常收入、转账等）
      transaction_type = row['交易分类']&.strip
      
      if transaction_type == '转账'
        @stats[:transfers] += 1
        
        if @sample_data.size < 10
          account_str = row['资金账户'].strip
          if account_str.include?('→')
            parts = account_str.split('→').map(&:strip)
            amount = row['流入金额'].to_f > 0 ? row['流入金额'].to_f : row['流出金额'].to_f
            
            @sample_data << {
              date: row['日期'],
              category: '转账',
              account: "#{parts[0]} → #{parts[1]}",
              type: 'TRANSFER',
              amount: amount,
              note: "转账"
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
          @sample_data << {
            date: row['日期'],
            category: "#{row['收支大类']} - #{row['交易类型']}",
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

    CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
      next if row['日期'].blank?
      
      account_str = row['资金账户'].strip if row['资金账户'].present?
      
      # 处理转账：分离出两个账户
      if account_str && account_str.include?('→')
        parts = account_str.split('→').map(&:strip)
        accounts_set << parts[0]
        accounts_set << parts[1]
      elsif account_str
        accounts_set << account_str
      end
      
      # 收支大类 = 父分类
      parent_name = row['收支大类']&.strip
      if parent_name.present?
        parent_categories_set << parent_name
        
        # 交易类型 = 子分类
        child_name = row['交易类型']&.strip
        if child_name.present?
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
      parent_category = Category.find_or_create_by(name: parent_name, parent_id: nil, category_type: 'EXPENSE') { |c| c.active = true }
      @categories_map[parent_name] = parent_category
      
      # 创建子分类
      if child_categories_map[parent_name]
        child_categories_map[parent_name].each do |child_name|
          Category.find_or_create_by(name: child_name, parent_id: parent_category.id, category_type: 'EXPENSE') { |c| c.active = true }
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

    # Get transfer category
    transfer_category = Category.find_or_create_by(name: '转账', category_type: 'TRANSFER') { |c| c.active = true }

    CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
      begin
        next if row['日期'].blank?

        date = Date.parse(row['日期'])
        income = row['流入金额'].to_f
        expense = row['流出金额'].to_f

        # Handle transfers: "账户A → 账户B"
        # 交易分类 = 交易类型（日常支出、日常收入、转账等）
        if row['交易分类']&.strip == '转账'
          account_str = row['资金账户'].strip
          
          # Parse "账户A → 账户B" format
          if account_str.include?('→')
            parts = account_str.split('→').map(&:strip)
            from_account_name = parts[0]
            to_account_name = parts[1]
            
            from_account = accounts_map[from_account_name]
            to_account = accounts_map[to_account_name]
            
            if from_account && to_account && (income > 0 || expense > 0)
              amount = income > 0 ? income : expense
              
              # Create two transactions: expense from source, income to destination
              note = "转账: #{from_account_name} → #{to_account_name}"
              
              # Expense transaction (from account)
              Transaction.create!(
                date: date,
                type: 'EXPENSE',
                amount: amount,
                account: from_account,
                category: transfer_category,
                note: note
              )
              
              # Income transaction (to account)
              Transaction.create!(
                date: date,
                type: 'INCOME',
                amount: amount,
                account: to_account,
                category: transfer_category,
                note: note
              )
              
              result[:transfers] += 1
              result[:imported] += 2
            else
              result[:skipped] += 1
            end
          else
            result[:skipped] += 1
          end
          next
        end

        # Handle regular transactions
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

        account_name = row['资金账户'].strip
        account = accounts_map[account_name]
        
        unless account
          result[:skipped] += 1
          next
        end

        # 使用子分类（交易类型）作为分类
        parent_name = row['收支大类']&.strip
        child_name = row['交易类型']&.strip
        
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
          result[:skipped] += 1
          next
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
