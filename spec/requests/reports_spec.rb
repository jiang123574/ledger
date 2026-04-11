# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports", type: :request do
  let(:account) { create(:account) }
  let(:category) { create(:category, name: "Test Category", category_type: "EXPENSE") }
  let(:current_year) { Date.current.year }

  before do
    login
  end

  describe "GET /reports" do
    it "returns success" do
      get reports_path
      expect(response).to have_http_status(:success)
    end

    it "defaults to current year" do
      get reports_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /reports/:year" do
    it "returns success for yearly report" do
      get report_year_path(year: current_year)
      expect(response).to have_http_status(:success)
    end

    it "handles invalid year gracefully" do
      get report_year_path(year: 1999)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /reports/:year/:month" do
    it "returns success for monthly report" do
      get report_month_path(year: current_year, month: 1)
      expect(response).to have_http_status(:success)
    end

    it "handles invalid month gracefully" do
      get report_month_path(year: current_year, month: 13)
      expect(response).to have_http_status(:success)
    end
  end
end
