# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::AlertComponent, type: :component do
  describe "#render" do
    it "renders info variant with correct styling" do
      render_inline(described_class.new(message: "Info message", variant: :info))

      expect(page).to have_css(".bg-blue-50")
      expect(page).to have_content("Info message")
    end

    it "renders success variant with correct styling" do
      render_inline(described_class.new(message: "Success!", variant: :success))

      expect(page).to have_css(".bg-green-50")
      expect(page).to have_content("Success!")
    end

    it "renders warning variant with correct styling" do
      render_inline(described_class.new(message: "Warning!", variant: :warning))

      expect(page).to have_css(".bg-yellow-50")
      expect(page).to have_content("Warning!")
    end

    it "renders error variant with correct styling" do
      render_inline(described_class.new(message: "Error!", variant: :error))

      expect(page).to have_css(".bg-red-50")
      expect(page).to have_content("Error!")
    end

    it "renders with block content" do
      render_inline(described_class.new(variant: :info)) do
        "<strong>Important:</strong> Please read.".html_safe
      end

      expect(page).to have_css("strong", text: "Important:")
    end

    it "renders dismissible button when dismissible: true" do
      render_inline(described_class.new(message: "Dismissible", variant: :info, dismissible: true))

      expect(page).to have_css("button[data-action*='dismiss']")
    end

    it "does not render dismissible button by default" do
      render_inline(described_class.new(message: "Not dismissible", variant: :info))

      expect(page).not_to have_css("button[data-action*='dismiss']")
    end
  end

  describe "validations" do
    it "raises error for invalid variant" do
      expect {
        described_class.new(message: "Test", variant: :invalid)
      }.to raise_error(ArgumentError, /Invalid variant/)
    end
  end
end
