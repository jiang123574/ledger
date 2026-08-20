# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Versions", type: :request do
  # 快速创建测试日志（跳过验证，因为 belongs_to polymorphic 在测试环境中 item 可能不存在）
  def create_log(attrs = {})
    defaults = { item_type: "Entry", item_id: 1, action: "create", description: "测试日志" }
    log = OperationLog.new(defaults.merge(attrs))
    log.save!(validate: false)
    log
  end

  before do
    login
  end

  describe "GET /versions" do
    it "returns success" do
      get versions_path
      expect(response).to have_http_status(:success)
    end

    it "displays operation logs in the page" do
      log = create_log(
        item_type: "Entry",
        item_id: 1,
        action: "create",
        description: "创建交易测试",
        created_at: Time.current
      )

      get versions_path

      expect(response.body).to include("创建交易测试")
      expect(response.body).to include("交易") # 中文化显示
      expect(response.body).to include("创建")
    end

    it "shows stats cards" do
      3.times do |i|
        create_log(
          item_type: "Entry",
          item_id: i + 1,
          action: "create",
          description: "测试创建 #{i}",
          created_at: Time.current
        )
      end

      get versions_path

      expect(response.body).to include("今日操作")
      expect(response.body).to include("今日创建")
      expect(response.body).to include("今日更新")
      expect(response.body).to include("今日删除")
    end

    context "filtering by item_type" do
      it "filters by model type" do
        entry_log = create_log(item_type: "Entry", item_id: 1, action: "create", description: "交易日志")
        budget_log = create_log(item_type: "Budget", item_id: 1, action: "create", description: "预算日志")

        get versions_path, params: { item_type: "Entry" }

        expect(response.body).to include("交易日志")
        expect(response.body).not_to include("预算日志")
      end
    end

    context "filtering by action_type" do
      it "filters by action type" do
        create_log = create_log(item_type: "Entry", item_id: 1, action: "create", description: "创建交易")
        update_log = create_log(item_type: "Entry", item_id: 1, action: "update", description: "更新交易")

        get versions_path, params: { action_type: "create" }

        expect(response.body).to include("创建交易")
        expect(response.body).not_to include("更新交易")
      end
    end

    context "filtering by IP address" do
      it "filters by ip_address" do
        log1 = create_log(item_type: "Entry", item_id: 1, action: "create", description: "IP1 日志", ip_address: "192.168.1.1")
        log2 = create_log(item_type: "Entry", item_id: 2, action: "create", description: "IP2 日志", ip_address: "10.0.0.1")

        get versions_path, params: { ip_address: "192.168.1.1" }

        expect(response.body).to include("IP1 日志")
        expect(response.body).not_to include("IP2 日志")
      end
    end

    context "filtering by date range" do
      before do
        @old_log = create_log(
          item_type: "Entry", item_id: 1, action: "create",
          description: "旧日志", created_at: 7.days.ago
        )
        @new_log = create_log(
          item_type: "Entry", item_id: 2, action: "create",
          description: "新日志", created_at: 1.day.ago
        )
      end

      it "filters by date_from" do
        get versions_path, params: { date_from: 2.days.ago.to_date.to_s }
        expect(response.body).to include("新日志")
        expect(response.body).not_to include("旧日志")
      end

      it "filters by date_to" do
        get versions_path, params: { date_to: 2.days.ago.to_date.to_s }
        expect(response.body).to include("旧日志")
        expect(response.body).not_to include("新日志")
      end

      it "filters by both date_from and date_to" do
        get versions_path, params: { date_from: 3.days.ago.to_date.to_s, date_to: 1.day.ago.to_date.to_s }
        expect(response.body).to include("新日志")
        expect(response.body).not_to include("旧日志")
      end

      it "returns 200 with invalid date_from (no 500)" do
        get versions_path, params: { date_from: "abc" }
        expect(response).to have_http_status(:success)
      end

      it "returns 200 with impossible date (no 500)" do
        get versions_path, params: { date_from: "2026-02-31" }
        expect(response).to have_http_status(:success)
      end

      it "returns 200 with invalid date_to (no 500)" do
        get versions_path, params: { date_to: "not-a-date" }
        expect(response).to have_http_status(:success)
      end
    end

    context "search" do
      it "searches by description" do
        log1 = create_log(item_type: "Entry", item_id: 1, action: "create", description: "早餐支出")
        log2 = create_log(item_type: "Entry", item_id: 2, action: "create", description: "工资收入")

        get versions_path, params: { search: "早餐" }

        expect(response.body).to include("早餐支出")
        expect(response.body).not_to include("工资收入")
      end
    end

    context "CSV export" do
      before do
        3.times do |i|
          create_log(
            item_type: "Entry",
            item_id: i + 1,
            action: "create",
            description: "CSV 测试 #{i}",
            ip_address: "127.0.0.1",
            created_at: Time.current
          )
        end
      end

      it "returns CSV format" do
        get versions_path, params: { format: "csv" }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("text/csv")
        expect(response.headers["Content-Disposition"]).to include("operation_logs_")
      end

      it "includes all filtered results (no pagination limit)" do
        get versions_path, params: { format: "csv" }
        csv = CSV.parse(response.body)
        # 1 header row + 3 data rows
        expect(csv.length).to eq(4)
        expect(csv[0]).to include("时间", "操作", "模型类型")
        expect(csv[1]).to include("创建")
        expect(csv[1]).to include("交易")
      end

      it "respects filters in CSV export" do
        get versions_path, params: { format: "csv", action_type: "update" }
        csv = CSV.parse(response.body)
        # only header, no data rows (all are create)
        expect(csv.length).to eq(1)
      end

      it "exports in same order as page (created_at desc)" do
        # 用独有的关键词避免与其他日志混淆
        create_log(item_type: "Budget", item_id: 10, action: "create", description: "排序测试_最早", created_at: 3.days.ago)
        create_log(item_type: "Budget", item_id: 11, action: "create", description: "排序测试_中间", created_at: 2.days.ago)
        create_log(item_type: "Budget", item_id: 12, action: "create", description: "排序测试_最晚", created_at: 1.day.ago)

        get versions_path, params: { format: "csv", item_type: "Budget" }
        csv = CSV.parse(response.body)
        # 跳过 header，顺序应该是：最晚 → 中间 → 最早（desc）
        expect(csv[1]).to include("排序测试_最晚")
        expect(csv[2]).to include("排序测试_中间")
        expect(csv[3]).to include("排序测试_最早")
      end
    end

    context "JSON export" do
      before do
        3.times do |i|
          create_log(
            item_type: "Entry",
            item_id: i + 1,
            action: "create",
            description: "JSON 测试 #{i}",
            created_at: Time.current
          )
        end
      end

      it "returns JSON format" do
        get versions_path, params: { format: "json" }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("application/json")
      end

      it "includes all results (no silent limit)" do
        get versions_path, params: { format: "json" }
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
        expect(json.first["action"]).to eq("create")
        expect(json.first["action_label"]).to eq("创建")
        expect(json.first["item_type_label"]).to eq("交易")
      end

      it "respects filters in JSON export" do
        get versions_path, params: { format: "json", item_type: "Budget" }
        json = JSON.parse(response.body)
        expect(json.length).to eq(0)
      end
    end

    context "quick presets" do
      it "renders quick filter chips" do
        get versions_path
        expect(response.body).to include("今天")
        expect(response.body).to include("昨天")
        expect(response.body).to include("近7天")
        expect(response.body).to include("近30天")
        expect(response.body).to include("删除操作")
        expect(response.body).to include("交易相关")
      end
    end
  end

  describe "GET /versions/:id" do
    it "returns success" do
      log = create_log(
        item_type: "Entry",
        item_id: 1,
        action: "create",
        description: "测试详情",
        ip_address: "127.0.0.1"
      )

      get version_path(log)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("测试详情")
    end

    context "update action with diff" do
      it "shows diff view and toggle button" do
        log = create_log(
          item_type: "Entry",
          item_id: 1,
          action: "update",
          description: "更新交易",
          changeset: { "amount" => [ 100, 200 ], "name" => [ "旧名", "新名" ] }.to_json
        )

        get version_path(log)
        expect(response.body).to include("Diff 视图")
        expect(response.body).to include("查看原始 JSON")
        expect(response.body).to include("100")
        expect(response.body).to include("200")
      end

      it "correctly displays false and 0 values (not as empty)" do
        log = create_log(
          item_type: "Entry",
          item_id: 1,
          action: "update",
          description: "布尔和零值测试",
          changeset: { "is_refund" => [ false, true ], "count" => [ 0, 5 ] }.to_json
        )

        get version_path(log)
        expect(response.body).not_to include("(空)")
        expect(response.body).to include("false")
        expect(response.body).to include("true")
        expect(response.body).to include("0")
        expect(response.body).to include("5")
      end
    end

    context "create action (no diff)" do
      it "does not show diff toggle button for create" do
        log = create_log(
          item_type: "Entry",
          item_id: 1,
          action: "create",
          description: "创建交易",
          changeset: { "amount" => 100, "name" => "测试" }.to_json
        )

        get version_path(log)
        expect(response.body).not_to include("查看原始 JSON")
        expect(response.body).not_to include("查看 Diff 视图")
      end
    end

    context "destroy action (no diff)" do
      it "does not show diff toggle button for destroy" do
        log = create_log(
          item_type: "Entry",
          item_id: 1,
          action: "destroy",
          description: "删除交易",
          changeset: { "amount" => 100 }.to_json
        )

        get version_path(log)
        expect(response.body).not_to include("查看原始 JSON")
      end
    end
  end
end
