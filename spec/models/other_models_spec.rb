# frozen_string_literal: true

require "rails_helper"

RSpec.describe Attachment, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:entry).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:file_path) }
    it { is_expected.to validate_presence_of(:file_name) }
    it { is_expected.to validate_presence_of(:file_type) }
  end

  describe "#image?" do
    it "returns true for image content types" do
      attachment = Attachment.new(file_type: "image/jpeg")
      expect(attachment.image?).to be true
    end

    it "returns false for non-image content types" do
      attachment = Attachment.new(file_type: "application/pdf")
      expect(attachment.image?).to be false
    end

    it "returns false when file_type is nil" do
      attachment = Attachment.new(file_type: nil)
      expect(attachment.image?).to be false
    end
  end

  describe "#human_size" do
    it "returns bytes for small files" do
      attachment = Attachment.new(file_size: 500)
      expect(attachment.human_size).to eq("500 B")
    end

    it "returns KB for medium files" do
      attachment = Attachment.new(file_size: 2048)
      expect(attachment.human_size).to eq("2.0 KB")
    end

    it "returns MB for large files" do
      attachment = Attachment.new(file_size: 2 * 1024 * 1024)
      expect(attachment.human_size).to eq("2.0 MB")
    end

    it "returns 0 when file_size is nil" do
      attachment = Attachment.new(file_size: nil)
      expect(attachment.human_size).to eq(0)
    end

    it "returns 0 when file_size is 0" do
      attachment = Attachment.new(file_size: 0)
      expect(attachment.human_size).to eq(0)
    end
  end
end

RSpec.describe Tagging, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:tag) }
  end
end

RSpec.describe ImportBatch, type: :model do
  describe "attributes" do
    it "has source_name attribute" do
      batch = ImportBatch.new(source_name: "pixiu")
      expect(batch.source_name).to eq("pixiu")
    end
  end
end

RSpec.describe BackupRecord, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:filename) }
    it { is_expected.to validate_presence_of(:file_path) }
  end

  describe "#human_size" do
    it "returns formatted file size" do
      record = BackupRecord.new(file_size: 1024 * 1024)
      expect(record.human_size).to include("MB")
    end
  end
end
