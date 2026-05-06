# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::DialogComponent, type: :component do
  describe "basic rendering" do
    it "renders dialog wrapper" do
      render_inline(described_class.new)
      expect(page).to have_css("div.fixed.inset-0.z-50")
    end

    it "renders dialog content container" do
      render_inline(described_class.new)
      expect(page).to have_css("div.bg-container.rounded-xl")
    end

    it "has dialog controller" do
      render_inline(described_class.new)
      expect(page).to have_css("[data-controller='dialog']")
    end
  end

  describe "title and subtitle" do
    it "renders title" do
      render_inline(described_class.new(title: "Dialog Title"))
      expect(page).to have_css("h3", text: "Dialog Title")
      expect(page).to have_css("h3.text-lg.font-semibold")
    end

    it "renders subtitle" do
      render_inline(described_class.new(title: "Title", subtitle: "Subtitle text"))
      expect(page).to have_css("p.text-sm.text-secondary", text: "Subtitle text")
    end

    it "renders without title" do
      render_inline(described_class.new) { "Content" }
      expect(page).not_to have_css("h3")
      expect(page).to have_text("Content")
    end
  end

  describe "size variants" do
    sizes = %i[modal wide full]

    sizes.each do |size|
      it "renders #{size} size" do
        render_inline(described_class.new(size: size))
        expect(page).to have_css("div")
      end
    end

    it "applies modal size class (default)" do
      render_inline(described_class.new(size: :modal))
      expect(page).to have_css("div.max-w-md")
    end

    it "applies wide size class" do
      render_inline(described_class.new(size: :wide))
      expect(page).to have_css("div.max-w-2xl")
    end

    it "applies full size class" do
      render_inline(described_class.new(size: :full))
      expect(page).to have_css("div.max-w-4xl")
    end

    it "defaults to modal for unknown size" do
      render_inline(described_class.new(size: :unknown))
      expect(page).to have_css("div.max-w-md")
    end
  end

  describe "content block" do
    it "renders content block as body" do
      render_inline(described_class.new) { "Dialog Content" }
      expect(page).to have_text("Dialog Content")
    end
  end

  describe "combinations" do
    it "renders full dialog with all features" do
      component = described_class.new(title: "Full Dialog", subtitle: "Subtitle", size: :wide)
      render_inline(component) { "Body content" }
      expect(page).to have_css("h3", text: "Full Dialog")
      expect(page).to have_css("p.text-sm", text: "Subtitle")
      expect(page).to have_css("div.max-w-2xl")
      expect(page).to have_text("Body content")
    end
  end

  describe "constants" do
    it "has VARIANTS constant" do
      expect(Ds::DialogComponent::VARIANTS).to be_a(Hash)
      expect(Ds::DialogComponent::VARIANTS.keys).to contain_exactly(:modal, :wide, :full)
    end

    it "VARIANTS constant is frozen" do
      expect(Ds::DialogComponent::VARIANTS).to be_frozen
    end
  end
end
