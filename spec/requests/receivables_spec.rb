# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Receivables", type: :request do
  before { login }

  let(:account) { create(:account) }
  let(:counterparty) { create(:counterparty, name: "客户A") }

  describe "GET /receivables" do
    it "renders the index page" do
      get "/receivables"
      expect(response).to have_http_status(:ok)
    end

    it "shows receivable descriptions" do
      create(:receivable, account: account, counterparty: counterparty, description: "测试应收款")
      get "/receivables"
      expect(response.body).to include("测试应收款")
    end
  end

  describe "GET /receivables with filters" do
    let(:counterparty_a) { create(:counterparty, name: "客户A") }
    let(:counterparty_b) { create(:counterparty, name: "客户B") }

    it "filters by counterparty id" do
      create(:receivable, account: account, counterparty: counterparty_a, description: "客户A收款")
      create(:receivable, account: account, counterparty: counterparty_b, description: "客户B收款")

      get "/receivables", params: { counterparty_id: "id:#{counterparty_a.id}" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("客户A收款")
      expect(response.body).not_to include("客户B收款")
    end

    it "filters by none token for receivables without counterparty" do
      create(:receivable, account: account, counterparty: nil, description: "无客户收款")
      create(:receivable, account: account, counterparty: counterparty_a, description: "有客户收款")

      get "/receivables", params: { counterparty_id: "none" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("无客户收款")
      expect(response.body).not_to include("有客户收款")
    end
  end

  describe "POST /receivables" do
    before do
      create(:account, name: SystemAccountSyncService::RECEIVABLE_ACCOUNT_NAME, type: "CASH")
    end

    it "creates a receivable" do
      expect {
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
      }.to change(Receivable, :count).by(1)

      expect(response).to redirect_to(receivables_path)
      expect(flash[:notice]).to eq("应收款已创建")

      receivable = Receivable.last
      expect(receivable.description).to eq("咨询费")
      expect(receivable.original_amount).to eq(5000)
      expect(receivable.remaining_amount).to eq(5000)
    end

    it "handles validation errors" do
      post "/receivables", params: {
        receivable: {
          description: "",
          original_amount: nil
        }
      }
      expect(response).to redirect_to(receivables_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "PATCH /receivables/:id" do
    it "updates the receivable" do
      receivable = create(:receivable,
        account: account,
        counterparty: counterparty,
        description: "原描述",
        original_amount: 1000,
        date: Date.current
      )

      patch "/receivables/#{receivable.id}", params: {
        receivable: {
          description: "新描述",
          original_amount: 2000
        }
      }

      expect(response).to redirect_to(receivables_path)
      expect(flash[:notice]).to eq("应收款已更新")
      expect(receivable.reload.description).to eq("新描述")
    end
  end

  describe "DELETE /receivables/:id" do
    it "deletes the receivable" do
      receivable = create(:receivable, account: account, counterparty: counterparty)

      expect {
        delete "/receivables/#{receivable.id}"
      }.to change(Receivable, :count).by(-1)

      expect(response).to redirect_to(receivables_url)
      expect(flash[:notice]).to eq("应收款已删除")
    end
  end

  describe "POST /receivables/:id/settle" do
    it "settles a receivable" do
      receivable = create(:receivable,
        account: account,
        counterparty: counterparty,
        original_amount: 1000,
        remaining_amount: 1000
      )

      post "/receivables/#{receivable.id}/settle", params: {
        amount: 1000,
        account_id: account.id,
        settlement_date: Date.current.to_s
      }

      expect(response).to redirect_to(receivables_path)
      expect(flash[:notice]).to be_present
    end

    it "rejects invalid amount" do
      receivable = create(:receivable, account: account, counterparty: counterparty, original_amount: 1000)

      post "/receivables/#{receivable.id}/settle", params: {
        amount: 0,
        account_id: account.id
      }

      expect(response).to redirect_to(receivable_path(receivable))
      expect(flash[:alert]).to be_present
    end

    it "rejects missing account" do
      receivable = create(:receivable, account: account, counterparty: counterparty, original_amount: 1000)

      post "/receivables/#{receivable.id}/settle", params: {
        amount: 500,
        account_id: ""
      }

      expect(response).to redirect_to(receivable_path(receivable))
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST /receivables/:id/revert" do
    it "reverts a settlement" do
      receivable = create(:receivable,
        account: account,
        counterparty: counterparty,
        original_amount: 1000,
        remaining_amount: 1000
      )

      post "/receivables/#{receivable.id}/revert"
      expect(response).to redirect_to(receivables_path)
    end
  end
end
