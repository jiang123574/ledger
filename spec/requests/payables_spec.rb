# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payables", type: :request do
  before { login }

  let(:account) { create(:account) }
  let(:counterparty) { create(:counterparty, name: "供应商A") }
  let(:payable_system_account) { create(:account, name: SystemAccountSyncService::PAYABLE_ACCOUNT_NAME) }

  describe "GET /payables" do
    let(:counterparty_a) { create(:counterparty, name: "供应商A") }
    let(:counterparty_b) { create(:counterparty, name: "供应商B") }

    it "renders the index page" do
      get "/payables"
      expect(response).to have_http_status(:ok)
    end

    it "filters unsettled payables by counterparty id token" do
      Payable.create!(
        description: "A-待付款", original_amount: 100, remaining_amount: 100,
        date: Date.current, account: account, counterparty: counterparty_a
      )
      Payable.create!(
        description: "B-待付款", original_amount: 200, remaining_amount: 200,
        date: Date.current, account: account, counterparty: counterparty_b
      )

      get "/payables", params: { counterparty_id: "id:#{counterparty_a.id}" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("A-待付款")
      expect(response.body).not_to include("B-待付款")
    end

    it "filters unsettled payables with none token" do
      Payable.create!(
        description: "无联系人-待付款", original_amount: 80, remaining_amount: 80,
        date: Date.current, account: account, counterparty: nil
      )
      Payable.create!(
        description: "有联系人-待付款", original_amount: 120, remaining_amount: 120,
        date: Date.current, account: account, counterparty: counterparty_a
      )

      get "/payables", params: { counterparty_id: "none" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("无联系人-待付款")
      expect(response.body).not_to include("有联系人-待付款")
    end
  end

  describe "POST /payables" do
    it "creates a payable with transfer" do
      payable_system_account

      expect {
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
      }.to change(Payable, :count).by(1)

      expect(response).to redirect_to(payables_path)
      expect(flash[:notice]).to eq("应付款已创建")

      payable = Payable.last
      expect(payable.description).to eq("办公用品采购")
      expect(payable.original_amount).to eq(3000)
      expect(payable.transfer_id).to be_present

      transfer_entries = Entry.where(transfer_id: payable.transfer_id)
      expect(transfer_entries.count).to eq(2)

      out_entry = transfer_entries.find { |e| e.account_id == payable_system_account.id }
      expect(out_entry.amount).to eq(-3000)
      expect(out_entry.name).to include("创建应付款")

      in_entry = transfer_entries.find { |e| e.account_id == account.id }
      expect(in_entry.amount).to eq(3000)
    end

    it "creates payable without transfer when account is payable system account" do
      post "/payables", params: {
        payable: {
          description: "办公用品采购",
          original_amount: 3000,
          date: Date.current,
          account_id: payable_system_account.id,
          counterparty_id: counterparty.id
        }
      }

      expect(response).to redirect_to(payables_path)

      payable = Payable.last
      expect(payable.transfer_id).to be_nil
    end

    it "handles validation errors" do
      post "/payables", params: {
        payable: { description: "", original_amount: nil }
      }
      expect(response).to redirect_to(payables_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "PATCH /payables/:id" do
    it "updates the payable and transfer amount" do
      payable_system_account

      payable = create(:payable,
        account: account,
        counterparty: counterparty,
        description: "原描述",
        original_amount: 500,
        date: Date.current
      )

      transfer_id = EntryCreationService.create_transfer(
        from_account_id: payable_system_account.id,
        to_account_id: account.id,
        amount: 500,
        date: Date.current,
        note: "创建应付款 原描述"
      )
      payable.update!(transfer_id: transfer_id)

      patch "/payables/#{payable.id}", params: {
        payable: { description: "新描述", original_amount: 1500 }
      }

      expect(response).to redirect_to(payables_path)
      expect(flash[:notice]).to eq("应付款已更新")
      expect(payable.reload.description).to eq("新描述")

      transfer_entries = Entry.where(transfer_id: transfer_id)
      out_entry = transfer_entries.find { |e| e.amount < 0 }
      expect(out_entry.amount.abs).to eq(1500)
    end
  end

  describe "DELETE /payables/:id" do
    it "deletes the payable with associated transfer entries" do
      payable_system_account

      payable = create(:payable, account: account, counterparty: counterparty, original_amount: 1000)

      transfer_id = EntryCreationService.create_transfer(
        from_account_id: payable_system_account.id,
        to_account_id: account.id,
        amount: 1000,
        date: Date.current,
        note: "创建应付款"
      )
      payable.update!(transfer_id: transfer_id)

      expect {
        delete "/payables/#{payable.id}"
      }.to change(Payable, :count).by(-1)

      expect(response).to redirect_to(payables_url)
      expect(flash[:notice]).to eq("应付款已删除")

      expect(Entry.where(transfer_id: transfer_id).count).to eq(0)
    end
  end

  describe "POST /payables/:id/settle" do
    let(:payable) { create(:payable, account: account, counterparty: counterparty, original_amount: 1000, remaining_amount: 1000) }

    before do
      payable_system_account
    end

    it "settles a payable with expense entry" do
      settle_account = create(:account, name: "付款账户")

      post "/payables/#{payable.id}/settle", params: {
        amount: 1000, account_id: settle_account.id, settlement_date: Date.current.to_s
      }

      expect(response).to redirect_to(payables_path)
      expect(flash[:notice]).to be_present
      expect(payable.reload.remaining_amount).to eq(0)
      expect(payable.settled_at).to be_present
      expect(payable.settlement_transfer_ids.size).to eq(2)

      expense_entry = Entry.find(payable.settlement_transfer_ids.first)
      expect(expense_entry.account_id).to eq(settle_account.id)
      expect(expense_entry.amount).to eq(-1000)
      expect(expense_entry.name).to include("付款")
      expect(expense_entry.entryable.kind).to eq("expense")

      income_entry = Entry.find(payable.settlement_transfer_ids.last)
      expect(income_entry.account_id).to eq(payable_system_account.id)
      expect(income_entry.amount).to eq(1000)
    end

    it "supports partial settlement" do
      settle_account = create(:account, name: "付款账户")

      post "/payables/#{payable.id}/settle", params: {
        amount: 300, account_id: settle_account.id, settlement_date: Date.current.to_s
      }

      expect(response).to redirect_to(payables_path)
      expect(payable.reload.remaining_amount).to eq(700)
      expect(payable.settled_at).to be_nil
      expect(payable.settlement_transfer_ids.size).to eq(2)
    end

    it "rejects invalid amount" do
      post "/payables/#{payable.id}/settle", params: { amount: 0, account_id: account.id }

      expect(response).to redirect_to(payables_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST /payables/:id/revert" do
    let(:payable) { create(:payable, account: account, counterparty: counterparty, original_amount: 1000, remaining_amount: 1000) }

    before do
      payable_system_account
    end

    it "reverts a settlement and deletes entries" do
      settle_account = create(:account, name: "付款账户")

      post "/payables/#{payable.id}/settle", params: {
        amount: 700, account_id: settle_account.id, settlement_date: Date.current.to_s
      }
      expect(payable.reload.remaining_amount).to eq(300)

      entry_ids = payable.reload.settlement_transfer_ids
      expect(Entry.where(id: entry_ids).count).to eq(2)

      post "/payables/#{payable.id}/revert"
      expect(response).to redirect_to(payables_path)
      expect(flash[:notice]).to be_present
      expect(payable.reload.remaining_amount).to eq(1000)
      expect(payable.settlement_transfer_ids).to be_empty

      expect(Entry.where(id: entry_ids).count).to eq(0)
    end

    it "supports multiple partial settlements" do
      settle_account = create(:account, name: "付款账户")

      post "/payables/#{payable.id}/settle", params: {
        amount: 300, account_id: settle_account.id, settlement_date: Date.current.to_s
      }

      payable.reload
      expect(payable.remaining_amount).to eq(700)
      expect(payable.settlement_transfer_ids.size).to eq(2)

      post "/payables/#{payable.id}/settle", params: {
        amount: 200, account_id: settle_account.id, settlement_date: Date.current.to_s
      }

      payable.reload
      expect(payable.remaining_amount).to eq(500)
      expect(payable.settlement_transfer_ids.size).to eq(4)

      post "/payables/#{payable.id}/revert"

      payable.reload
      expect(payable.remaining_amount).to eq(1000)
      expect(payable.settlement_transfer_ids).to be_empty

      payable.settlement_transfer_ids.each do |id|
        expect(Entry.where(id: id).count).to eq(0)
      end
    end
  end
end
