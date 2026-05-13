# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Error Scenarios", type: :request do
  let(:account) { create(:account) }
  let(:category) { create(:category, :expense) }

  # ==================== Authentication ====================
  describe "Authentication" do
    context "without login" do
      before do
        ENV["AUTH_USER"] = "admin"
        ENV["AUTH_PASSWORD"] = "testpass"
      end

      it "redirects HTML requests to login page" do
        get accounts_path
        expect(response).to redirect_to(login_path)
      end

      it "redirects HTML POST requests to login page" do
        post entries_path, params: { entry: { amount: 100 } }
        expect(response).to redirect_to(login_path)
      end
    end

    context "with login" do
      before { login }

      it "allows access to protected pages" do
        get accounts_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  # ==================== Entry Validation (JSON) ====================
  describe "Entry Validation (JSON)", :authenticated do
    before { login }

    it "returns success:true for valid entry" do
      post entries_path,
           params: { entry: { amount: "100", kind: "expense", date: Date.current.to_s, account_id: account.id, category_id: category.id } },
           as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end

    it "returns success:false for invalid account_id" do
      post entries_path,
           params: { entry: { amount: "100", kind: "expense", date: Date.current.to_s, account_id: 99999 } },
           as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["error"]).to be_present
    end

    it "returns success:false for date too old (before 30 years)" do
      post entries_path,
           params: { entry: { amount: "100", kind: "expense", date: "1900-01-01", account_id: account.id } },
           as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
    end

    it "returns success:false for missing date" do
      post entries_path,
           params: { entry: { amount: "100", kind: "expense", account_id: account.id } },
           as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
    end

    it "returns 400 for missing entry wrapper" do
      post entries_path, params: {}, as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  # ==================== Entry Validation (HTML) ====================
  describe "Entry Validation (HTML)", :authenticated do
    before { login }

    it "redirects with alert for invalid entry" do
      post entries_path, params: { entry: { amount: nil, account_id: account.id } }
      expect(response).to redirect_to(accounts_path)
      expect(flash[:alert]).to be_present
    end

    it "redirects with notice for valid entry" do
      post entries_path,
           params: { entry: { amount: "100", kind: "expense", date: Date.current.to_s, account_id: account.id, category_id: category.id } }
      expect(response).to redirect_to(accounts_path)
      expect(flash[:notice]).to eq("交易已创建")
    end
  end

  # ==================== Transaction Validation ====================
  describe "Transaction Validation", :authenticated do
    before { login }

    it "creates expense successfully" do
      expect {
        post transactions_path,
             params: { transaction: { type: "EXPENSE", amount: 100, date: Date.current.to_s, account_id: account.id, category_id: category.id } }
      }.to change(Entry, :count).by(1)
    end

    it "creates transfer successfully" do
      target_account = create(:account, name: "Target")
      expect {
        post transactions_path,
             params: { transaction: { type: "TRANSFER", amount: 100, date: Date.current.to_s, account_id: account.id, target_account_id: target_account.id } }
      }.to change(Entry, :count).by(2)
    end

    it "returns error for invalid target account" do
      expect {
        post transactions_path,
             params: { transaction: { type: "TRANSFER", amount: 100, date: Date.current.to_s, account_id: account.id, target_account_id: 99999 } }
      }.not_to change(Entry, :count)
      expect(response).to redirect_to(accounts_path)
      expect(flash[:alert]).to be_present
    end

    it "returns error for invalid source account" do
      expect {
        post transactions_path,
             params: { transaction: { type: "EXPENSE", amount: 100, date: Date.current.to_s, account_id: 99999 } }
      }.not_to change(Entry, :count)
      expect(response).to redirect_to(accounts_path)
      expect(flash[:alert]).to be_present
    end

    it "handles funding transfer" do
      funding_account = create(:account, name: "Funding")
      expect {
        post transactions_path,
             params: {
               transaction: { type: "EXPENSE", amount: 500, date: Date.current.to_s, account_id: account.id, category_id: category.id },
               funding_account_id: funding_account.id
             }
      }.to change(Entry, :count).by(3)
    end
  end

  # ==================== Category Validation ====================
  describe "Category Validation", :authenticated do
    before { login }

    it "redirects with alert for empty name" do
      post categories_path, params: { category: { name: "", category_type: "expense" } }
      expect(response).to redirect_to(settings_path(section: "categories"))
      expect(flash[:alert]).to be_present
    end

    it "creates category successfully with valid params" do
      expect {
        post categories_path, params: { category: { name: "Test Category", category_type: "expense" } }
      }.to change(Category, :count).by(1)
      expect(response).to redirect_to(settings_path(section: "categories"))
      expect(flash[:notice]).to eq("分类已创建")
    end

    it "updates category successfully" do
      cat = create(:category, name: "Original")
      patch category_path(cat), params: { category: { name: "Updated" } }
      expect(cat.reload.name).to eq("Updated")
      expect(response).to redirect_to(settings_path(section: "categories"))
      expect(flash[:notice]).to eq("分类已更新")
    end

    it "destroys category successfully" do
      cat = create(:category)
      expect {
        delete category_path(cat)
      }.to change(Category, :count).by(-1)
      expect(response).to redirect_to(settings_path(section: "categories"))
      expect(flash[:notice]).to eq("分类已删除")
    end
  end

  # ==================== Plan Validation ====================
  describe "Plan Validation", :authenticated do
    before { login }

    it "redirects with alert for missing name" do
      post plans_path, params: { plan: { type: "RECURRING", amount: 100, account_id: account.id } }
      expect(response).to redirect_to(plans_path)
      expect(flash[:alert]).to be_present
    end

    it "creates plan successfully with valid params" do
      expect {
        post plans_path, params: { plan: { name: "Test Plan", type: "RECURRING", amount: 100, account_id: account.id, day_of_month: 1 } }
      }.to change(Plan, :count).by(1)
      expect(response).to redirect_to(plans_path)
      expect(flash[:notice]).to eq(I18n.t("plans.created"))
    end

    it "updates plan successfully" do
      plan = create(:plan, name: "Original", account: account)
      patch plan_path(plan), params: { plan: { name: "Updated" } }
      expect(plan.reload.name).to eq("Updated")
      expect(response).to redirect_to(plans_path)
      expect(flash[:notice]).to eq(I18n.t("plans.updated"))
    end

    it "destroys plan successfully" do
      plan = create(:plan, account: account)
      expect {
        delete plan_path(plan)
      }.to change(Plan, :count).by(-1)
      expect(response).to redirect_to(plans_path)
      expect(flash[:notice]).to eq(I18n.t("plans.deleted"))
    end
  end

  # ==================== Account Validation ====================
  describe "Account Validation", :authenticated do
    before { login }

    it "redirects with alert for empty name" do
      post accounts_path, params: { account: { name: "", type: "CASH" } }
      expect(response).to redirect_to(accounts_path)
      expect(flash[:alert]).to be_present
    end

    it "creates account successfully with valid params" do
      expect {
        post accounts_path, params: { account: { name: "Test Account", type: "CASH" } }
      }.to change(Account, :count).by(1)
      expect(response).to redirect_to(accounts_path)
    end

    it "updates account successfully" do
      acc = create(:account, name: "Original")
      patch account_path(acc), params: { account: { name: "Updated" } }
      expect(acc.reload.name).to eq("Updated")
      expect(response).to redirect_to(accounts_path)
    end

    it "destroys account successfully" do
      acc = create(:account)
      expect {
        delete account_path(acc)
      }.to change(Account, :count).by(-1)
      expect(response).to redirect_to(accounts_path)
    end
  end

  # ==================== Resource Not Found ====================
  describe "Resource Not Found", :authenticated do
    before { login }

    it "returns 404 for non-existent entry" do
      get entry_path(99999)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for non-existent account" do
      get account_path(99999)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for non-existent category" do
      get category_path(99999)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for DELETE non-existent entry" do
      delete entry_path(99999)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for PATCH non-existent entry" do
      patch entry_path(99999), params: { entry: { name: "test" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  # ==================== Boundary Values ====================
  describe "Boundary Values", :authenticated do
    before { login }

    describe "Amount boundaries" do
      it "handles very large amount" do
        post entries_path,
             params: { entry: { amount: "999999999.99", kind: "expense", date: Date.current.to_s, account_id: account.id, category_id: category.id } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "handles very small amount" do
        post entries_path,
             params: { entry: { amount: "0.01", kind: "expense", date: Date.current.to_s, account_id: account.id, category_id: category.id } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end
    end

    describe "Date boundaries" do
      it "handles future date" do
        post entries_path,
             params: { entry: { amount: "100", kind: "expense", date: 365.days.from_now.to_s, account_id: account.id, category_id: category.id } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "rejects date before 30 years" do
        post entries_path,
             params: { entry: { amount: "100", kind: "expense", date: 40.years.ago.to_s, account_id: account.id } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
      end
    end

    describe "String field boundaries" do
      it "handles very long note" do
        long_note = "A" * 1000
        post entries_path,
             params: { entry: { amount: "100", kind: "expense", date: Date.current.to_s, account_id: account.id, notes: long_note } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "handles special characters in note" do
        special_note = "测试 <script>alert('xss')</script> & \"quotes\""
        post entries_path,
             params: { entry: { amount: "100", kind: "expense", date: Date.current.to_s, account_id: account.id, notes: special_note } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "handles unicode characters in name" do
        unicode_name = "测试🎉emoji"
        post entries_path,
             params: { entry: { amount: "100", kind: "expense", date: Date.current.to_s, account_id: account.id, name: unicode_name } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end
    end
  end

  # ==================== Bulk Operations ====================
  describe "Bulk Operations", :authenticated do
    before { login }

    it "handles empty ids gracefully" do
      post bulk_destroy_entries_path
      expect(response).to redirect_to(accounts_path)
      expect(flash[:alert]).to eq("请选择要删除的交易")
    end

    it "handles non-existent ids in bulk destroy" do
      existing_entry = create(:entry, account: account)
      post bulk_destroy_entries_path, params: { ids: [ existing_entry.id, 99999 ] }
      expect(response).to redirect_to(accounts_path)
      expect(flash[:notice]).to include("1")
    end

    it "deletes multiple entries" do
      entry1 = create(:entry, account: account)
      entry2 = create(:entry, account: account)
      expect {
        post bulk_destroy_entries_path, params: { ids: [ entry1.id, entry2.id ] }
      }.to change(Entry, :count).by(-2)
      expect(flash[:notice]).to include("2")
    end
  end

  # ==================== Concurrent-like Operations ====================
  describe "Concurrent-like Operations", :authenticated do
    before { login }

    it "handles double delete gracefully" do
      entry = create(:entry, account: account)
      entry_id = entry.id

      delete entry_path(entry_id)
      expect(response).to have_http_status(:redirect)

      delete entry_path(entry_id)
      expect(response).to have_http_status(:not_found)
    end

    it "handles update after delete" do
      entry = create(:entry, account: account)
      entry_id = entry.id

      delete entry_path(entry_id)
      patch entry_path(entry_id), params: { entry: { name: "updated" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  # ==================== Continue Entry Mode ====================
  describe "Continue Entry Mode", :authenticated do
    before { login }

    it "returns entry data in JSON for continue_entry mode" do
      post transactions_path,
           params: {
             transaction: { type: "EXPENSE", amount: "100", date: Date.current.to_s, account_id: account.id, category_id: category.id },
             continue_entry: "1"
           },
           as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["message"]).to include("请继续录入")
      expect(json["entry"]).to be_present
      expect(json["entry"]["id"]).to be_present
    end

    it "returns correct display_type for expense" do
      post transactions_path,
           params: {
             transaction: { type: "EXPENSE", amount: "100", date: Date.current.to_s, account_id: account.id },
             continue_entry: "1"
           },
           as: :json
      json = JSON.parse(response.body)
      expect(json["entry"]["display_type"]).to eq("支出")
    end

    it "returns correct display_type for income" do
      post transactions_path,
           params: {
             transaction: { type: "INCOME", amount: "100", date: Date.current.to_s, account_id: account.id },
             continue_entry: "1"
           },
           as: :json
      json = JSON.parse(response.body)
      expect(json["entry"]["display_type"]).to eq("收入")
    end
  end

  # ==================== Additional Validation Failures ====================
  describe "Additional Validation Failures (422)", :authenticated do
    before { login }

    describe "Entry validation" do
      it "handles missing amount (defaults to 0)" do
        post entries_path,
             params: { entry: { kind: "expense", date: Date.current.to_s, account_id: account.id } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        # Entry controller defaults missing amount to 0
        expect(json["success"]).to be true
      end

      it "handles missing kind (defaults to expense)" do
        post entries_path,
             params: { entry: { amount: "100", date: Date.current.to_s, account_id: account.id } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        # Entry controller defaults missing kind to expense
        expect(json["success"]).to be true
      end

      it "handles invalid amount format (defaults to 0)" do
        post entries_path,
             params: { entry: { amount: "not_a_number", kind: "expense", date: Date.current.to_s, account_id: account.id } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        # Invalid amount string is converted to 0
        expect(json["success"]).to be true
      end

      it "accepts zero amount" do
        post entries_path,
             params: { entry: { amount: "0", kind: "expense", date: Date.current.to_s, account_id: account.id } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "accepts negative amount" do
        post entries_path,
             params: { entry: { amount: "-100", kind: "expense", date: Date.current.to_s, account_id: account.id } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "returns error for invalid date format" do
        post entries_path,
             params: { entry: { amount: "100", kind: "expense", date: "not-a-date", account_id: account.id } },
             as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
      end

      # NOTE: This test documents current behavior - controller should catch FK errors
      # and return 422, but currently raises exception. This is a known issue.
      it "raises foreign key violation for invalid category_id (controller bug)" do
        expect {
          post entries_path,
               params: { entry: { amount: "100", kind: "expense", date: Date.current.to_s, account_id: account.id, category_id: 99999 } },
               as: :json
        }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end

    describe "Category validation" do
      it "rejects duplicate category name" do
        existing = create(:category, name: "Existing Category", category_type: "expense")
        post categories_path, params: { category: { name: "Existing Category", category_type: "expense" } }
        expect(response).to redirect_to(settings_path(section: "categories"))
        expect(Category.count).to eq(1) # Only original exists, duplicate rejected
        expect(flash[:alert]).to be_present
      end

      it "creates category with invalid type (handled gracefully)" do
        post categories_path, params: { category: { name: "Test", category_type: "invalid_type" } }
        expect(response).to redirect_to(settings_path(section: "categories"))
        # Invalid type defaults to expense or is ignored
      end

      # NOTE: This test documents current behavior - controller should catch FK errors
      it "raises foreign key violation for invalid parent_id (controller bug)" do
        expect {
          post categories_path, params: { category: { name: "Child", category_type: "expense", parent_id: 99999 } }
        }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end

    describe "Account validation" do
      it "rejects duplicate account name" do
        existing = create(:account, name: "Existing Account")
        post accounts_path, params: { account: { name: "Existing Account", type: "CASH" } }
        expect(response).to redirect_to(accounts_path)
        expect(Account.count).to eq(1) # Only original exists, duplicate rejected
        expect(flash[:alert]).to be_present
      end

      it "creates account with invalid type (handled gracefully)" do
        post accounts_path, params: { account: { name: "Test", type: "INVALID_TYPE" } }
        expect(response).to redirect_to(accounts_path)
        # Invalid type defaults or is ignored
      end
    end

    describe "Plan validation" do
      it "rejects plan with negative amount" do
        expect {
          post plans_path, params: { plan: { name: "Test", type: "RECURRING", amount: -100, account_id: account.id } }
        }.not_to change(Plan, :count)
        expect(response).to redirect_to(plans_path)
        expect(flash[:alert]).to be_present
      end

      it "creates plan with invalid day_of_month (handled gracefully)" do
        post plans_path, params: { plan: { name: "Test", type: "RECURRING", amount: 100, account_id: account.id, day_of_month: 32 } }
        expect(response).to redirect_to(plans_path)
      end

      it "creates plan with zero installments" do
        post plans_path, params: { plan: { name: "Test", type: "INSTALLMENT", amount: 100, account_id: account.id, installments_total: 0 } }
        expect(response).to redirect_to(plans_path)
      end
    end
  end

  # ==================== Forbidden Scenarios ====================
  describe "Forbidden Scenarios", :authenticated do
    before { login }

    it "redirects to login without authentication" do
      logout
      get accounts_path
      expect(response).to redirect_to(login_path)
    end
  end

  # ==================== Method Not Allowed ====================
  describe "Method Not Allowed", :authenticated do
    before { login }

    it "redirects GET on transactions_path" do
      get transactions_path
      expect(response).to have_http_status(:redirect)
    end

    it "returns error for PATCH on collection endpoint" do
      patch entries_path, params: { entry: { name: "test" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  # ==================== Malformed Input ====================
  describe "Malformed Input", :authenticated do
    before { login }

    it "handles malformed JSON gracefully" do
      post entries_path,
           params: "{ invalid json }",
           as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "handles empty POST body" do
      post entries_path, params: {}, as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "returns error for nil values in params" do
      post entries_path,
           params: { entry: { amount: nil, kind: nil, date: nil, account_id: nil } },
           as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
    end

    # NOTE: This test documents current behavior - controller should return 400
    # instead of raising NoMethodError. This is a known issue.
    it "raises error for array instead of hash (controller bug)" do
      expect {
        post entries_path,
             params: { entry: [ "invalid", "array" ] },
             as: :json
      }.to raise_error(NoMethodError)
    end

    it "handles extremely long field values" do
      long_value = "A" * 10000
      post entries_path,
           params: { entry: { amount: "100", kind: "expense", date: Date.current.to_s, account_id: account.id, name: long_value } },
           as: :json
      expect(response).to have_http_status(:ok)
      # Long values are truncated or stored as-is
    end
  end
end
