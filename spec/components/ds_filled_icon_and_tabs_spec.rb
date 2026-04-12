# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::FilledIconComponent, type: :component do
  describe "initialization" do
    it "accepts icon, color, and size options" do
      component = described_class.new(icon: "star", color: :red, size: :lg)
      expect(component.instance_variable_get(:@icon)).to eq("star")
      expect(component.instance_variable_get(:@color)).to eq(:red)
      expect(component.instance_variable_get(:@size)).to eq(:lg)
    end

    it "defaults to blue color and md size" do
      component = described_class.new(icon: "star")
      expect(component.instance_variable_get(:@color)).to eq(:blue)
      expect(component.instance_variable_get(:@size)).to eq(:md)
    end

    it "stores extra options" do
      component = described_class.new(icon: "star", class: "my-class")
      expect(component.instance_variable_get(:@options)[:class]).to eq("my-class")
    end
  end

  describe "COLORS constant" do
    it "defines colors for all supported color keys" do
      expect(Ds::FilledIconComponent::COLORS).to have_key(:red)
      expect(Ds::FilledIconComponent::COLORS).to have_key(:green)
      expect(Ds::FilledIconComponent::COLORS).to have_key(:blue)
      expect(Ds::FilledIconComponent::COLORS).to have_key(:yellow)
      expect(Ds::FilledIconComponent::COLORS).to have_key(:purple)
    end

    it "includes background and text classes" do
      expect(Ds::FilledIconComponent::COLORS[:red]).to include("bg-red-100")
      expect(Ds::FilledIconComponent::COLORS[:red]).to include("text-red-600")
    end
  end
end

RSpec.describe Ds::TabsComponent, type: :component do
  describe "initialization" do
    it "accepts active_tab" do
      component = described_class.new(active_tab: :tab1)
      expect(component.instance_variable_get(:@active_tab)).to eq(:tab1)
    end

    it "works without active_tab" do
      component = described_class.new
      expect(component.instance_variable_get(:@active_tab)).to be_nil
    end
  end

  describe "#tab_link" do
    it "generates a link for a tab" do
      component = described_class.new(active_tab: :tab1)
      result = component.tab_link(:tab1, "Tab 1")
      expect(result).to include("Tab 1")
      expect(result).to include("data-tabs-target")
    end

    it "applies active classes to selected tab" do
      component = described_class.new(active_tab: :tab1)
      result = component.tab_link(:tab1, "Active Tab")
      expect(result).to include("border-blue-500")
      expect(result).to include("text-blue-600")
    end

    it "applies inactive classes to non-selected tab" do
      component = described_class.new(active_tab: :tab1)
      result = component.tab_link(:tab2, "Inactive Tab")
      expect(result).to include("border-transparent")
    end

    it "includes tab_id in data attributes" do
      component = described_class.new(active_tab: :tab1)
      result = component.tab_link(:my_tab, "Tab")
      expect(result).to include("data-tab-id")
    end

    it "merges custom data attributes" do
      component = described_class.new(active_tab: :tab1)
      result = component.tab_link(:tab1, "Tab", data: { custom: "value" })
      expect(result).to include("custom")
    end
  end

  describe "#panel" do
    it "renders an active panel" do
      component = described_class.new(active_tab: :tab1)
      rendered = component.panel(:tab1) { "Panel Content" }
      expect(rendered).to include("Panel Content")
      expect(rendered).to include("data-tabs-target")
      expect(rendered).not_to include("hidden")
    end

    it "renders a hidden inactive panel" do
      component = described_class.new(active_tab: :tab1)
      rendered = component.panel(:tab2) { "Hidden Content" }
      expect(rendered).to include("Hidden Content")
      expect(rendered).to include("hidden")
    end

    it "includes tab_panel_id in data attributes" do
      component = described_class.new(active_tab: :tab1)
      rendered = component.panel(:tab1) { "Content" }
      expect(rendered).to include("data-tab-panel-id")
    end
  end
end
