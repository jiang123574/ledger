# frozen_string_literal: true

require "rails_helper"

RSpec.describe CacheBuster do
  before do
    described_class.clear!
  end

  describe ".bump" do
    it "increments version for a scope" do
      expect(described_class.bump(:entries)).to eq(1)
      expect(described_class.bump(:entries)).to eq(2)
      expect(described_class.bump(:entries)).to eq(3)
    end

    it "returns the new version" do
      new_version = described_class.bump(:accounts)
      expect(new_version).to eq(1)
    end
  end

  describe ".version" do
    it "returns 0 for new scope" do
      expect(described_class.version(:entries)).to eq(0)
    end

    it "returns current version after bumps" do
      described_class.bump(:entries)
      described_class.bump(:entries)
      expect(described_class.version(:entries)).to eq(2)
    end

    it "handles multiple scopes independently" do
      described_class.bump(:entries)
      described_class.bump(:accounts)
      described_class.bump(:entries)

      expect(described_class.version(:entries)).to eq(2)
      expect(described_class.version(:accounts)).to eq(1)
    end
  end

  describe ".bump_all" do
    it "bumps multiple scopes" do
      described_class.bump_all(:entries, :accounts, :budgets)

      expect(described_class.version(:entries)).to eq(1)
      expect(described_class.version(:accounts)).to eq(1)
      expect(described_class.version(:budgets)).to eq(1)
    end
  end

  describe ".clear!" do
    it "resets all versions" do
      described_class.bump(:entries)
      described_class.bump(:accounts)

      described_class.clear!

      expect(described_class.version(:entries)).to eq(0)
      expect(described_class.version(:accounts)).to eq(0)
    end
  end
end
