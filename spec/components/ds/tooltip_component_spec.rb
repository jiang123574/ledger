# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::TooltipComponent, type: :component do
  describe "#render" do
    it "renders tooltip trigger with content" do
      render_inline(described_class.new(text: "Tooltip text", position: :top)) do
        "Hover me"
      end

      expect(page).to have_content("Hover me")
      expect(page).to have_css("[data-tooltip-text='Tooltip text']")
    end

    it "supports different positions" do
      %i[top bottom left right top-start top-end bottom-start bottom-end].each do |position|
        render_inline(described_class.new(text: "Tip", position: position)) { "Content" }

        expect(page).to have_css("[data-tooltip-position='#{position}']")
      end
    end

    it "defaults to top position" do
      render_inline(described_class.new(text: "Tip")) { "Content" }

      expect(page).to have_css("[data-tooltip-position='top']")
    end
  end
end