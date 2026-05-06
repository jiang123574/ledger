# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::CardComponent, type: :component do
  describe "basic rendering" do
    it "renders a div container" do
      render_inline(described_class.new) { "Content" }
      expect(page).to have_css("div.bg-container")
      expect(page).to have_text("Content")
    end

    it "has default padding" do
      render_inline(described_class.new) { "Content" }
      expect(page).to have_css("div.p-4")
    end

    it "renders without padding when disabled" do
      render_inline(described_class.new(padding: false)) { "Content" }
      expect(page).not_to have_css("div.p-4")
    end
  end

  describe "rounded variants" do
    rounded_sizes = %i[sm md lg xl none]

    rounded_sizes.each do |size|
      it "renders #{size} rounded" do
        render_inline(described_class.new(rounded: size)) { "Card" }
        expect(page).to have_css("div")
      end
    end

    it "applies sm rounded class" do
      render_inline(described_class.new(rounded: :sm)) { "Card" }
      expect(page).to have_css("div.rounded-sm")
    end

    it "applies md rounded class" do
      render_inline(described_class.new(rounded: :md)) { "Card" }
      expect(page).to have_css("div.rounded")
    end

    it "applies lg rounded class (default)" do
      render_inline(described_class.new(rounded: :lg)) { "Card" }
      expect(page).to have_css("div.rounded-lg")
    end

    it "applies xl rounded class" do
      render_inline(described_class.new(rounded: :xl)) { "Card" }
      expect(page).to have_css("div.rounded-xl")
    end

    it "applies no rounded class when none" do
      render_inline(described_class.new(rounded: :none)) { "Card" }
      expect(page).not_to have_css("div.rounded")
    end

    it "defaults to lg rounded for unknown value" do
      render_inline(described_class.new(rounded: :unknown)) { "Card" }
      expect(page).to have_css("div.rounded-lg")
    end
  end

  describe "shadow variants" do
    shadow_sizes = %i[none border_xs border_sm border_md border_lg]

    shadow_sizes.each do |shadow|
      it "renders #{shadow} shadow" do
        render_inline(described_class.new(shadow: shadow)) { "Card" }
        expect(page).to have_css("div")
      end
    end

    it "applies border_xs shadow class (default)" do
      render_inline(described_class.new(shadow: :border_xs)) { "Card" }
      expect(page).to have_css("div.shadow-border-xs")
    end

    it "applies border_sm shadow class" do
      render_inline(described_class.new(shadow: :border_sm)) { "Card" }
      expect(page).to have_css("div.shadow-border-sm")
    end

    it "applies border_md shadow class" do
      render_inline(described_class.new(shadow: :border_md)) { "Card" }
      expect(page).to have_css("div.shadow-border-md")
    end

    it "applies border_lg shadow class" do
      render_inline(described_class.new(shadow: :border_lg)) { "Card" }
      expect(page).to have_css("div.shadow-border-lg")
    end

    it "applies no shadow when none" do
      render_inline(described_class.new(shadow: :none)) { "Card" }
      expect(page).not_to have_css("div.shadow-border")
    end

    it "defaults to border_xs shadow for unknown value" do
      render_inline(described_class.new(shadow: :unknown)) { "Card" }
      expect(page).to have_css("div.shadow-border-xs")
    end
  end

  describe "custom options" do
    it "accepts custom class" do
      render_inline(described_class.new(class: "custom-card")) { "Custom" }
      expect(page).to have_css("div.custom-card")
    end

    it "merges custom class with base classes" do
      render_inline(described_class.new(class: "custom-card")) { "Custom" }
      expect(page).to have_css("div.bg-container.custom-card")
    end
  end

  describe "combinations" do
    it "renders card with all options" do
      render_inline(described_class.new(rounded: :xl, shadow: :border_lg, padding: true)) { "Full Card" }
      expect(page).to have_css("div.bg-container.rounded-xl.shadow-border-lg.p-4")
    end

    it "renders minimal card" do
      render_inline(described_class.new(rounded: :none, shadow: :none, padding: false)) { "Minimal" }
      expect(page).to have_css("div.bg-container")
      expect(page).not_to have_css("div.rounded")
      expect(page).not_to have_css("div.shadow-border")
      expect(page).not_to have_css("div.p-4")
    end
  end

  describe "constants" do
    it "has ROUNDED_CLASSES constant" do
      expect(Ds::CardComponent::ROUNDED_CLASSES).to be_a(Hash)
      expect(Ds::CardComponent::ROUNDED_CLASSES.keys).to contain_exactly(:sm, :md, :lg, :xl, :none)
    end

    it "has SHADOW_CLASSES constant" do
      expect(Ds::CardComponent::SHADOW_CLASSES).to be_a(Hash)
      expect(Ds::CardComponent::SHADOW_CLASSES.keys).to contain_exactly(:none, :border_xs, :border_sm, :border_md, :border_lg)
    end

    it "constants are frozen" do
      expect(Ds::CardComponent::ROUNDED_CLASSES).to be_frozen
      expect(Ds::CardComponent::SHADOW_CLASSES).to be_frozen
    end
  end
end
