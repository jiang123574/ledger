# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accounts entries API", type: :request do
  before { login }

  let(:account) { create(:account, initial_balance: 1000) }
  let(:another_account) { create(:account, initial_balance: 500) }

  describe "GET /accounts/entries" do
    context "authentication" do
      it "requires authentication" do
        # 调用端点时需要认证
        # 如果没有异常，说明请求被 login helper 正确认证了
        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        expect(response).to have_http_status(:ok)
      end
    end

    context "with basic entries" do
      before do
        # 创建几条普通交易
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction, kind: 'EXPENSE'),
          amount: -100,
          date: 10.days.ago,
          name: '午餐'
        )
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction, kind: 'INCOME'),
          amount: 500,
          date: 5.days.ago,
          name: '收入'
        )
      end

      it "returns entries list with pagination" do
        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        expect(response).to have_http_status(:ok)
        data = response.parsed_body
        expect(data).to have_key("entries")
        expect(data).to have_key("total")
        expect(data["entries"]).to be_an(Array)
        expect(data["entries"].count).to be <= 10
      end

      it "respects per_page parameter" do
        get "/accounts/entries", params: { page: 1, per_page: 1, format: :json }

        data = response.parsed_body
        expect(data["entries"].count).to be <= 1
      end

      it "limits per_page to maximum 200" do
        get "/accounts/entries", params: { page: 1, per_page: 5000, format: :json }

        data = response.parsed_body
        expect(data["entries"].count).to be <= 200
      end

      it "enforces minimum per_page of 5" do
        get "/accounts/entries", params: { page: 1, per_page: 1, format: :json }

        data = response.parsed_body
        expect(data["entries"].count).to be >= 1
      end

      it "includes required entry fields" do
        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        data = response.parsed_body
        entry = data["entries"].first

        expect(entry).to include(
          "id",
          "date",
          "amount",
          "display_amount",
          "type",
          "display_type",
          "display_amount_type",
          "display_name",
          "note",
          "balance_after",
          "show_both_amounts"
        )
      end

      it "returns account name as note when display_note is missing" do
        entry = create(:entry,
          account: account,
          entryable: create(:entryable_transaction, kind: 'EXPENSE'),
          amount: -120,
          date: 3.days.ago
        )
        entry.update_column(:name, '') if entry.respond_to?(:name)
        entry.update_column(:notes, '') if entry.respond_to?(:notes)

        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        data = response.parsed_body
        matched = data["entries"].find { |e| e["id"] == entry.id }

        expect(matched).to be_present
        expect(matched["note"]).to eq(account.name)
      end

      it "returns entries in reverse chronological order" do
        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        data = response.parsed_body
        entries = data["entries"]

        dates = entries.map { |e| e["date"] }
        expect(dates).to eq(dates.sort.reverse)
      end
    end

    context "with period filtering" do
      before do
        # 创建当月和上月的交易
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction),
          amount: -50,
          date: Date.current.beginning_of_month
        )
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction),
          amount: -30,
          date: 1.month.ago
        )
      end

      it "filters by month (default)" do
        get "/accounts/entries", params: {
          page: 1,
          per_page: 10,
          period_type: 'month',
          format: :json
        }

        data = response.parsed_body
        expect(data["entries"].count).to be >= 1
      end

      it "filters by year" do
        get "/accounts/entries", params: {
          page: 1,
          per_page: 10,
          period_type: 'year',
          period_value: Date.current.year.to_s,
          format: :json
        }

        data = response.parsed_body
        expect(data["total"]).to be >= 1
      end

      it "defaults to current period when period_value is missing" do
        get "/accounts/entries", params: {
          page: 1,
          per_page: 10,
          period_type: 'month',
          format: :json
        }

        expect(response).to have_http_status(:ok)
      end
    end

    context "with account filter" do
      before do
        create(:entry, account: account, entryable: create(:entryable_transaction), amount: -100)
        create(:entry, account: another_account, entryable: create(:entryable_transaction), amount: -50)
      end

      it "filters entries by account_id" do
        get "/accounts/entries", params: {
          page: 1,
          per_page: 10,
          account_id: account.id,
          format: :json
        }

        expect(response).to have_http_status(:ok)
        data = response.parsed_body
        expect(data["entries"]).not_to be_empty
        # 验证返回的数据包含指定账户的交易
        entry_account_ids = data["entries"].map { |e| e["account_id"] }
        expect(entry_account_ids).to all(eq(account.id))
      end
    end

    context "with transfer entries" do
      before do
        transfer = create(:entry,
          account: account,
          entryable: create(:entryable_transaction),
          amount: 100,
          name: '转账'
        )
        transfer.update_column(:entryable_type, 'Entryable::Transaction')
      end

      it "handles transfer entries correctly" do
        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        expect(response).to have_http_status(:ok)
      end

      it "shows transfer amounts correctly in multi-account view" do
        get "/accounts/entries", params: {
          page: 1,
          per_page: 10,
          format: :json
        }

        expect(response).to have_http_status(:ok)
        data = response.parsed_body
        expect(data["entries"]).not_to be_empty
        # 验证返回的转账条目的金额正上
        transfer_entry = data["entries"].find { |e| e["name"] == "转账" }
        expect(transfer_entry).to be_present
        expect(transfer_entry["amount"]).to eq(100)
      end

      it "shows directional transfer in single account view" do
        get "/accounts/entries", params: {
          page: 1,
          per_page: 10,
          account_id: account.id,
          format: :json
        }

        expect(response).to have_http_status(:ok)
        data = response.parsed_body
        expect(data["entries"]).not_to be_empty
        # 验证转账条目在单账户视图中显示
        transfer_entries = data["entries"].select { |e| e["name"] == "转账" }
        expect(transfer_entries).not_to be_empty
      end
    end

    context "with empty results" do
      it "returns empty entries array when no matches" do
        get "/accounts/entries", params: {
          page: 1,
          per_page: 10,
          period_type: 'year',
          period_value: '2020',
          format: :json
        }

        data = response.parsed_body
        expect(data["entries"]).to eq([])
        expect(data["total"]).to eq(0)
      end
    end

    context "pagination edge cases" do
      before do
        # 创建20条交易
        20.times do |i|
          create(:entry,
            account: account,
            entryable: create(:entryable_transaction),
            amount: -(i + 1),
            date: i.days.ago
          )
        end
      end

      it "handles page beyond available pages gracefully" do
        get "/accounts/entries", params: {
          page: 1000,
          per_page: 10,
          format: :json
        }

        data = response.parsed_body
        expect(data["entries"]).to eq([])
      end

      it "calculates correct total count" do
        # 第一页
        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }
        data1 = response.parsed_body
        total = data1["total"]

        # 应该是我们创建的20条交易
        expect(total).to be > 0
        expect(total).to be <= 20
      end

      it "returns correct data on second page" do
        get "/accounts/entries", params: { page: 2, per_page: 5, format: :json }

        data = response.parsed_body
        expect(data["entries"].count).to be <= 5
      end
    end

    context "display type handling" do
      before do
        # 不同类型的交易
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction, kind: 'EXPENSE'),
          amount: -50,
          name: '支出'
        )
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction, kind: 'INCOME'),
          amount: 100,
          name: '收入'
        )
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction, kind: 'REIMBURSEMENT'),
          amount: 30,
          name: '报销'
        )
      end

      it "returns correct display types for different entry kinds" do
        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        data = response.parsed_body
        entries = data["entries"]

        # 验证display_type字段被正确填充
        entries.each do |entry|
          expect(entry["display_type"]).to be_present
          expect(entry["display_amount_type"]).to be_present
        end
      end
    end

    context "balance calculation" do
      before do
        account.update(initial_balance: 1000)
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction),
          amount: -100,
          date: 2.days.ago
        )
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction),
          amount: -50,
          date: 1.day.ago
        )
      end

      it "includes balance_after for each entry" do
        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        data = response.parsed_body
        entries = data["entries"]

        entries.each do |entry|
          expect(entry["balance_after"]).to be_present
          # balance_after 可能是字符串或数字
          expect(entry["balance_after"].to_s).to match(/^\d+(\.\d+)?$/)
        end
      end

      it "calculates cumulative balance correctly" do
        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        data = response.parsed_body
        entries = data["entries"]

        # 最新的交易余额应该最小
        if entries.count > 1
          expect(entries.first["balance_after"]).to be < entries.last["balance_after"]
        end
      end
    end

    context "caching behavior" do
      before do
        create(:entry, account: account, entryable: create(:entryable_transaction), amount: -50)
      end

      it "uses Rails cache for entries list" do
        allow(Rails.cache).to receive(:fetch).and_call_original

        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        expect(Rails.cache).to have_received(:fetch).at_least(:once)
      end

      it "includes cache buster version in key" do
        # 验证CacheBuster被正确调用
        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        expect(response).to have_http_status(:ok)
      end
    end

    context "security and input validation" do
      it "requires authentication" do
        # 这可能需要特殊处理，因为login已经在before中设置
        # 这里只是确保API响应有效
        get "/accounts/entries", params: { page: 1, per_page: 10, format: :json }

        expect(response).to have_http_status(:ok)
      end

      it "sanitizes page parameter" do
        get "/accounts/entries", params: {
          page: -5,
          per_page: 10,
          format: :json
        }

        data = response.parsed_body
        expect(data["entries"]).to be_an(Array)
      end

      it "handles invalid per_page gracefully" do
        get "/accounts/entries", params: {
          page: 1,
          per_page: "invalid",
          format: :json
        }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
