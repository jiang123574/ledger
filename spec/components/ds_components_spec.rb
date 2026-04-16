# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DS Components", type: :component do
  describe Ds::BadgeComponent do
    it "renders with default variant" do
      render_inline(Ds::BadgeComponent.new) { "Test Badge" }
      expect(page).to have_text("Test Badge")
      expect(page).to have_css("span")
    end

    it "renders with primary variant" do
      render_inline(Ds::BadgeComponent.new(variant: :primary)) { "Primary" }
      expect(page).to have_text("Primary")
    end

    it "renders with income variant" do
      render_inline(Ds::BadgeComponent.new(variant: :income)) { "Income" }
      expect(page).to have_text("Income")
    end

    it "renders with expense variant" do
      render_inline(Ds::BadgeComponent.new(variant: :expense)) { "Expense" }
      expect(page).to have_text("Expense")
    end

    it "renders with dot indicator" do
      render_inline(Ds::BadgeComponent.new(dot: true)) { "With Dot" }
      expect(page).to have_text("With Dot")
    end

    it "renders with transfer variant" do
      render_inline(Ds::BadgeComponent.new(variant: :transfer)) { "Transfer" }
      expect(page).to have_text("Transfer")
    end

    it "renders with warning variant" do
      render_inline(Ds::BadgeComponent.new(variant: :warning)) { "Warning" }
      expect(page).to have_text("Warning")
    end

    it "renders with danger variant" do
      render_inline(Ds::BadgeComponent.new(variant: :danger)) { "Danger" }
      expect(page).to have_text("Danger")
    end

    it "renders with different sizes" do
      render_inline(Ds::BadgeComponent.new(size: :xs)) { "XS" }
      expect(page).to have_text("XS")

      render_inline(Ds::BadgeComponent.new(size: :sm)) { "SM" }
      expect(page).to have_text("SM")

      render_inline(Ds::BadgeComponent.new(size: :md)) { "MD" }
      expect(page).to have_text("MD")
    end
  end

  describe Ds::ButtonComponent do
    it "renders a button with text" do
      render_inline(Ds::ButtonComponent.new) { "Click Me" }
      expect(page).to have_text("Click Me")
      expect(page).to have_css("button")
    end

    it "renders with primary variant" do
      render_inline(Ds::ButtonComponent.new(variant: :primary)) { "Primary" }
      expect(page).to have_text("Primary")
    end

    it "renders with secondary variant" do
      render_inline(Ds::ButtonComponent.new(variant: :secondary)) { "Secondary" }
      expect(page).to have_text("Secondary")
    end

    it "renders as a link when href provided" do
      render_inline(Ds::ButtonComponent.new(href: "/test")) { "Link" }
      expect(page).to have_css("a")
      expect(page).to have_text("Link")
    end

    it "renders disabled button" do
      render_inline(Ds::ButtonComponent.new(disabled: true)) { "Disabled" }
      expect(page).to have_css("button")
    end

    it "renders with different sizes" do
      render_inline(Ds::ButtonComponent.new(size: :xs)) { "XS" }
      expect(page).to have_text("XS")

      render_inline(Ds::ButtonComponent.new(size: :lg)) { "LG" }
      expect(page).to have_text("LG")
    end

    it "renders destructive variant" do
      render_inline(Ds::ButtonComponent.new(variant: :destructive)) { "Delete" }
      expect(page).to have_text("Delete")
    end

    it "renders ghost variant" do
      render_inline(Ds::ButtonComponent.new(variant: :ghost)) { "Ghost" }
      expect(page).to have_text("Ghost")
    end

    it "renders link variant" do
      render_inline(Ds::ButtonComponent.new(variant: :link)) { "Link Style" }
      expect(page).to have_text("Link Style")
    end

    it "renders with outline variant" do
      render_inline(Ds::ButtonComponent.new(variant: :outline)) { "Outline" }
      expect(page).to have_text("Outline")
    end
  end

  describe Ds::DialogComponent do
    it "renders a dialog with title" do
      render_inline(Ds::DialogComponent.new(title: "Test Dialog")) { "Content" }
      expect(page).to have_text("Test Dialog")
    end
  end

  describe Ds::EmptyStateComponent do
    it "renders empty state with title" do
      render_inline(Ds::EmptyStateComponent.new(title: "No data"))
      expect(page).to have_text("No data")
    end

    it "renders with description" do
      render_inline(Ds::EmptyStateComponent.new(title: "Empty", description: "Nothing here"))
      expect(page).to have_text("Nothing here")
    end
  end

  describe Ds::DonutChartComponent do
    it "renders a donut chart container" do
      render_inline(Ds::DonutChartComponent.new(data: [ { label: "A", value: 100 } ]))
      expect(page).to have_css("div")
    end
  end

  describe Ds::SankeyChartComponent do
    it "renders a chart container" do
      render_inline(Ds::SankeyChartComponent.new(data: { nodes: [], links: [] }))
      expect(page).to have_css("div")
    end
  end
end
