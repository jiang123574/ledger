# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::ButtonComponent, type: :component do
  describe "basic rendering" do
    it "renders a button with text" do
      render_inline(described_class.new) { "Click Me" }
      expect(page).to have_text("Click Me")
      expect(page).to have_css("button")
    end

    it "renders button with correct type attribute" do
      render_inline(described_class.new(type: :submit)) { "Submit" }
      expect(page).to have_css("button[type='submit']")
    end
  end

  describe "variants" do
    variants = %i[primary secondary destructive inverse outline ghost link]

    variants.each do |variant|
      it "renders #{variant} variant" do
        render_inline(described_class.new(variant: variant)) { variant.to_s.capitalize }
        expect(page).to have_text(variant.to_s.capitalize)
        expect(page).to have_css("button")
      end
    end

    it "applies primary variant styles" do
      render_inline(described_class.new(variant: :primary)) { "Primary" }
      expect(page).to have_css("button.bg-inverse")
    end

    it "applies secondary variant styles" do
      render_inline(described_class.new(variant: :secondary)) { "Secondary" }
      expect(page).to have_css("button.border")
    end

    it "applies destructive variant styles" do
      render_inline(described_class.new(variant: :destructive)) { "Delete" }
      expect(page).to have_css("button.bg-red-100")
    end
  end

  describe "sizes" do
    sizes = %i[xs sm md lg]

    sizes.each do |size|
      it "renders #{size} size" do
        render_inline(described_class.new(size: size)) { size.to_s.upcase }
        expect(page).to have_text(size.to_s.upcase)
      end
    end

    it "applies xs size classes" do
      render_inline(described_class.new(size: :xs)) { "XS" }
      expect(page).to have_css("button.px-2")
    end

    it "applies lg size classes" do
      render_inline(described_class.new(size: :lg)) { "LG" }
      expect(page).to have_css("button.px-5")
    end
  end

  describe "as link" do
    it "renders as a link when href provided" do
      render_inline(described_class.new(href: "/test")) { "Link" }
      expect(page).to have_css("a")
      expect(page).not_to have_css("button")
    end

    it "renders as button when href provided but disabled" do
      render_inline(described_class.new(href: "/test", disabled: true)) { "Disabled Link" }
      expect(page).to have_css("button")
      expect(page).not_to have_css("a")
    end

    it "link has correct href" do
      render_inline(described_class.new(href: "/path/to/page")) { "Navigate" }
      expect(page).to have_css("a[href='/path/to/page']")
    end
  end

  describe "disabled state" do
    it "renders disabled button" do
      render_inline(described_class.new(disabled: true)) { "Disabled" }
      expect(page).to have_css("button[disabled]")
    end

    it "has disabled attribute" do
      render_inline(described_class.new(disabled: true)) { "Disabled" }
      expect(page).to have_css("button[disabled]")
    end

    it "has disabled styles in class list" do
      render_inline(described_class.new(disabled: true)) { "Disabled" }
      expect(page).to have_css("button")
      # Tailwind disabled: pseudo-class modifier is in the class string
      expect(page.find("button")["class"]).to include("disabled:opacity-50")
    end
  end

  describe "loading state" do
    it "renders loading spinner" do
      render_inline(described_class.new(loading: true)) { "Loading" }
      expect(page).to have_css(".btn-spinner")
    end

    it "disables button when loading" do
      render_inline(described_class.new(loading: true)) { "Loading" }
      expect(page).to have_css("button[disabled]")
    end

    it "renders spinner alongside content when loading" do
      render_inline(described_class.new(loading: true)) { "Loading Text" }
      expect(page).to have_css(".btn-spinner")
      expect(page).to have_text("Loading Text")
    end
  end

  describe "icon support" do
    it "renders with icon on left" do
      render_inline(described_class.new(icon: "plus")) { "Add" }
      expect(page).to have_text("Add")
    end

    it "renders with icon on right" do
      render_inline(described_class.new(icon: "arrow-right", icon_position: :right)) { "Next" }
      expect(page).to have_text("Next")
    end

    it "renders icon only without content" do
      render_inline(described_class.new(icon: "check"))
      expect(page).to have_css("svg")
    end

    it "adjusts icon size based on button size" do
      render_inline(described_class.new(icon: "plus", size: :xs))
      expect(page).to have_css("svg")

      render_inline(described_class.new(icon: "plus", size: :lg))
      expect(page).to have_css("svg")
    end
  end

  describe "combinations" do
    it "renders large primary button with icon" do
      render_inline(described_class.new(variant: :primary, size: :lg, icon: "check")) { "Confirm" }
      expect(page).to have_text("Confirm")
      expect(page).to have_css("button.bg-inverse")
      expect(page).to have_css("button.px-5")
      expect(page).to have_css("svg")
    end

    it "renders small destructive button with loading" do
      render_inline(described_class.new(variant: :destructive, size: :sm, loading: true)) { "Deleting" }
      expect(page).to have_css(".btn-spinner")
      expect(page).to have_css("button[disabled]")
    end

    it "renders ghost link with icon" do
      render_inline(described_class.new(href: "/test", variant: :ghost, icon: "external-link")) { "Open" }
      expect(page).to have_css("a")
      expect(page).to have_text("Open")
    end

    it "renders outline button with icon on right" do
      render_inline(described_class.new(variant: :outline, icon: "arrow-right", icon_position: :right)) { "Continue" }
      expect(page).to have_text("Continue")
      expect(page).to have_css("svg")
    end
  end

  describe "custom options" do
    it "accepts custom class" do
      render_inline(described_class.new(class: "custom-class")) { "Custom" }
      expect(page).to have_css("button.custom-class")
    end

    it "accepts custom data attributes" do
      render_inline(described_class.new(data: { controller: "test" })) { "Data" }
      expect(page).to have_css("button[data-controller='test']")
    end
  end

  describe "accessibility" do
    it "has focus ring styles in class list" do
      render_inline(described_class.new) { "Focus" }
      # Tailwind focus: pseudo-class modifier is in the class string
      expect(page.find("button")["class"]).to include("focus:ring-2")
    end

    it "disabled button has cursor-not-allowed" do
      render_inline(described_class.new(disabled: true)) { "Disabled" }
      expect(page).to have_css("button")
      expect(page.find("button")["class"]).to include("disabled:cursor-not-allowed")
    end
  end
end
