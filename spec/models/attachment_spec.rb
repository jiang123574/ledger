# frozen_string_literal: true

require "rails_helper"

RSpec.describe Attachment, type: :model do
  describe "validations" do
    subject { Attachment.new(file_path: "/test/file.jpg", file_name: "file.jpg", file_type: "image/jpeg", entry: create(:entry)) }

    it { should validate_presence_of(:file_path) }
    it { should validate_presence_of(:file_name) }
    it { should validate_presence_of(:file_type) }
  end

  describe "associations" do
    it { should belong_to(:entry).optional }
  end

  describe "custom validations" do
    it "is invalid without an entry" do
      attachment = Attachment.new(file_path: "/test.jpg", file_name: "test.jpg", file_type: "image/jpeg", entry: nil)
      expect(attachment).not_to be_valid
      expect(attachment.errors[:base]).to include("必须关联到 Entry")
    end

    it "is valid with an entry" do
      attachment = Attachment.new(file_path: "/test.jpg", file_name: "test.jpg", file_type: "image/jpeg", entry: create(:entry))
      attachment.valid? # trigger validations
      expect(attachment.errors[:base]).to be_empty
    end
  end

  describe "#image?" do
    it "returns true for image types" do
      attachment = Attachment.new(file_type: "image/jpeg")
      expect(attachment.image?).to be true
    end

    it "returns true for png" do
      attachment = Attachment.new(file_type: "image/png")
      expect(attachment.image?).to be true
    end

    it "returns false for non-image types" do
      attachment = Attachment.new(file_type: "application/pdf")
      expect(attachment.image?).to be false
    end

    it "returns false for nil file_type" do
      attachment = Attachment.new(file_type: nil)
      expect(attachment.image?).to be false
    end
  end

  describe "#human_size" do
    it "returns 0 for nil file_size" do
      attachment = Attachment.new(file_size: nil)
      expect(attachment.human_size).to eq(0)
    end

    it "returns 0 for zero file_size" do
      attachment = Attachment.new(file_size: 0)
      expect(attachment.human_size).to eq(0)
    end

    it "formats bytes" do
      attachment = Attachment.new(file_size: 500)
      expect(attachment.human_size).to eq("500 B")
    end

    it "formats kilobytes" do
      attachment = Attachment.new(file_size: 2048)
      expect(attachment.human_size).to eq("2.0 KB")
    end

    it "formats megabytes" do
      attachment = Attachment.new(file_size: 1048576)
      expect(attachment.human_size).to eq("1.0 MB")
    end
  end
end
