# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Receivables", type: :request do
  before { login }

  let(:account) { create(:account) }
  let(:counterparty) { create(:counterparty, name: "客户A") }
  let(:receivable_system_account) { create(:account, name: SystemAccountSyncService::RECEIVABLE_ACCOUNT_NAME) }

  describe "POST /receivables" do
    it "creates receivable with transfer" do
      receivable_system_account

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

      expect(receivable.transfer_id).to be_present

      transfer_entries = Entry.where(transfer_id: receivable.transfer_id)
      expect(transfer_entries.count).to eq(2)

      out_entry = transfer_entries.find { |e| e.account_id == account.id }
      expect(out_entry.amount).to eq(-5000)
      expect(out_entry.name).to include("创建应收款")

      in_entry = transfer_entries.find { |e| e.account_id == receivable_system_account.id }
      expect(in_entry.amount).to eq(5000)
    end

    it "creates receivable without transfer when account is receivable system account" do
      post "/receivables", params: {
        receivable: {
          description: "咨询费",
          original_amount: 5000,
          date: Date.current,
          account_id: receivable_system_account.id,
          counterparty_id: counterparty.id
        }
      }

      expect(response).to redirect_to(receivables_path)

      receivable = Receivable.last
      expect(receivable.transfer_id).to be_nil
    end

    it "updates transfer amount when receivable is updated" do
      receivable_system_account

      receivable = create(:receivable,
        account: account,
        counterparty: counterparty,
        description: "原描述",
        original_amount: 1000,
        date: Date.current
      )

      transfer_id = EntryCreationService.create_transfer(
        from_account_id: account.id,
        to_account_id: receivable_system_account.id,
        amount: 1000,
        date: Date.current,
        note: "创建应收款 原描述"
      )
      receivable.update!(transfer_id: transfer_id)

      patch "/receivables/#{receivable.id}", params: {
        receivable: {
          description: "新描述",
          original_amount: 2000
        }
      }

      expect(response).to redirect_to(receivables_path)

      transfer_entries = Entry.where(transfer_id: transfer_id)
      out_entry = transfer_entries.find { |e| e.amount < 0 }
      expect(out_entry.amount.abs).to eq(2000)
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
    it "deletes receivable with associated transfer entries" do
      receivable_system_account

      receivable = create(:receivable, account: account, counterparty: counterparty, original_amount: 1000)

      transfer_id = EntryCreationService.create_transfer(
        from_account_id: account.id,
        to_account_id: receivable_system_account.id,
        amount: 1000,
        date: Date.current,
        note: "创建应收款"
      )
      receivable.update!(transfer_id: transfer_id)

      expect {
        delete "/receivables/#{receivable.id}"
      }.to change(Receivable, :count).by(-1)

      expect(response).to redirect_to(receivables_path)

      expect(Entry.where(transfer_id: transfer_id).count).to eq(0)
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

    before do
      receivable_system_account
    end

    it "creates transfer entries for reimbursement" do
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
      expect(receivable.reimbursement_transfer_ids).not_to be_empty

      transfer_id = receivable.reimbursement_transfer_ids.first
      transfer_entries = Entry.where(transfer_id: transfer_id)
      expect(transfer_entries.count).to eq(2)

      out_entry = transfer_entries.find { |e| e.account_id == receivable_system_account.id }
      in_entry = transfer_entries.find { |e| e.account_id == settle_account.id }

      expect(out_entry).to be_present
      expect(out_entry.amount).to eq(-5000)
      expect(out_entry.name).to include("报销")

      expect(in_entry).to be_present
      expect(in_entry.amount).to eq(5000)
      expect(in_entry.name).to include("报销")
    end

    it "creates partial reimbursement transfer" do
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
      expect(receivable.reimbursement_transfer_ids).not_to be_empty

      transfer_id = receivable.reimbursement_transfer_ids.first
      transfer_entries = Entry.where(transfer_id: transfer_id)
      out_entry = transfer_entries.find { |e| e.account_id == receivable_system_account.id }
      expect(out_entry).to be_present
      expect(out_entry.amount).to eq(-2000)
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

    before do
      receivable_system_account
    end

    it "reverts reimbursement and deletes transfer entries" do
      post "/receivables/#{receivable.id}/settle", params: {
        amount: 2500,
        account_id: revert_account.id,
        settlement_date: Date.current
      }

      receivable.reload
      expect(receivable.remaining_amount).to eq(2500)
      expect(receivable.reimbursement_transfer_ids).not_to be_empty

      transfer_id = receivable.reimbursement_transfer_ids.first
      transfer_entries = Entry.where(transfer_id: transfer_id)
      expect(transfer_entries.count).to eq(2)

      post "/receivables/#{receivable.id}/revert"

      expect(response).to redirect_to(receivables_path)

      receivable.reload
      expect(receivable.remaining_amount).to eq(5000)
      expect(receivable.settled_at).to be_nil
      expect(receivable.reimbursement_transfer_ids).to be_empty

      expect(Entry.where(transfer_id: transfer_id).count).to eq(0)
    end

    it "supports multiple partial reimbursements" do
      post "/receivables/#{receivable.id}/settle", params: {
        amount: 1000,
        account_id: revert_account.id,
        settlement_date: Date.current
      }

      receivable.reload
      expect(receivable.remaining_amount).to eq(4000)
      expect(receivable.reimbursement_transfer_ids.size).to eq(1)

      post "/receivables/#{receivable.id}/settle", params: {
        amount: 1500,
        account_id: revert_account.id,
        settlement_date: Date.current
      }

      receivable.reload
      expect(receivable.remaining_amount).to eq(2500)
      expect(receivable.reimbursement_transfer_ids.size).to eq(2)

      post "/receivables/#{receivable.id}/revert"

      receivable.reload
      expect(receivable.remaining_amount).to eq(5000)
      expect(receivable.reimbursement_transfer_ids).to be_empty

      receivable.reimbursement_transfer_ids.each do |tid|
        expect(Entry.where(transfer_id: tid).count).to eq(0)
      end
    end
  end
end
