# frozen_string_literal: true

# 比翼鸟 (Pixiu) CSV 导入服务
# 处理比翼鸟记账应用的 CSV 导入流程：预览、映射、导入
class PixiuImportService
  # 支出类型分类列表
  EXPENSE_CATEGORIES = %w[日常支出 垫付 借出 物品购入 缴纳保费 理财申购 还款 债务坏账 债权坏账 应付款 物品批量购入].freeze
  # 收入类型分类列表
  INCOME_CATEGORIES = %w[日常收入 余额调整 收款 报销 物品售出 借入 理财赎回].freeze
  # 转账分类
  TRANSFER_CATEGORIES = %w[转账 信用卡还款].freeze
  # 非转账的交易类型关键词
  NON_TRANSFER_KEYWORDS = %w[优惠抵扣 手续费].freeze

  # 预览 CSV 文件，返回统计信息和样本数据
  def self.preview(file_path)
    stats = { total: 0, valid: 0, transfers: 0, invalid: 0 }
    sample_data = []

    CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
      stats[:total] += 1
      next if row['日期'].blank?

      transaction_category = row['交易分类']&.strip
      transaction_type_detail = row['交易类型']&.strip

      if transfer?(transaction_category, transaction_type_detail)
        stats[:transfers] += 1
        if sample_data.size < 10
          transfer_info = parse_transfer_info(row, transaction_type_detail)
          sample_data << build_sample_transfer(row, transfer_info, transaction_type_detail) if transfer_info[:from_account] && transfer_info[:to_account]
        end
        next
      end

      income = row['流入金额'].to_d
      expense = row['流出金额'].to_d

      if income > 0 || expense > 0
        stats[:valid] += 1
        if sample_data.size < 10
          sample_data << build_sample_entry(row, income, expense)
        end
      else
        stats[:invalid] += 1
      end
    end

    { stats: stats, sample_data: sample_data }
  end

  # 加载映射数据：收集所有账户和分类，创建默认映射
  def self.load_mappings(file_path)
    accounts_set = Set.new
    parent_categories_set = Set.new
    child_categories_map = {}
    parent_category_types = {}

    CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
      next if row['日期'].blank?

      collect_accounts(row, accounts_set)
      collect_categories(row, parent_categories_set, child_categories_map, parent_category_types)
    end

    accounts_map = build_accounts_map(accounts_set)
    categories_map = build_categories_map(parent_categories_set, child_categories_map, parent_category_types)

    { accounts_map: accounts_map, categories_map: categories_map }
  end

  # 执行导入
  def self.import(file_path, accounts_map, categories_map)
    result = { imported: 0, skipped: 0, errors: 0, transfers: 0 }

    CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
      next if row['日期'].blank?

      begin
        date = Date.parse(row['日期'])
      rescue Date::Error => e
        result[:errors] += 1
        Rails.logger.error("Import error: invalid date '#{row['日期']}': #{e.message}")
        next
      end

      income = row['流入金额'].to_d
      expense = row['流出金额'].to_d
      transaction_category = row['交易分类']&.strip
      transaction_type_detail = row['交易类型']&.strip
      account_str = row['资金账户']&.strip

      begin
        if transfer?(transaction_category, transaction_type_detail)
          handle_transfer_import(row, date, income, expense, transaction_category,
                                 transaction_type_detail, account_str, accounts_map, result)
        else
          handle_regular_import(row, date, income, expense, transaction_category,
                                accounts_map, categories_map, result)
        end
      rescue ActiveRecord::RecordInvalid => e
        result[:errors] += 1
        Rails.logger.error("Import error: validation failed: #{e.record.errors.full_messages.join(', ')}")
      rescue ActiveRecord::RecordNotFound => e
        result[:errors] += 1
        Rails.logger.error("Import error: record not found: #{e.message}")
      end
    end

    result
  end

  # 构建参数账户映射（前端提交的 { pixiu_name => account_id }）
  def self.build_accounts_map(params_accounts)
    result = {}
    params_accounts&.each do |pixiu_name, account_id|
      account = Account.find(account_id)
      result[pixiu_name] = account
    end
    result
  end

  # 构建参数分类映射
  def self.build_categories_map(params_categories)
    result = {}
    params_categories&.each do |pixiu_name, category_id|
      category = Category.find(category_id)
      result[pixiu_name] = category
    end
    result
  end

  class << self
    private

    # 判断是否为转账类型
    def transfer?(transaction_category, transaction_type_detail)
      non_transfer = NON_TRANSFER_KEYWORDS.any? { |t| transaction_type_detail&.include?(t) }
      (TRANSFER_CATEGORIES.include?(transaction_category) || transaction_type_detail&.start_with?('转账')) && !non_transfer
    end

    # 解析转账账户信息
    def parse_transfer_info(row, transaction_type_detail)
      account_str = row['资金账户']&.strip

      if account_str&.include?('→')
        parts = account_str.split('→').map(&:strip)
        return { from_account: parts[0], to_account: parts[1], from_name: parts[0], to_name: parts[1] }
      elsif transaction_type_detail&.include?('/')
        parts = transaction_type_detail.split('/').map(&:strip)
        if parts.length > 1
          account_info = parts[1]
          if account_info.include?('转到') || account_info.include?('转出')
            to_name = account_info.sub(/转到|转出/, '').strip
            return { from_account: "支付宝余额", to_account: to_name, from_name: "支付宝余额", to_name: to_name }
          elsif account_info.include?('转入')
            from_name = account_info.sub('转入', '').strip
            return { from_account: from_name, to_account: "支付宝余额", from_name: from_name, to_name: "支付宝余额" }
          else
            return { from_account: "支付宝余额", to_account: account_info, from_name: "支付宝余额", to_name: account_info }
          end
        end
      end

      { from_account: nil, to_account: nil }
    end

    # 构建转账样本数据
    def build_sample_transfer(row, transfer_info, transaction_type_detail)
      income = row['流入金额'].to_d
      expense = row['流出金额'].to_d
      amount = income > 0 ? income : expense

      {
        date: row['日期'],
        category: '转账',
        account: "#{transfer_info[:from_name]} → #{transfer_info[:to_name]}",
        type: 'TRANSFER',
        amount: amount,
        note: transaction_type_detail || "转账"
      }
    end

    # 构建普通收支样本数据
    def build_sample_entry(row, income, expense)
      parent = row['收支大类']&.strip.presence
      transaction_category = row['交易分类']&.strip
      if parent.blank? && transaction_category.present? && !%w[日常收入 日常支出 转账].include?(transaction_category)
        parent = transaction_category
      end
      parent ||= '-'

      {
        date: row['日期'],
        category: "#{parent} - #{row['交易类型']}",
        account: row['资金账户'],
        type: income > 0 ? 'INCOME' : 'EXPENSE',
        amount: income > 0 ? income : expense,
        note: row['备注'].present? ? row['备注'] : ''
      }
    end

    # 收集 CSV 中的账户名称
    def collect_accounts(row, accounts_set)
      account_str = row['资金账户']&.strip
      transaction_category = row['交易分类']&.strip
      transaction_type_detail = row['交易类型']&.strip

      if account_str&.include?('→')
        parts = account_str.split('→').map(&:strip)
        accounts_set << parts[0]
        accounts_set << parts[1]
      elsif transaction_type_detail&.include?('/') && transaction_category == '转账'
        parts = transaction_type_detail.split('/').map(&:strip)
        if parts.length > 1
          account_info = parts[1]
          if account_info.include?('转到') || account_info.include?('转出')
            accounts_set << account_info.sub(/转到|转出/, '').strip
          elsif account_info.include?('转入')
            accounts_set << account_info.sub('转入', '').strip
          else
            accounts_set << account_info
          end
        end
        accounts_set << "支付宝余额"
      elsif account_str
        accounts_set << account_str
      end
    end

    # 收集 CSV 中的分类信息
    def collect_categories(row, parent_categories_set, child_categories_map, parent_category_types)
      parent_name = row['收支大类']&.strip
      transaction_category = row['交易分类']&.strip
      child_name = row['交易类型']&.strip

      return if transaction_category == '转账'

      # 收支大类为空时的回退逻辑
      if parent_name.blank?
        if transaction_category.present?
          parent_name = transaction_category
        elsif child_name.present?
          parent_name = child_name
          child_name = nil
        end
      elsif parent_name == '无'
        if child_name.present?
          parent_name = child_name
          child_name = nil
        end
      end

      return unless parent_name.present?

      parent_categories_set << parent_name

      # 根据交易分类判断分类类型
      if INCOME_CATEGORIES.include?(transaction_category)
        parent_category_types[parent_name] = 'INCOME'
      elsif EXPENSE_CATEGORIES.include?(transaction_category)
        parent_category_types[parent_name] = 'EXPENSE'
      end

      # 子分类处理
      if parent_name != row['收支大类']&.strip || parent_name == '无'
        # 收支大类为空或"无"时，不创建子分类
      elsif child_name.present?
        child_categories_map[parent_name] ||= Set.new
        child_categories_map[parent_name] << child_name
      end
    end

    # 创建默认账户映射
    def build_accounts_map(accounts_set)
      accounts_map = {}
      accounts_set.each do |name|
        account = Account.find_or_create_by(name: name) { |a| a.sort_order = 0 }
        accounts_map[name] = account
      end
      accounts_map
    end

    # 创建默认分类映射
    def build_categories_map(parent_categories_set, child_categories_map, parent_category_types)
      categories_map = {}
      parent_categories_set.each do |parent_name|
        category_type = parent_category_types[parent_name] || 'EXPENSE'

        parent_category = Category.find_or_create_by(name: parent_name, parent_id: nil) do |c|
          c.type = category_type
          c.active = true
        end
        categories_map[parent_name] = parent_category

        # 类型不匹配时更新
        parent_category.update!(type: category_type) if parent_category.type != category_type

        # 创建子分类
        next unless child_categories_map[parent_name]

        child_categories_map[parent_name].each do |child_name|
          child_category = Category.find_by(name: child_name, parent_id: parent_category.id)
          next if child_category

          begin
            child_category = Category.create!(
              name: child_name,
              parent_id: parent_category.id,
              type: category_type,
              active: true
            )
          rescue ActiveRecord::RecordNotUnique
            child_category = Category.find_by(name: child_name)
          end
        end
      end
      categories_map
    end

    # 导入转账记录
    def handle_transfer_import(row, date, income, expense, transaction_category,
                               transaction_type_detail, account_str, accounts_map, result)
      transfer_info = parse_transfer_info(row, transaction_type_detail)
      from_account = accounts_map[transfer_info[:from_account]]
      to_account = accounts_map[transfer_info[:to_account]]
      amount = income > 0 ? income : expense

      if from_account && to_account && (income > 0 || expense > 0)
        note = transaction_type_detail || "转账: #{transfer_info[:from_name]} → #{transfer_info[:to_name]}"
        create_entry_transfer(
          from_account: from_account,
          to_account: to_account,
          amount: amount,
          date: date,
          note: note
        )
        result[:transfers] += 1
        result[:imported] += 1
      else
        result[:skipped] += 1
      end
    end

    # 导入普通收支记录
    def handle_regular_import(row, date, income, expense, transaction_category,
                              accounts_map, categories_map, result)
      if INCOME_CATEGORIES.include?(transaction_category)
        if expense > 0
          type = 'EXPENSE'
          amount = expense
        else
          type = 'INCOME'
          amount = income > 0 ? income : expense
        end
      elsif EXPENSE_CATEGORIES.include?(transaction_category)
        if income > 0
          type = 'INCOME'
          amount = income
        else
          type = 'EXPENSE'
          amount = expense
        end
      else
        if income > 0
          type = 'INCOME'
          amount = income
        elsif expense > 0
          type = 'EXPENSE'
          amount = expense
        else
          result[:skipped] += 1
          return
        end
      end

      account_name = row['资金账户'].strip
      account = accounts_map[account_name]

      unless account
        result[:skipped] += 1
        return
      end

      # 解析分类
      category = resolve_category(row, type, categories_map)

      note_parts = []
      note_parts << row['交易类型'].strip if row['交易类型'].present?
      note_parts << row['备注'].strip if row['备注'].present?
      note = note_parts.join(' - ')

      create_entry(
        account: account,
        amount: type == 'INCOME' ? amount : -amount,
        date: date,
        name: note,
        kind: type.downcase,
        category: category
      )

      result[:imported] += 1
    end

    # 解析分类
    def resolve_category(row, type, categories_map)
      parent_name = row['收支大类']&.strip
      transaction_category = row['交易分类']&.strip
      child_name = row['交易类型']&.strip

      # 收支大类为空时的回退
      if parent_name.blank?
        if transaction_category.present? && transaction_category != '转账'
          parent_name = transaction_category
        elsif child_name.present?
          parent_name = child_name
          child_name = nil
        end
      elsif parent_name == '无'
        if child_name.present?
          parent_name = child_name
          child_name = nil
        end
      end

      # 优先使用子分类
      if child_name.present? && parent_name.present?
        parent_category = categories_map[parent_name]
        child_category = parent_category&.children&.find_by(name: child_name)
        return child_category || parent_category
      end

      parent_name = parent_name.presence || '其他'
      category = categories_map[parent_name]

      # 如果分类不存在，尝试查找或创建
      unless category
        category = Category.find_or_create_by(name: parent_name, parent_id: nil) do |c|
          c.type = type
          c.active = true
        end
        categories_map[parent_name] ||= category
      end

      category
    end

    # 创建普通 Entry
    def create_entry(account:, amount:, date:, name:, kind:, category: nil)
      Entry.transaction do
        entryable = Entryable::Transaction.create!(
          kind: kind,
          category_id: category&.id
        )

        Entry.create!(
          account_id: account.id,
          date: date,
          name: name,
          amount: amount,
          currency: 'CNY',
          entryable: entryable
        )
      end
    end

    # 创建转账 Entry 对（转出 + 转入）
    def create_entry_transfer(from_account:, to_account:, amount:, date:, note:)
      transfer_id = SecureRandom.uuid.gsub('-', '').to_i(16) % 2_000_000_000

      Entry.transaction do
        # 转出 Entry
        entryable_out = Entryable::Transaction.create!(kind: 'expense')

        Entry.create!(
          account_id: from_account.id,
          date: date,
          name: note,
          amount: -amount.to_d,
          currency: from_account.currency || 'CNY',
          entryable: entryable_out,
          transfer_id: transfer_id
        )

        # 转入 Entry
        entryable_in = Entryable::Transaction.create!(kind: 'income')

        Entry.create!(
          account_id: to_account.id,
          date: date,
          name: note,
          amount: amount.to_d,
          currency: to_account.currency || 'CNY',
          entryable: entryable_in,
          transfer_id: transfer_id
        )
      end
    end
  end
end
