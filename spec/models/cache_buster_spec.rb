# frozen_string_literal: true

require "rails_helper"

RSpec.describe CacheBuster, type: :model do
  before { Rails.cache.clear }

  describe ".version" do
    it "returns 0 when no version has been set" do
      expect(CacheBuster.version(:entries)).to eq(0)
    end
  end

  describe ".bump" do
    it "increments version from 0 to 1" do
      expect { CacheBuster.bump(:entries) }.to change { CacheBuster.version(:entries) }.from(0).to(1)
    end

    it "increments version on successive bumps" do
      CacheBuster.bump(:entries)
      CacheBuster.bump(:entries)
      expect(CacheBuster.version(:entries)).to eq(2)
    end

    it "returns the new version" do
      expect(CacheBuster.bump(:accounts)).to eq(1)
      expect(CacheBuster.bump(:accounts)).to eq(2)
    end
  end

  describe ".bump_all" do
    it "bumps multiple scopes" do
      CacheBuster.bump_all(:entries, :accounts)

      expect(CacheBuster.version(:entries)).to eq(1)
      expect(CacheBuster.version(:accounts)).to eq(1)
    end

    it "works with repeated calls" do
      CacheBuster.bump_all(:entries, :accounts)
      CacheBuster.bump_all(:entries, :accounts)

      expect(CacheBuster.version(:entries)).to eq(2)
      expect(CacheBuster.version(:accounts)).to eq(2)
    end
  end

  describe "scope isolation" do
    it "keeps different scopes independent" do
      CacheBuster.bump(:entries)
      CacheBuster.bump(:entries)
      CacheBuster.bump(:accounts)

      expect(CacheBuster.version(:entries)).to eq(2)
      expect(CacheBuster.version(:accounts)).to eq(1)
    end
  end
end
