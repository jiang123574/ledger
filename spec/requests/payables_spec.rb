# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payables", type: :request do
  before { http_login }

  let(:account) { create(:account) }
  let(:counterparty) { create(:counterparty, name: "供应商A") }

  describe "GET /payables" do
    let(:counterparty_a) { create(:counterparty, name: "供应商A") }
    let(:counterparty_b) { create(:counterparty, name: "供应商B") }

    it "filters unsettled payables by counterparty id token" do
      Payable.create!(
        description: "A-待付款",
        original_amount: 100,
        remaining_amount: 100,
        date: Date.current,
        account: account,
        counterparty: counterparty_a
      )
      Payable.create!(
        description: "B-待付款",
        original_amount: 200,
        remaining_amount: 200,
        date: Date.current,
        account: account,
        counterparty: counterparty_b
      )

      get "/payables", params: { counterparty_id: "id:#{counterparty_a.id}" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("A-待付款")
      expect(response.body).not_to include("B-待付款")
    end

    it "filters unsettled payables with none token" do
      Payable.create!(
        description: "无联系人-待付款",
        original_amount: 80,
        remaining_amount: 80,
        date: Date.current,
        account: account,
        counterparty: nil
      )
      Payable.create!(
        description: "有联系人-待付款",
        original_amount: 120,
        remaining_amount: 120,
        date: Date.current,
        account: account,
        counterparty: counterparty_a
      )

      get "/payables", params: { counterparty_id: "none" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("无联系人-待付款")
      expect(response.body).not_to include("有联系人-待付款")
    end
  end

  describe "POST /payables" do
    it "creates payable with source_entry link" do
      post "/payables", params: {
        payable: {
          description: "办公用品采购",
          original_amount: 3000,
          date: Date.current,
          account_id: account.id,
          counterparty_id: counterparty.id,
          category: "办公"
        }
      }

      expect(response).to redirect_to(payables_path)

      payable = Payable.last
      expect(payable.description).to eq("办公用品采购")
      expect(payable.original_amount).to eq(3000)

      # 验证自动创建了 Entry
      source_entry = Entry.where("notes LIKE ?", "%payable:#{payable.id}:source%").first
      expect(source_entry).to be_present
      expect(source_entry.amount).to eq(3000)
      expect(source_entry.name).to include("[待付款]")
    end

it "updates source_entry when payable is updated" do
      payable = create(:payable,
        account: account,
        counterparty: counterparty,
        description: "原描述",
        original_amount: 500,
        date: Date.current
      )

      entryable = create(:entryable_transaction, :income)
      source_entry = create(:entry,
        account: account,
        amount: 500,
        date: Date.current,
        name: "[待付款] 原描述",
        notes: "payable:#{payable.id}:source",
        entryable: entryable
      )

      patch "/payables/#{payable.id}", params: {
        payable: {
          description: "新描述",
          original_amount: 1500,
          date: (Date.current + 1.day)
        }
      }

      expect(response).to redirect_to(payables_path)

      source_entry.reload
      expect(source_entry.name).to include("新描述")
      expect(source_entry.amount).to eq(1500.0)
    end
  end

describe "DELETE /payables" do
    it "deletes payable with associated entry" do
      payable = create(:payable, account: account, counterparty: counterparty)

      entryable = create(:entryable_transaction, :income)
      source_entry = create(:entry,
        account: account,
        amount: payable.original_amount,
        notes: "payable:#{payable.id}:source",
        entryable: entryable
      )

      expect {
        delete "/payables/#{payable.id}"
      }.to change(Payable, :count).by(-1)

      expect(response).to redirect_to(payables_path)
    end

    it "deletes associated source_entry when payable is destroyed" do
      payable = create(:payable, account: account, counterparty: counterparty, original_amount: 2000)

      entryable = create(:entryable_transaction, :income)
      source_entry = create(:entry,
        account: account,
        amount: 2000,
        notes: "payable:#{payable.id}:source",
        entryable: entryable
      )

      expect {
        delete "/payables/#{payable.id}"
      }.to change(Entry, :count).by(-1)

      expect(Entry.find_by(id: source_entry.id)).to be_nil
    end
  end

  describe "source_entry compatibility" do
    it "provides source_transaction_or_entry compatibility method" do
      payable = create(:payable, account: account)

      # 创建 Entry 关联
      entry = create(:entry, account: account)
      payable.update(source_entry_id: entry.id)

      expect(payable.source_transaction_or_entry).to eq(entry)
    end

    it "returns source_amount from entry" do
      payable = create(:payable, account: account, original_amount: 2000)
      entry = create(:entry, account: account, amount: 1000)
      payable.update(source_entry_id: entry.id)

      expect(payable.source_amount).to eq(1000)
    end
  end
end
