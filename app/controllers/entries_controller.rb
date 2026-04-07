# frozen_string_literal: true

class EntriesController < ApplicationController
  include EntryableActions

  before_action :set_entry, only: [ :update, :destroy ]
  before_action :load_lookups, only: [ :create, :update ]

  # GET /entries — 301 重定向到 accounts
  def index
    redirect_to accounts_path(request.query_parameters), status: :moved_permanently
  end

  def create
    @entry = build_entry
    if @entry.save
      expire_entries_cache
      handle_successful_save("交易已创建")
    else
      handle_save_error(@entry)
    end
  end

  def update
    if @entry.update(entry_params)
      expire_entries_cache
      handle_successful_save("交易已更新")
    else
      handle_save_error(@entry)
    end
  end

  def destroy
    @entry.destroy
    expire_entries_cache
    redirect_to accounts_path(filter_params), notice: "交易已删除"
  end

  def bulk_destroy
    ids = params[:ids].presence
    if ids
      count = Entry.where(id: ids).destroy_all.size
      redirect_to accounts_path(filter_params), notice: "已删除 #{count} 笔交易"
    else
      redirect_to accounts_path(filter_params), alert: "请选择要删除的交易"
    end
  end

  private

  def set_entry
    @entry = Entry.find(params[:id])
  end

  def load_lookups
    @accounts = Account.visible.order(:name)
    @categories = Category.active.by_sort_order
    @tags = Tag.alphabetically
  end

  def build_entry
    attrs = entry_params

    entryable_attrs = {
      kind: attrs[:kind] || "expense",
      category_id: attrs[:category_id]
    }

    if attrs[:tag_ids].present?
      entryable_attrs[:tags] = attrs[:tag_ids].reject(&:blank?).map(&:to_i)
    end

    entry = Entry.new(
      account_id: attrs[:account_id],
      date: attrs[:date],
      name: attrs[:name] || "#{attrs[:kind] == 'income' ? '收入' : '支出'} #{attrs[:amount]}",
      amount: attrs[:kind] == "income" ? attrs[:amount].to_d : -attrs[:amount].to_d,
      currency: attrs[:currency] || "CNY",
      notes: attrs[:notes]
    )

    entry.entryable = Entryable::Transaction.new(entryable_attrs)
    entry
  end

  def entry_params
    params.require(:entry).permit(
      :date, :kind, :amount, :currency, :name, :notes,
      :category_id, :account_id,
      tag_ids: []
    )
  end

  def filter_params
    params.permit(
      :account_id, :search, :type, :kind, :period_type, :period_value,
      :show_hidden, :view_mode, :page, :per_page,
      category_ids: []
    )
  end
end
