# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::MenuComponent, type: :component do
  describe "initialization" do
    it "accepts valid variant :icon" do
      component = described_class.new(variant: :icon)
      expect(component).to be_present
    end

    it "accepts valid variant :button" do
      component = described_class.new(variant: :button)
      expect(component).to be_present
    end

    it "accepts valid variant :avatar" do
      component = described_class.new(variant: :avatar)
      expect(component).to be_present
    end

    it "raises on invalid variant" do
      expect { described_class.new(variant: :invalid) }.to raise_error(ArgumentError, /Invalid variant/)
    end

    it "accepts custom placement" do
      component = described_class.new(variant: :icon, placement: "top-start")
      expect(component).to be_present
    end

    it "accepts custom offset" do
      component = described_class.new(variant: :icon, offset: 8)
      expect(component).to be_present
    end
  end

  describe "#call" do
    it "renders with menu controller" do
      result = render_inline(described_class.new(variant: :icon))
      expect(result).to have_css("div[data-controller='menu']")
    end

    it "renders placement value" do
      result = render_inline(described_class.new(variant: :icon, placement: "bottom-start"))
      expect(result).to have_css("div[data-menu-placement-value='bottom-start']")
    end

    it "renders offset value" do
      result = render_inline(described_class.new(variant: :icon, offset: 8))
      expect(result).to have_css("div[data-menu-offset-value='8']")
    end

    it "renders mobile fullwidth value" do
      result = render_inline(described_class.new(variant: :icon, mobile_fullwidth: false))
      expect(result).to have_css("div[data-menu-mobile-fullwidth-value='false']")
    end

    it "renders a button target" do
      result = render_inline(described_class.new(variant: :icon))
      expect(result).to have_css("[data-menu-target='button']")
    end

    it "renders a content target" do
      result = render_inline(described_class.new(variant: :icon))
      expect(result).to have_css("[data-menu-target='content']")
    end

    it "renders avatar variant with U text" do
      result = render_inline(described_class.new(variant: :avatar))
      expect(result).to have_text("U")
    end
  end
end

RSpec.describe Ds::MenuItemComponent, type: :component do
  describe "initialization" do
    it "accepts link variant" do
      component = described_class.new(variant: :link, text: "Edit", href: "/edit")
      expect(component).to be_present
    end

    it "accepts button variant" do
      component = described_class.new(variant: :button, text: "Delete", href: "/delete")
      expect(component).to be_present
    end

    it "accepts divider variant" do
      component = described_class.new(variant: :divider)
      expect(component).to be_present
    end

    it "raises on invalid variant" do
      expect { described_class.new(variant: :invalid) }.to raise_error(ArgumentError, /Invalid variant/)
    end
  end

  describe "#call" do
    it "renders divider as hr" do
      result = render_inline(described_class.new(variant: :divider))
      expect(result).to have_css("hr")
    end

    it "renders link with text" do
      result = render_inline(described_class.new(variant: :link, text: "Edit", href: "/edit"))
      expect(result).to have_text("Edit")
      expect(result).to have_css("a")
    end

    it "renders link with icon" do
      result = render_inline(described_class.new(variant: :link, text: "Edit", icon: "pencil", href: "/edit"))
      expect(result).to have_css("svg")
    end

    it "renders button with text" do
      result = render_inline(described_class.new(variant: :button, text: "Delete", href: "/delete"))
      expect(result).to have_text("Delete")
    end

    it "renders destructive link with red styling" do
      result = render_inline(described_class.new(variant: :link, text: "Delete", href: "/delete", destructive: true))
      expect(result).to have_text("Delete")
    end

    it "renders button with confirm dialog" do
      result = render_inline(described_class.new(variant: :button, text: "Delete", href: "/delete", confirm: "Are you sure?"))
      expect(result).to have_css("[data-turbo-confirm='Are you sure?']")
    end
  end
end
