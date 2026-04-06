# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Receivables", type: :request do
  before { http_login }

  let(:account) { create(:account) }
  let(:counterparty) { create(:counterparty, name: "客户A") }

  describe "POST /receivables" do
    it "creates receivable with source_entry link" do
      post "/receivables", params: {
        receivable: {
          description: "咨询费",
          original_amount: 5000,
          date: Date.current,
          account_id: account.id,
          counterparty_id: counterparty.id,
          category: "其他"
        }
      }

      expect(response).to redirect_to(receivables_path)

      receivable = Receivable.last
      expect(receivable.description).to eq("咨询费")
      expect(receivable.original_amount).to eq(5000)

      # 验证自动创建了 Entry
      source_entry = Entry.where("notes LIKE ?", "%receivable:#{receivable.id}:source%").first
      expect(source_entry).to be_present
      expect(source_entry.amount).to eq(-5000)
      expect(source_entry.name).to include("[待报销]")
    end

    it "updates source_entry when receivable is updated" do
      receivable = create(:receivable,
        account: account,
        counterparty: counterparty,
        description: "原描述",
        original_amount: 1000,
        date: Date.current
      )

      # 创建源 Entry
      source_entry = create(:entry,
        account: account,
        amount: -1000,
        date: Date.current,
        name: "[待报销] 原描述",
        notes: "receivable:#{receivable.id}:source"
      )

      # 更新应收款
      patch "/receivables/#{receivable.id}", params: {
        receivable: {
          description: "新描述",
          original_amount: 2000,
          date: (Date.current + 1.day)
        }
      }

      expect(response).to redirect_to(receivables_path)

      source_entry.reload
      expect(source_entry.name).to include("新描述")
      expect(source_entry.amount).to eq(-2000.0)
    end
  end

  describe "GET /receivables with filters" do
    let(:counterparty_a) { create(:counterparty, name: "客户A") }
    let(:counterparty_b) { create(:counterparty, name: "客户B") }

    it "filters by counterparty id" do
      create(:receivable,
        account: account,
        counterparty: counterparty_a,
        description: "客户A收款"
      )
      create(:receivable,
        account: account,
        counterparty: counterparty_b,
        description: "客户B收款"
      )

      get "/receivables", params: { counterparty_id: "id:#{counterparty_a.id}" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("客户A收款")
      expect(response.body).not_to include("客户B收款")
    end

    it "filters by none token for receivables without counterparty" do
      create(:receivable,
        account: account,
        counterparty: nil,
        description: "无客户收款"
      )
      create(:receivable,
        account: account,
        counterparty: counterparty_a,
        description: "有客户收款"
      )

      get "/receivables", params: { counterparty_id: "none" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("无客户收款")
      expect(response.body).not_to include("有客户收款")
    end
  end

describe "DELETE /receivables" do
    it "deletes receivable with associated entries" do
      receivable = create(:receivable, account: account, counterparty: counterparty)

      entryable = create(:entryable_transaction, :expense)
      source_entry = create(:entry,
        account: account,
        amount: -receivable.original_amount,
        notes: "receivable:#{receivable.id}:source",
        entryable: entryable
      )

      expect {
        delete "/receivables/#{receivable.id}"
      }.to change(Receivable, :count).by(-1)

      expect(response).to redirect_to(receivables_path)
    end

    it "deletes associated source_entry when receivable is destroyed" do
      receivable = create(:receivable, account: account, counterparty: counterparty, original_amount: 1500)

      entryable = create(:entryable_transaction, :expense)
      source_entry = create(:entry,
        account: account,
        amount: -1500,
        notes: "receivable:#{receivable.id}:source",
        entryable: entryable
      )

      expect {
        delete "/receivables/#{receivable.id}"
      }.to change(Entry, :count).by(-1)

      expect(Entry.find_by(id: source_entry.id)).to be_nil
    end
  end

  describe "source_entry compatibility" do
    it "provides source_transaction_or_entry compatibility method" do
      receivable = create(:receivable, account: account)

      # 创建 Entry 关联
      entry = create(:entry, account: account)
      receivable.update(source_entry_id: entry.id)

      expect(receivable.source_transaction_or_entry).to eq(entry)
    end

    it "returns source_amount from entry" do
      receivable = create(:receivable, account: account, original_amount: 1000)
      entry = create(:entry, account: account, amount: 500)
      receivable.update(source_entry_id: entry.id)

      expect(receivable.source_amount).to eq(500)
    end
  end
end
