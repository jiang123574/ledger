# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accounts reorder", type: :request do
  before { login }

  describe "account reordering" do
    it "updates sort_order when dragging an account to a new position" do
      a1 = create(:account, sort_order: 0)
      a2 = create(:account, sort_order: 1)
      a3 = create(:account, sort_order: 2)

      patch "/accounts/#{a1.id}/reorder",
        params: { target_id: a3.id },
        as: :json

      expect(response).to have_http_status(:ok)

      ordered_ids = Account.visible.order(:sort_order, :name).pluck(:id)
      reordered_subset = ordered_ids.select { |id| [ a1.id, a2.id, a3.id ].include?(id) }
      expect(reordered_subset).to eq([ a2.id, a3.id, a1.id ])
    end

    it "allows reordering against hidden accounts when show_hidden is true" do
      visible_1 = create(:account, sort_order: 0, hidden: false)
      hidden = create(:account, sort_order: 1, hidden: true)
      visible_2 = create(:account, sort_order: 2, hidden: false)

      patch "/accounts/#{visible_2.id}/reorder",
        params: { target_id: hidden.id, show_hidden: true },
        as: :json

      expect(response).to have_http_status(:ok)

      ordered_ids = Account.order(:sort_order, :name).pluck(:id)
      reordered_subset = ordered_ids.select { |id| [ visible_1.id, visible_2.id, hidden.id ].include?(id) }
      expect(reordered_subset).to eq([ visible_1.id, visible_2.id, hidden.id ])
    end
  end

  describe "entry reordering" do
    let(:account) { create(:account) }
    let(:date) { Date.today }

    it "successfully reorders entries and updates balances", :aggregate_failures do
      e1 = create(:entry, account: account, date: date, amount: -10.0, sort_order: 3)
      e2 = create(:entry, account: account, date: date, amount: -20.0, sort_order: 2)
      e3 = create(:entry, account: account, date: date, amount: 50.0, sort_order: 1)

      reordered_ids = [ e3.id, e1.id, e2.id ]

      patch "/accounts/#{account.id}/reorder_entries",
        params: { entry_ids: reordered_ids, date: date.to_s },
        as: :json

      expect(response).to have_http_status(:ok)

      response_data = JSON.parse(response.body)
      expect(response_data["success"]).to be true
      expect(response_data["balances"]).to be_an(Array)
      expect(response_data["balances"].size).to eq(3)

      # Controller sets sort_order as total_entries - index (descending for first item)
      # So order by sort_order ascending gives: e2(1), e1(2), e3(3)
      entries = Entry.where(id: reordered_ids).order(:sort_order)
      expect(entries.pluck(:id)).to eq([ e2.id, e1.id, e3.id ])

      balances = response_data["balances"]
      # Balances are returned in date asc, sort_order asc order
      expect(balances[0]["entry_id"]).to eq(e2.id)
      expect(balances[1]["entry_id"]).to eq(e1.id)
      expect(balances[2]["entry_id"]).to eq(e3.id)
    end

    it "returns error for mismatched entry count" do
      e1 = create(:entry, account: account, date: date, amount: -10.0)
      e2 = create(:entry, account: account, date: date, amount: -20.0)

      patch "/accounts/#{account.id}/reorder_entries",
        params: { entry_ids: [ e1.id ], date: date.to_s },
        as: :json

      expect(response).to have_http_status(:unprocessable_content)

      response_data = JSON.parse(response.body)
      expect(response_data["success"]).to be false
      expect(response_data["error"]).to include("条目列表不匹配")
    end

    it "returns error for invalid date" do
      patch "/accounts/#{account.id}/reorder_entries",
        params: { entry_ids: [], date: "invalid-date" },
        as: :json

      expect(response).to have_http_status(:bad_request)

      response_data = JSON.parse(response.body)
      expect(response_data["success"]).to be false
      expect(response_data["error"]).to include("日期格式不正确")
    end
  end
end
