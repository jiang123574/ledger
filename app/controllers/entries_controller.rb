# frozen_string_literal: true

class EntriesController < ApplicationController
  before_action :set_entry, only: [:update, :destroy]
  before_action :load_lookups, only: [:create, :update]

  def index
    redirect_to accounts_path(request.query_parameters)
  end

  def create
    @entry = build_entry

    if @entry.save
      expire_entries_cache
      handle_successful_save("交易已创建")
    else
      redirect_to accounts_path(filter_params), alert: @entry.errors.full_messages.join(", ")
    end
  end

  def update
    if @entry.update(entry_params)
      expire_entries_cache
      handle_successful_save("交易已更新")
    else
      redirect_to accounts_path(filter_params), alert: @entry.errors.full_messages.join(", ")
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
      kind: attrs[:kind] || 'expense',
      category_id: attrs[:category_id]
    }
    
    if attrs[:tag_ids].present?
      entryable_attrs[:tags] = attrs[:tag_ids].reject(&:blank?).map(&:to_i)
    end
    
    entry = Entry.new(
      account_id: attrs[:account_id],
      date: attrs[:date],
      name: attrs[:name] || "#{attrs[:kind] == 'income' ? '收入' : '支出'} #{attrs[:amount]}",
      amount: attrs[:kind] == 'income' ? attrs[:amount].to_d : -attrs[:amount].to_d,
      currency: attrs[:currency] || 'CNY',
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
    params.permit(:account_id, :search, :kind, :period_type, :period_value, category_ids: [])
  end

  def build_redirect_url
    if params[:account_id].present? || params[:period_type].present? || params[:search].present?
      accounts_path(filter_params)
    else
      referer = request.referer
      return accounts_path if referer.blank?
      
      begin
        uri = URI.parse(referer)
        filter_params_from_referer = Rack::Utils.parse_nested_query(uri.query).symbolize_keys
        accounts_path(filter_params_from_referer.select { |k, v| v.present? })
      rescue
        accounts_path
      end
    end
  end

  def handle_successful_save(message)
    if params[:continue_entry] == "1"
      return redirect_to(continue_entry_redirect_url, notice: "#{message}，请继续录入")
    end

    redirect_url = build_redirect_url
    respond_to do |format|
      format.html { redirect_to redirect_url, notice: message }
      format.turbo_stream { redirect_to redirect_url, notice: message }
    end
  end

  def continue_entry_redirect_url
    fallback = accounts_path(open_new_entry: 1)
    referer = request.referer
    return fallback if referer.blank?

    uri = URI.parse(referer)
    params_hash = Rack::Utils.parse_nested_query(uri.query)
    params_hash["open_new_entry"] = "1"
    uri.query = params_hash.to_query
    uri.to_s
  rescue URI::InvalidURIError
    fallback
  end

  def expire_entries_cache
    Rails.cache.delete_matched("entries_*")
  end
end