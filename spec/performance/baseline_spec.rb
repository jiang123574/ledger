# frozen_string_literal: true

# Performance Baseline Tests
# 确保关键页面的响应时间保持在合理范围内
# 这些测试用于检测性能衰退
#
# 运行方式: bundle exec rspec spec/performance/
#
require "rails_helper"
require "benchmark"

RSpec.describe "Performance Baseline", type: :request do
  let!(:accounts) { create_list(:account, 5) }
  let!(:categories) { create_list(:category, 10, category_type: "expense") }

  before do
    # 创建一些测试数据
    accounts.each do |account|
      create_list(:entry, 20,
        account: account,
        entryable: create(:entryable_transaction, kind: "expense", category_id: categories.sample.id),
        amount: -rand(10..1000),
        date: Date.today - rand(0..30)
      )
    end

    # 模拟登录（使用 session 认证）
    allow_any_instance_of(ApplicationController).to receive(:auth_configured?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
  end

  describe "Dashboard page" do
    it "loads dashboard in under 500ms" do
      time = Benchmark.realtime do
        get dashboard_path
      end

      # 预期：首页加载时间 < 500ms（包括数据库查询和渲染）
      expect(time).to be < 0.5
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Accounts list page" do
    it "loads accounts page in under 500ms" do
      time = Benchmark.realtime do
        get accounts_path
      end

      # 预期：账户列表加载时间 < 500ms
      expect(time).to be < 0.5
      expect(response).to have_http_status(:ok)
    end

    it "loads accounts page with 100 entries in under 800ms" do
      # 创建更多数据测试性能
      account = accounts.first
      create_list(:entry, 100,
        account: account,
        entryable: create(:entryable_transaction, kind: "expense", category_id: categories.first.id),
        amount: -100,
        date: Date.today - rand(0..30)
      )

      time = Benchmark.realtime do
        get accounts_path(account_id: account.id)
      end

      # 预期：带100条记录的页面加载时间 < 800ms
      expect(time).to be < 0.8
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Reports page" do
    it "loads reports page in under 500ms" do
      time = Benchmark.realtime do
        get reports_path
      end

      # 预期：报表页面加载时间 < 500ms
      expect(time).to be < 0.5
      expect(response).to have_http_status(:ok)
    end

    it "loads reports page with specific month in under 500ms" do
      month = Date.today.strftime("%Y-%m")
      time = Benchmark.realtime do
        get report_month_path(Date.today.year, Date.today.month)
      end

      expect(time).to be < 0.5
      expect(response).to have_http_status(:ok)
    end
  end

  describe "API endpoints" do
    it "responds to entries API in under 200ms" do
      account = accounts.first

      time = Benchmark.realtime do
        get entries_accounts_path, as: :json
      end

      # 预期：API 响应时间 < 200ms
      expect(time).to be < 0.2
      expect(response).to have_http_status(:ok)
    end

    it "responds to settings page in under 300ms" do
      time = Benchmark.realtime do
        get settings_path(section: "categories")
      end

      # 预期：设置页面加载时间 < 300ms
      expect(time).to be < 0.3
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Database queries" do
    it "counts N+1 queries for account list" do
      # 使用 Bullet 检测 N+1 查询
      # 注意：需要在 test 环境配置 Bullet
      get accounts_path

      # 如果 Bullet 配置正确，这里会检测到 N+1 查询
      expect(response).to have_http_status(:ok)
    end
  end
end