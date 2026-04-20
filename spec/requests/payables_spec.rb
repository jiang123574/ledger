# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payables", type: :request do
  before { login }

  let(:account) { create(:account) }
  let(:counterparty) { create(:counterparty, name: "供应商A") }

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
    it "creates a payable" do
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
    it "updates the payable" do
      payable = create(:payable,
        account: account, counterparty: counterparty,
        description: "原描述", original_amount: 500, date: Date.current
      )

      patch "/payables/#{payable.id}", params: {
        payable: { description: "新描述", original_amount: 1500 }
      }

      expect(response).to redirect_to(payables_path)
      expect(flash[:notice]).to eq("应付款已更新")
      expect(payable.reload.description).to eq("新描述")
    end
  end

  describe "DELETE /payables/:id" do
    it "deletes the payable" do
      payable = create(:payable, account: account, counterparty: counterparty)

      expect {
        delete "/payables/#{payable.id}"
      }.to change(Payable, :count).by(-1)

      expect(response).to redirect_to(payables_url)
      expect(flash[:notice]).to eq("应付款已删除")
    end
  end

  describe "POST /payables/:id/settle" do
    it "settles a payable and decreases remaining_amount" do
      payable = create(:payable,
        account: account, counterparty: counterparty,
        original_amount: 1000, remaining_amount: 1000
      )

      post "/payables/#{payable.id}/settle", params: {
        amount: 1000, account_id: account.id, settlement_date: Date.current.to_s
      }

      expect(response).to redirect_to(payables_path)
      expect(flash[:notice]).to be_present
      expect(payable.reload.remaining_amount).to eq(0)
    end

    it "supports partial settlement" do
      payable = create(:payable,
        account: account, counterparty: counterparty,
        original_amount: 1000, remaining_amount: 1000
      )

      post "/payables/#{payable.id}/settle", params: {
        amount: 300, account_id: account.id, settlement_date: Date.current.to_s
      }

      expect(response).to redirect_to(payables_path)
      expect(payable.reload.remaining_amount).to eq(700)
    end

    it "rejects invalid amount" do
      payable = create(:payable, account: account, counterparty: counterparty, original_amount: 1000)

      post "/payables/#{payable.id}/settle", params: { amount: 0, account_id: account.id }

      expect(response).to redirect_to(payables_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST /payables/:id/revert" do
    it "reverts a settlement and restores remaining_amount" do
      payable = create(:payable,
        account: account, counterparty: counterparty,
        original_amount: 1000, remaining_amount: 1000
      )

      # 先 settle
      post "/payables/#{payable.id}/settle", params: {
        amount: 700, account_id: account.id, settlement_date: Date.current.to_s
      }
      expect(payable.reload.remaining_amount).to eq(300)

      # 再 revert 最后一笔结算
      post "/payables/#{payable.id}/revert"
      expect(response).to redirect_to(payables_path)
      expect(flash[:notice]).to be_present
      expect(payable.reload.remaining_amount).to eq(1000)
    end
  end
end
