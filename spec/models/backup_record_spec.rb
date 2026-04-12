# frozen_string_literal: true

require "rails_helper"

RSpec.describe BackupRecord, type: :model do
  describe "validations" do
    it { should validate_presence_of(:filename) }
    it { should validate_presence_of(:file_path) }
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by created_at descending" do
        old_record = create(:backup_record, created_at: 2.days.ago)
        new_record = create(:backup_record, created_at: Time.current)

        expect(BackupRecord.recent.first).to eq(new_record)
      end
    end

    describe ".completed" do
      it "returns only completed records" do
        completed = create(:backup_record, status: "completed")
        pending = create(:backup_record, status: "pending")

        expect(BackupRecord.completed).to include(completed)
        expect(BackupRecord.completed).not_to include(pending)
      end
    end
  end

  describe "#human_size" do
    it "returns 0 for nil file_size" do
      record = BackupRecord.new(file_size: nil)
      expect(record.human_size).to eq(0)
    end

    it "returns 0 for zero file_size" do
      record = BackupRecord.new(file_size: 0)
      expect(record.human_size).to eq(0)
    end

    it "formats bytes" do
      record = BackupRecord.new(file_size: 500)
      expect(record.human_size).to eq("500 B")
    end

    it "formats kilobytes" do
      record = BackupRecord.new(file_size: 2048)
      expect(record.human_size).to eq("2.0 KB")
    end

    it "formats megabytes" do
      record = BackupRecord.new(file_size: 1048576)
      expect(record.human_size).to eq("1.0 MB")
    end
  end
end
