# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::TooltipComponent, type: :component do
  describe "#render" do
    it "renders tooltip trigger with content" do
      render_inline(described_class.new(text: "Tooltip text", placement: "top")) do
        "Hover me"
      end

      expect(page).to have_content("Hover me")
      expect(page).to have_css("[data-controller='tooltip']")
      expect(page).to have_css("[data-tooltip-placement-value='top']")
      expect(page).to have_content("Tooltip text")
    end

    it "supports different placements" do
      %w[top bottom left right top-start top-end bottom-start bottom-end].each do |placement|
        render_inline(described_class.new(text: "Tip", placement: placement)) { "Content" }

        expect(page).to have_css("[data-tooltip-placement-value='#{placement}']")
      end
    end

    it "defaults to top placement" do
      render_inline(described_class.new(text: "Tip")) { "Content" }

      expect(page).to have_css("[data-tooltip-placement-value='top']")
    end

    it "raises error for invalid placement" do
      expect {
        described_class.new(text: "Tip", placement: "invalid")
      }.to raise_error(ArgumentError, /Invalid placement/)
    end
  end
end
