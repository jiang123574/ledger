# frozen_string_literal: true

# EntryBulkUpdateService - 处理 Entry 批量更新逻辑
#
# 从 Entry 模型提取的批量更新功能：
# - 批量更新日期、备注、分类、商户
# - 批量更新标签
# - 自动锁定修改字段、标记用户修改
#
class EntryBulkUpdateService
  # 批量更新 Entry
  #
  # @param entries [Array<Entry>] 要更新的 Entry 数组
  # @param bulk_update_params [Hash] 批量更新参数
  #   - date: 日期
  #   - notes: 备注
  #   - category_id: 分类 ID
  #   - merchant_id: 商户 ID
  #   - tag_ids: 标签 ID 数组
  # @param update_tags [Boolean] 是否更新标签
  #
  # @return [Integer] 更新的 Entry 数量
  def self.bulk_update(entries, bulk_update_params, update_tags: false)
    bulk_attributes = build_bulk_attributes(bulk_update_params)
    tag_ids = extract_tag_ids(bulk_update_params)

    return 0 unless has_updates?(bulk_attributes, update_tags)

    count = 0

    Entry.transaction do
      entries.each do |entry|
        if update_entry(entry, bulk_attributes, tag_ids, update_tags)
          count += 1
        end
      end
    end

    count
  end

  private

  def self.build_bulk_attributes(params)
    {
      date: params[:date],
      notes: params[:notes],
      entryable_attributes: {
        category_id: params[:category_id],
        merchant_id: params[:merchant_id]
      }.compact_blank
    }.compact_blank
  end

  def self.extract_tag_ids(params)
    Array.wrap(params[:tag_ids]).reject(&:blank?)
  end

  def self.has_updates?(bulk_attributes, update_tags)
    bulk_attributes.present? || update_tags
  end

  def self.update_entry(entry, bulk_attributes, tag_ids, update_tags)
    changed = false

    # 更新基础属性
    if bulk_attributes.present?
      attrs = prepare_entry_attributes(entry, bulk_attributes)
      if attrs.present?
        entry.update!(attrs)
        changed = true
      end
    end

    # 更新标签
    if update_tags && entry.transaction?
      update_entry_tags(entry, tag_ids)
      changed = true
    end

    # 锁定和标记
    if changed
      lock_and_mark(entry)
    end

    changed
  end

  def self.prepare_entry_attributes(entry, bulk_attributes)
    attrs = bulk_attributes.dup

    # 子交易不能更新日期
    attrs.delete(:date) if entry.split_child?

    return {} if attrs.blank?

    # 设置 entryable ID 以更新关联
    if attrs[:entryable_attributes].present?
      attrs[:entryable_attributes] = attrs[:entryable_attributes].dup
      attrs[:entryable_attributes][:id] = entry.entryable_id
    end

    attrs
  end

  def self.update_entry_tags(entry, tag_ids)
    entry.transaction.tag_ids = tag_ids
    entry.transaction.save!

    if entry.transaction.tags.any?
      entry.entryable.lock_attr!(:tag_ids)
    end
  end

  def self.lock_and_mark(entry)
    if entry.transaction?
      entry.entryable.lock_saved_attributes!
    end
    entry.mark_user_modified!
  end
end