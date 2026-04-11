# frozen_string_literal: true

require "rails_helper"

RSpec.describe "App Components", type: :component do
  describe StatCardComponent do
    it "renders stat card with numeric value" do
      render_inline(StatCardComponent.new(title: "Total", value: 1000.to_d))
      expect(page).to have_text("Total")
    end

    it "renders with currency" do
      render_inline(StatCardComponent.new(title: "Balance", value: 500.to_d, currency: "$"))
      expect(page).to have_text("$")
    end

    it "renders with trend" do
      render_inline(StatCardComponent.new(title: "Growth", value: 200.to_d, trend: "+10%", trend_direction: "up"))
      expect(page).to have_text("+10%")
    end
  end
end

RSpec.describe ApplicationComponent do
  describe "#classes" do
    it "joins class names" do
      component = Class.new { include ApplicationComponent }.new
      expect(component.classes("foo", "bar")).to eq("foo bar")
    end

    it "handles arrays" do
      component = Class.new { include ApplicationComponent }.new
      expect(component.classes(["foo", "bar"], "baz")).to eq("foo bar baz")
    end

    it "compacts nil values" do
      component = Class.new { include ApplicationComponent }.new
      expect(component.classes("foo", nil, "bar")).to eq("foo bar")
    end

    it "handles empty args" do
      component = Class.new { include ApplicationComponent }.new
      expect(component.classes).to eq("")
    end
  end

  describe "#data_attributes" do
    it "generates data attributes" do
      component = Class.new { include ApplicationComponent }.new
      result = component.data_attributes(controller: "test", action: "click")
      expect(result).to include('data-controller="test"')
      expect(result).to include('data-action="click"')
    end

    it "handles empty attributes" do
      component = Class.new { include ApplicationComponent }.new
      expect(component.data_attributes).to eq("")
    end
  end
end

RSpec.describe Ds::BaseComponent do
  describe "#class_names" do
    it "joins string and keyword arguments" do
      component = described_class.new
      result = component.class_names("foo", "bar", active: true, disabled: false)
      expect(result).to include("foo")
      expect(result).to include("bar")
      expect(result).to include("active")
      expect(result).not_to include("disabled")
    end

    it "handles only string args" do
      component = described_class.new
      expect(component.class_names("foo", "bar")).to eq("foo bar")
    end

    it "handles only keyword args" do
      component = described_class.new
      result = component.class_names(active: true, visible: false)
      expect(result).to eq("active")
    end

    it "handles empty args" do
      component = described_class.new
      expect(component.class_names).to eq("")
    end

    it "dasherizes keyword names" do
      component = described_class.new
      result = component.class_names(data_test: true)
      expect(result).to eq("data-test")
    end
  end
end
