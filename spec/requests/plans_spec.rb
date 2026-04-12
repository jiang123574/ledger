# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Plans", type: :request do
  let(:account) { create(:account, name: "Test Account") }

  before do
    login
  end

  describe "GET /plans" do
    it "returns success" do
      get plans_path
      expect(response).to have_http_status(:success)
    end

    it "includes active plans in the page" do
      active_plan = create(:plan, :active, name: "Active Plan", account: account)
      inactive_plan = create(:plan, :inactive, name: "Inactive Plan", account: account)

      get plans_path

      expect(response.body).to include("Active Plan")
      expect(response.body).to include("Inactive Plan")
    end
  end

  describe "GET /plans/:id" do
    let(:plan) { create(:plan, name: "Test Plan", account: account) }

    # Note: show action may return 406 if no show view template exists
    # The project uses index with modal/details, not separate show page
  end

  describe "POST /plans" do
    let(:valid_attributes) do
      {
        name: "New Plan",
        type: "RECURRING",
        amount: 100.00,
        currency: "CNY",
        account_id: account.id,
        day_of_month: 15
      }
    end

    context "with valid parameters" do
      it "creates a new plan" do
        expect {
          post plans_path, params: { plan: valid_attributes }
        }.to change(Plan, :count).by(1)
      end

      it "redirects to plans index with success notice" do
        post plans_path, params: { plan: valid_attributes }
        expect(response).to redirect_to(plans_path)
        expect(flash[:notice]).to eq(I18n.t("plans.created"))
      end
    end

    context "with invalid parameters" do
      it "does not create a plan without name" do
        expect {
          post plans_path, params: { plan: valid_attributes.merge(name: nil) }
        }.not_to change(Plan, :count)
      end

      it "redirects to plans index with error alert" do
        post plans_path, params: { plan: valid_attributes.merge(name: nil) }
        expect(response).to redirect_to(plans_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "with installment type" do
      it "calculates amount from total_amount and installments_total" do
        post plans_path, params: {
          plan: {
            name: "Installment Plan",
            type: "INSTALLMENT",
            total_amount: 1200.00,
            installments_total: 12,
            currency: "CNY",
            account_id: account.id,
            day_of_month: 1
          }
        }

        plan = Plan.last
        expect(plan.amount).to eq(100.00)
      end
    end

    context "with mortgage type" do
      it "calculates total_amount from amount and remaining_periods" do
        post plans_path, params: {
          plan: {
            name: "Mortgage Plan",
            type: "MORTGAGE",
            amount: 5000.00,
            currency: "CNY",
            account_id: account.id,
            day_of_month: 1
          },
          remaining_periods: 24
        }

        plan = Plan.last
        expect(plan.total_amount).to eq(120000.00)
      end

      it "validates remaining_periods is greater than 0" do
        post plans_path, params: {
          plan: {
            name: "Mortgage Plan",
            type: "MORTGAGE",
            amount: 5000.00,
            currency: "CNY",
            account_id: account.id,
            day_of_month: 1
          },
          remaining_periods: 0
        }

        expect(response).to redirect_to(plans_path)
        expect(flash[:alert]).to include("房贷剩余期数必须大于 0")
      end
    end
  end

  describe "PATCH /plans/:id" do
    let(:plan) { create(:plan, :active, name: "Original Name", account: account, amount: 100.00) }

    context "with valid parameters" do
      it "updates the plan" do
        patch plan_path(plan), params: { plan: { name: "Updated Name" } }
        expect(plan.reload.name).to eq("Updated Name")
      end

      it "redirects to plans index with success notice" do
        patch plan_path(plan), params: { plan: { name: "Updated Name" } }
        expect(response).to redirect_to(plans_path)
        expect(flash[:notice]).to eq(I18n.t("plans.updated"))
      end
    end

    context "with invalid parameters" do
      it "does not update the plan" do
        original_name = plan.name
        patch plan_path(plan), params: { plan: { name: nil } }
        expect(plan.reload.name).to eq(original_name)
      end

      it "redirects to plans index with error alert" do
        patch plan_path(plan), params: { plan: { name: nil } }
        expect(response).to redirect_to(plans_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "toggling active status" do
      it "deactivates an active plan" do
        patch plan_path(plan), params: { plan: { active: false } }
        expect(plan.reload.active?).to be false
      end

      it "activates an inactive plan" do
        inactive_plan = create(:plan, :inactive, account: account)
        patch plan_path(inactive_plan), params: { plan: { active: true } }
        expect(inactive_plan.reload.active?).to be true
      end
    end
  end

  describe "DELETE /plans/:id" do
    let!(:plan) { create(:plan, name: "Plan to Delete", account: account) }

    it "destroys the plan" do
      expect {
        delete plan_path(plan)
      }.to change(Plan, :count).by(-1)
    end

    it "redirects to plans index with success notice" do
      delete plan_path(plan)
      expect(response).to redirect_to(plans_path)
      expect(flash[:notice]).to eq(I18n.t("plans.deleted"))
    end
  end

  describe "POST /plans/:id/execute" do
    let(:plan) { create(:plan, :active, name: "Execute Plan", account: account, amount: 100.00) }

    context "when plan has account" do
      it "generates a transaction" do
        expect {
          post execute_plan_path(plan)
        }.to change(Entry, :count).by(1)
      end

      it "redirects to the generated transaction" do
        post execute_plan_path(plan)
        entry = Entry.last
        expect(response).to redirect_to(transaction_path(entry))
        expect(flash[:notice]).to eq(I18n.t("plans.executed"))
      end

      it "updates last_generated timestamp" do
        post execute_plan_path(plan)
        expect(plan.reload.last_generated).to be_present
      end
    end

    context "when plan has no account" do
      let(:plan_without_account) { create(:plan, :active, name: "No Account Plan", account: nil) }

      it "redirects with error" do
        post execute_plan_path(plan_without_account)
        expect(response).to redirect_to(plans_path)
        expect(flash[:alert]).to eq(I18n.t("plans.need_account"))
      end
    end

    context "when installment plan is completed" do
      let(:completed_plan) do
        create(:plan, :active, :completed, name: "Completed Plan", account: account)
      end

      it "redirects with error" do
        post execute_plan_path(completed_plan)
        expect(response).to redirect_to(plans_path)
        expect(flash[:alert]).to eq(I18n.t("plans.already_completed"))
      end
    end

    context "for installment plan" do
      let(:installment_plan) do
        create(:plan, :active, :installment, name: "Installment", account: account, installments_completed: 0, installments_total: 12)
      end

      it "increments installments_completed" do
        post execute_plan_path(installment_plan)
        expect(installment_plan.reload.installments_completed).to eq(1)
      end

      it "deactivates plan when completed" do
        installment_plan.update!(installments_completed: 11)
        post execute_plan_path(installment_plan)
        expect(installment_plan.reload.active?).to be false
      end
    end
  end
end
