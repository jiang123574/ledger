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

    expect(a2.reload.sort_order).to eq(0)
    expect(a3.reload.sort_order).to eq(1)
    expect(a1.reload.sort_order).to eq(2)
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

    expect(visible_1.reload.sort_order).to eq(0)
    expect(visible_2.reload.sort_order).to eq(1)
    expect(hidden.reload.sort_order).to eq(2)
  end
end
