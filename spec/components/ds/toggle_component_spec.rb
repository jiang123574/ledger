# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::ToggleComponent, type: :component do
  describe "#render" do
    it "renders a toggle switch" do
      render_inline(described_class.new(name: "enabled", checked: false))

      expect(page).to have_css("button[type='button'][role='switch']")
      expect(page).to have_css("input[type='hidden'][name='enabled']", visible: false)
    end

    it "renders checked state correctly" do
      render_inline(described_class.new(name: "enabled", checked: true))

      expect(page).to have_css("button[aria-checked='true']")
    end

    it "renders unchecked state correctly" do
      render_inline(described_class.new(name: "enabled", checked: false))

      expect(page).to have_css("button[aria-checked='false']")
    end

    it "renders disabled state" do
      render_inline(described_class.new(name: "enabled", checked: false, disabled: true))

      expect(page).to have_css("button[disabled]")
    end

    it "supports custom id" do
      render_inline(described_class.new(name: "enabled", checked: false, id: "custom-toggle"))

      expect(page).to have_css("#custom-toggle")
    end
  end
end