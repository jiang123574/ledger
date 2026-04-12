# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Misc Controllers", type: :request do
  describe "Api::VitalsController" do
    it "accepts web vitals metrics" do
      post "/api/vitals", params: {
        metric: "LCP", value: 1500, rating: "good", url: "/"
      }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PWA manifest" do
    it "returns manifest JSON" do
      get "/manifest"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to be_present
    end
  end
end
