# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Receivables", type: :request do
  before { login }

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

      # 验证自动创建了 Entry 并通过 source_entry_id 关联
      expect(receivable.source_entry_id).to be_present
      source_entry = receivable.source_entry
      expect(source_entry).to be_present
      expect(source_entry.amount).to eq(-5000)
      expect(source_entry.name).to include("[待报销]")
      expect(source_entry.notes).to be_blank # 备注应该为空
    end

    it "updates source_entry when receivable is updated" do
      receivable = create(:receivable,
        account: account,
        counterparty: counterparty,
        description: "原描述",
        original_amount: 1000,
        date: Date.current
      )

      # 创建源 Entry 并关联
      source_entry = create(:entry,
        account: account,
        amount: -1000,
        date: Date.current,
        name: "[待报销] 原描述",
        entryable: create(:entryable_transaction, :expense)
      )
      receivable.update!(source_entry_id: source_entry.id)

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
      expect(source_entry.notes).to be_blank # 备注应该为空
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
        entryable: entryable
      )
      receivable.update!(source_entry_id: source_entry.id)

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
        entryable: entryable
      )
      receivable.update!(source_entry_id: source_entry.id)

      expect {
        delete "/receivables/#{receivable.id}"
      }.to change(Entry, :count).by(-1)

      expect(Entry.find_by(id: source_entry.id)).to be_nil
    end
  end

  describe "source_entry compatibility" do
    it "provides source_transaction_or_entry compatibility method" do
      receivable = create(:receivable, account: account)

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

  describe "POST /receivables/:id/settle" do
    let(:receivable) { create(:receivable, account: account, counterparty: counterparty, original_amount: 5000, remaining_amount: 5000) }
    let(:reimburse_category) { create(:category, name: "报销", category_type: "INCOME", active: true) }

    before do
      reimburse_category
    end

    it "creates reimbursement entry with reimburse category" do
      settle_account = create(:account, name: "报销账户")

      post "/receivables/#{receivable.id}/settle", params: {
        amount: 5000,
        account_id: settle_account.id,
        settlement_date: Date.current
      }

      expect(response).to redirect_to(receivables_path)

      receivable.reload
      expect(receivable.remaining_amount).to eq(0)
      expect(receivable.settled_at).to be_present

      reimburse_entry = Entry.where(account_id: settle_account.id)
                              .where("name LIKE ?", "%\[报销\]%")
                              .where("amount > 0")
                              .order(created_at: :desc)
                              .first

      expect(reimburse_entry).to be_present
      expect(reimburse_entry.amount).to eq(5000)
      expect(reimburse_entry.entryable).to be_a(Entryable::Transaction)
      expect(reimburse_entry.entryable.kind).to eq("income")
      expect(reimburse_entry.entryable.category_id).to eq(reimburse_category.id)
    end

    it "creates reimbursement entry without category if reimburse category does not exist" do
      Category.where(name: "报销", category_type: "INCOME").destroy_all
      settle_account = create(:account, name: "报销账户")

      post "/receivables/#{receivable.id}/settle", params: {
        amount: 5000,
        account_id: settle_account.id,
        settlement_date: Date.current
      }

      expect(response).to redirect_to(receivables_path)

      reimburse_entry = Entry.where(account_id: settle_account.id)
                              .where("name LIKE ?", "%\[报销\]%")
                              .where("amount > 0")
                              .order(created_at: :desc)
                              .first

      expect(reimburse_entry).to be_present
      expect(reimburse_entry.entryable.category_id).to be_nil
    end

    it "creates partial reimbursement entry" do
      settle_account = create(:account, name: "报销账户")

      post "/receivables/#{receivable.id}/settle", params: {
        amount: 2000,
        account_id: settle_account.id,
        settlement_date: Date.current
      }

      expect(response).to redirect_to(receivables_path)

      receivable.reload
      expect(receivable.remaining_amount).to eq(3000)
      expect(receivable.settled_at).to be_nil

      reimburse_entry = Entry.where(account_id: settle_account.id)
                              .where("name LIKE ?", "%\[报销\]%")
                              .where("amount > 0")
                              .order(created_at: :desc)
                              .first

      expect(reimburse_entry).to be_present
      expect(reimburse_entry.amount).to eq(2000)
    end

    it "rejects invalid amount or account" do
      post "/receivables/#{receivable.id}/settle", params: {
        amount: 0,
        account_id: account.id,
        settlement_date: Date.current
      }

      expect(response).to redirect_to(receivable)

      post "/receivables/#{receivable.id}/settle", params: {
        amount: 5000,
        account_id: nil,
        settlement_date: Date.current
      }

      expect(response).to redirect_to(receivable)
    end
  end

  describe "POST /receivables/:id/revert" do
    let(:receivable) { create(:receivable, account: account, counterparty: counterparty, original_amount: 5000, remaining_amount: 5000) }
    let(:revert_account) { create(:account, name: "报销账户") }
    let(:reimburse_category) { create(:category, name: "报销", category_type: "INCOME", active: true) }

    before do
      reimburse_category
      # 创建源支出Entry
      source_entry = create(:entry,
        account: account,
        amount: -5000,
        name: "[待报销] #{receivable.description}",
        entryable: create(:entryable_transaction, :expense)
      )
      receivable.update!(source_entry_id: source_entry.id)
    end

    it "reverts reimbursement and deletes related entries" do
      # 首先进行部分报销
      post "/receivables/#{receivable.id}/settle", params: {
        amount: 2500,
        account_id: revert_account.id,
        settlement_date: Date.current
      }

      receivable.reload
      expect(receivable.remaining_amount).to eq(2500)

      reimburse_entry = Entry.where(account_id: revert_account.id)
                              .where("name LIKE ?", "%\[报销\]%")
                              .first
      expect(reimburse_entry).to be_present
      initial_entry_count = Entry.count

      # 撤销报销
      post "/receivables/#{receivable.id}/revert"

      expect(response).to redirect_to(receivables_path)

      receivable.reload
      expect(receivable.remaining_amount).to eq(5000)
      expect(receivable.settled_at).to be_nil

      # 验证报销Entry被删除
      expect(Entry.find_by(id: reimburse_entry.id)).to be_nil

      # 验证源Entry仍然存在（因为是待报销状态）
      source_entry = receivable.source_entry
      expect(source_entry).to be_present
    end

    it "deletes source entry when receivable is destroyed after revert" do
      post "/receivables/#{receivable.id}/settle", params: {
        amount: 2500,
        account_id: revert_account.id,
        settlement_date: Date.current
      }

      post "/receivables/#{receivable.id}/revert"

      receivable.reload
      source_entry_id = receivable.source_entry_id

      # 删除应收款
      delete "/receivables/#{receivable.id}"

      # 验证源Entry也被删除
      expect(Entry.find_by(id: source_entry_id)).to be_nil
    end
  end
end
