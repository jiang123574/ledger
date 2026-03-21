# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::ToggleComponent, type: :component do
  describe "#render" do
    it "renders a toggle switch" do
      render_inline(described_class.new(id: "toggle-enabled", name: "enabled", checked: false))

      expect(page).to have_css("input[type='checkbox'][name='enabled']")
      expect(page).to have_css("input[type='hidden'][name='enabled']", visible: false)
    end

    it "renders checked state correctly" do
      render_inline(described_class.new(id: "toggle-checked", name: "enabled", checked: true))

      expect(page).to have_css("input[checked]")
    end

    it "renders unchecked state correctly" do
      render_inline(described_class.new(id: "toggle-unchecked", name: "enabled", checked: false))

      expect(page).not_to have_css("input[checked]")
    end

    it "renders disabled state" do
      render_inline(described_class.new(id: "toggle-disabled", name: "enabled", checked: false, disabled: true))

      expect(page).to have_css("input[disabled]")
    end

    it "supports custom id" do
      render_inline(described_class.new(id: "custom-toggle", name: "enabled", checked: false))

      expect(page).to have_css("#custom-toggle")
    end
  end
end