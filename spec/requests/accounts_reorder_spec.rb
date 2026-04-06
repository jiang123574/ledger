# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accounts reorder", type: :request do
  let(:auth_headers) do
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "testpass")
    }
  end

  it "updates sort_order when dragging an account to a new position" do
    a1 = create(:account, sort_order: 0)
    a2 = create(:account, sort_order: 1)
    a3 = create(:account, sort_order: 2)

    patch "/accounts/#{a1.id}/reorder",
      params: { target_id: a3.id },
      headers: auth_headers,
      as: :json

    expect(response).to have_http_status(:ok)

    ordered_ids = Account.visible.order(:sort_order, :name).pluck(:id)
    reordered_subset = ordered_ids.select { |id| [a1.id, a2.id, a3.id].include?(id) }
    expect(reordered_subset).to eq([a2.id, a3.id, a1.id])
  end

  it "allows reordering against hidden accounts when show_hidden is true" do
    visible_1 = create(:account, sort_order: 0, hidden: false)
    hidden = create(:account, sort_order: 1, hidden: true)
    visible_2 = create(:account, sort_order: 2, hidden: false)

    patch "/accounts/#{visible_2.id}/reorder",
      params: { target_id: hidden.id, show_hidden: true },
      headers: auth_headers,
      as: :json

    expect(response).to have_http_status(:ok)

    ordered_ids = Account.order(:sort_order, :name).pluck(:id)
    reordered_subset = ordered_ids.select { |id| [visible_1.id, visible_2.id, hidden.id].include?(id) }
    expect(reordered_subset).to eq([visible_1.id, visible_2.id, hidden.id])
  end
end
