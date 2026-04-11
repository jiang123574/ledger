# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Versions", type: :request do
  let(:account) { create(:account) }
  let(:entry) { create(:entry, :expense, account: account) }

  before do
    login
  end

  describe "GET /versions" do
    it "returns success" do
      get versions_path
      expect(response).to have_http_status(:success)
    end

    it "displays activity logs" do
      ActivityLog.create!(
        action: "create",
        item_type: "Entry",
        item_id: entry.id,
        description: "创建交易"
      )

      get versions_path
      expect(response).to have_http_status(:success)
    end

    context "with filters" do
      it "filters by item_type" do
        get versions_path, params: { item_type: "Entry" }
        expect(response).to have_http_status(:success)
      end

      it "filters by action_type" do
        get versions_path, params: { action_type: "create" }
        expect(response).to have_http_status(:success)
      end

      it "filters by search" do
        get versions_path, params: { search: "test" }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /versions/:id" do
    let(:activity_log) do
      ActivityLog.create!(
        action: "create",
        item_type: "Entry",
        item_id: entry.id,
        description: "创建交易"
      )
    end

    it "returns success" do
      get version_path(activity_log)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /versions/:id/revert" do
    let(:activity_log) do
      ActivityLog.create!(
        action: "create",
        item_type: "Entry",
        item_id: entry.id,
        description: "创建交易"
      )
    end

    context "when revert succeeds" do
      before do
        allow_any_instance_of(ActivityLog).to receive(:revert!).and_return(true)
      end

      it "redirects with success notice" do
        post revert_version_path(activity_log)
        expect(response).to redirect_to(versions_path)
        expect(flash[:notice]).to eq("已成功回滚操作")
      end
    end

    context "when revert fails" do
      before do
        allow_any_instance_of(ActivityLog).to receive(:revert!).and_return(false)
      end

      it "redirects with error alert" do
        post revert_version_path(activity_log)
        expect(response).to redirect_to(versions_path)
        expect(flash[:alert]).to eq("回滚失败")
      end
    end
  end
end
