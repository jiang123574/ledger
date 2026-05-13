# frozen_string_literal: true

# EntrySplitService - 处理 Entry 拆分和合并逻辑
#
# 从 Entry 模型提取的拆分功能：
# - split: 将一笔交易拆分为多笔子交易
# - unsplit: 合并拆分的子交易
#
class EntrySplitService
  # 拆分 Entry 为多笔子交易
  #
  # @param entry [Entry] 要拆分的父 Entry
  # @param splits [Array<Hash>] 拆分参数数组
  #   - name: 子交易名称
  #   - amount: 子交易金额
  #   - category_id: 子交易分类
  #
  # @raise [ArgumentError] 拆分金额总和必须等于父 Entry 金额
  # @return [Array<Entry>] 创建的子 Entry 数组
  def self.split(entry, splits)
    validate_split_amounts(entry, splits)

    child_entries = Entry.transaction do
      splits.map do |split_attrs|
        create_child_entry(entry, split_attrs)
      end

      entry.update!(excluded: true)
      entry.mark_user_modified!
    end

    child_entries
  end

  # 合并拆分的子交易
  #
  # @param entry [Entry] 父 Entry
  # @return [void]
  def self.unsplit(entry)
    Entry.transaction do
      entry.child_entries.destroy_all
      entry.update!(excluded: false)
    end
  end

  private

  def self.validate_split_amounts(entry, splits)
    total = splits.sum { |s| s[:amount].to_d }
    unless total == entry.amount
      raise ArgumentError,
            "Split amounts must sum to parent amount (expected #{entry.amount}, got #{total})"
    end
  end

  def self.create_child_entry(parent, split_attrs)
    parent.child_entries.create!(
      account: parent.account,
      date: parent.date,
      name: split_attrs[:name],
      amount: split_attrs[:amount],
      currency: parent.currency,
      entryable: Entryable::Transaction.new(
        category_id: split_attrs[:category_id]
      )
    )
  end
end