# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityLog, type: :model do
  let(:account) { create(:account) }
  let(:entry) { create(:entry, :expense, account: account) }

  describe "associations" do
    it { is_expected.to belong_to(:item) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:action) }
    it { is_expected.to validate_inclusion_of(:action).in_array(%w[create update destroy]) }
    it { is_expected.to validate_presence_of(:item_type) }
    it { is_expected.to validate_presence_of(:item_id) }
  end

  describe "scopes" do
    let!(:log1) { ActivityLog.create!(item: entry, action: "create", item_type: "Entry", item_id: entry.id) }
    let!(:log2) { ActivityLog.create!(item: entry, action: "update", item_type: "Entry", item_id: entry.id) }

    describe ".recent" do
      it "orders by created_at descending" do
        expect(ActivityLog.recent.first).to eq(log2)
      end
    end

    describe ".for_item" do
      it "returns logs for specific item" do
        expect(ActivityLog.for_item(entry)).to include(log1, log2)
      end
    end

    describe ".by_action" do
      it "filters by action type" do
        expect(ActivityLog.by_action("create")).to include(log1)
        expect(ActivityLog.by_action("create")).not_to include(log2)
      end
    end
  end

  describe "#changes_summary" do
    it "returns formatted changes" do
      log = ActivityLog.create!(
        item: entry,
        action: "update",
        item_type: "Entry",
        item_id: entry.id,
        changeset: { "name" => ["Old Name", "New Name"] }.to_json
      )

      expect(log.changes_summary).to eq("name: Old Name → New Name")
    end

    it "returns nil when changeset is blank" do
      log = ActivityLog.create!(
        item: entry,
        action: "create",
        item_type: "Entry",
        item_id: entry.id,
        changeset: nil
      )

      expect(log.changes_summary).to be_nil
    end

    it "excludes updated_at and created_at from summary" do
      log = ActivityLog.create!(
        item: entry,
        action: "update",
        item_type: "Entry",
        item_id: entry.id,
        changeset: {
          "name" => ["Old", "New"],
          "updated_at" => ["2024-01-01", "2024-01-02"]
        }.to_json
      )

      expect(log.changes_summary).not_to include("updated_at")
    end
  end

  describe "#revert!" do
    context "for create action" do
      let(:log) { ActivityLog.create!(item: entry, action: "create", item_type: "Entry", item_id: entry.id) }

      it "returns false" do
        expect(log.revert!).to be false
      end
    end

    context "for update action" do
      it "reverts the changes" do
        original_name = entry.name
        entry.update!(name: "Changed Name")

        log = ActivityLog.last
        log.revert!

        expect(entry.reload.name).to eq(original_name)
      end

      it "returns false when changeset is blank" do
        log = ActivityLog.create!(
          item: entry,
          action: "update",
          item_type: "Entry",
          item_id: entry.id,
          changeset: nil
        )

        expect(log.revert!).to be false
      end
    end
  end

  describe ".log_create" do
    it "creates a create activity log" do
      # Entry 有 after_create 回调会自动创建 ActivityLog
      # 所以这里直接检查 log 是否存在
      log = ActivityLog.where(item: entry, action: "create").first
      expect(log).to be_present
      expect(log.action).to eq("create")
      expect(log.item).to eq(entry)
    end

    it "filters sensitive fields" do
      allow(entry).to receive(:attributes).and_return({
        "id" => 1,
        "name" => "Test",
        "password" => "secret"
      })

      ActivityLog.log_create(entry)
      log = ActivityLog.last

      expect(log.changeset).not_to include("password")
    end
  end

  describe ".log_update" do
    it "creates log when changes exist" do
      entry.update!(name: "New Name")
      # Entry 有 after_update 回调会自动创建 ActivityLog
      log = ActivityLog.where(item: entry, action: "update").last
      expect(log).to be_present
      expect(log.action).to eq("update")
    end
  end

  describe ".log_destroy" do
    it "creates a destroy activity log" do
      entry_id = entry.id

      expect {
        ActivityLog.log_destroy(entry)
      }.to change(ActivityLog, :count).by(1)

      log = ActivityLog.last
      expect(log.action).to eq("destroy")
      expect(log.item_id).to eq(entry_id)
    end
  end
end
