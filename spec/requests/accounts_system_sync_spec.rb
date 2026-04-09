# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accounts system sync fallback", type: :request do
  before { login }

  let(:receivable_name) { "测试应收款#{SecureRandom.hex(4)}" }
  let(:payable_name) { "测试应付款#{SecureRandom.hex(4)}" }

  before do
    stub_const("SystemAccountSyncService::RECEIVABLE_ACCOUNT_NAME", receivable_name)
    stub_const("SystemAccountSyncService::PAYABLE_ACCOUNT_NAME", payable_name)
  end

  it "creates missing payable system account when visiting accounts index" do
    create(:account, name: receivable_name, initial_balance: 0)
    Payable.create!(
      description: "待付款测试",
      original_amount: 88,
      remaining_amount: 88,
      date: Date.current
    )
    Account.where(name: payable_name).delete_all

    expect {
      get "/accounts"
    }.to change { Account.where(name: payable_name).count }.from(0).to(1)

    expect(response).to have_http_status(:ok)
    expect(Account.find_by(name: payable_name)&.initial_balance.to_d).to eq(-88.to_d)
  end

  it "does not create extra system accounts when both already exist" do
    create(:account, name: receivable_name, initial_balance: 0)
    create(:account, name: payable_name, initial_balance: 0)

    expect {
      get "/accounts"
    }.not_to change { Account.where(name: [ receivable_name, payable_name ]).count }

    expect(response).to have_http_status(:ok)
  end
end
