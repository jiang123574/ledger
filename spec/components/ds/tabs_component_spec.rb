# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::TabsComponent, type: :component do
  describe "tab_link" do
    it "returns link element with correct href" do
      component = described_class.new(active_tab: "tab1")
      result = component.tab_link("tab1", "Tab 1")
      expect(result).to include("href=\"#")
      expect(result).to include("Tab 1")
    end

    it "active tab has blue styling" do
      component = described_class.new(active_tab: "tab1")
      result = component.tab_link("tab1", "Active Tab")
      expect(result).to include("border-blue-500")
      expect(result).to include("text-blue-600")
    end

    it "inactive tab has hover styling" do
      component = described_class.new(active_tab: "tab1")
      result = component.tab_link("tab2", "Inactive Tab")
      expect(result).to include("border-transparent")
      expect(result).to include("hover:text-primary")
    end

    it "has tabs controller data attributes" do
      component = described_class.new
      result = component.tab_link("tab1", "Tab")
      expect(result).to include("data-action=\"tabs#switch")
      expect(result).to include("data-tabs-target=\"tab")
      expect(result).to include("data-tab-id=\"tab1")
    end
  end

  describe "panel" do
    it "returns div with mt-4 class" do
      component = described_class.new(active_tab: "tab1")
      result = component.panel("tab1") { "Content" }
      expect(result).to include("mt-4")
    end

    it "active panel is visible" do
      component = described_class.new(active_tab: "tab1")
      result = component.panel("tab1") { "Visible" }
      expect(result).not_to include("hidden")
    end

    it "inactive panel is hidden" do
      component = described_class.new(active_tab: "tab1")
      result = component.panel("tab2") { "Hidden" }
      expect(result).to include("hidden")
    end

    it "has panel data attributes" do
      component = described_class.new(active_tab: "tab1")
      result = component.panel("mytab") { "Content" }
      expect(result).to include("data-tabs-target=\"panel")
      expect(result).to include("data-tab-panel-id=\"mytab")
    end
  end

  describe "active detection" do
    it "correctly identifies active tab" do
      component = described_class.new(active_tab: "overview")
      expect(component.send(:active?, "overview")).to be true
      expect(component.send(:active?, "other")).to be false
    end

    it "nil active_tab matches nothing" do
      component = described_class.new(active_tab: nil)
      expect(component.send(:active?, "tab1")).to be false
    end
  end
end
