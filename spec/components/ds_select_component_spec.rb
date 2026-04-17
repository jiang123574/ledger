# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::SelectComponent, type: :component do
  let(:form) { double("form") }

  before do
    allow(form).to receive(:hidden_field) do |method, **opts|
      "<input type=\"hidden\" name=\"#{method}\" value=\"#{opts[:value]}\" />".html_safe
    end
  end

  describe "initialization" do
    it "accepts hash items" do
      items = [ { value: 1, label: "Option 1" }, { value: 2, label: "Option 2" } ]
      component = described_class.new(form: form, method: :category_id, items: items)
      expect(component.items.length).to eq(2)
      expect(component.items.first[:label]).to eq("Option 1")
    end

    it "normalizes object items" do
      item = double("item", id: 42, name: "Test Item")
      component = described_class.new(form: form, method: :category_id, items: [ item ])
      expect(component.items.first[:value]).to eq(42)
      expect(component.items.first[:label]).to eq("Test Item")
      expect(component.items.first[:object]).to eq(item)
    end

    it "supports include_blank option" do
      items = [ { value: 1, label: "Option 1" } ]
      component = described_class.new(form: form, method: :category_id, items: items, include_blank: "None")
      expect(component.items.first[:value]).to be_nil
      expect(component.items.first[:label]).to eq("None")
      expect(component.items.length).to eq(2)
    end

    it "stores selected value" do
      items = [ { value: 1, label: "Option 1" } ]
      component = described_class.new(form: form, method: :category_id, items: items, selected: 1)
      expect(component.selected_value).to eq(1)
    end

    it "stores placeholder" do
      items = []
      component = described_class.new(form: form, method: :category_id, items: items, placeholder: "Pick one")
      expect(component.placeholder).to eq("Pick one")
    end

    it "stores variant" do
      items = []
      component = described_class.new(form: form, method: :category_id, items: items, variant: :badge)
      expect(component.variant).to eq(:badge)
    end

    it "stores searchable flag" do
      items = []
      component = described_class.new(form: form, method: :category_id, items: items, searchable: true)
      expect(component.searchable).to be true
    end
  end

  describe "#selected_item" do
    it "returns the selected item" do
      items = [ { value: 1, label: "A" }, { value: 2, label: "B" } ]
      component = described_class.new(form: form, method: :category_id, items: items, selected: 2)
      expect(component.selected_item[:label]).to eq("B")
    end

    it "returns nil when nothing selected" do
      items = [ { value: 1, label: "A" } ]
      component = described_class.new(form: form, method: :category_id, items: items)
      expect(component.selected_item).to be_nil
    end
  end

  describe "#call" do
    it "renders a div with controller" do
      items = [ { value: 1, label: "Option 1" } ]
      component = described_class.new(form: form, method: :category_id, items: items)
      result = render_inline(component)
      expect(result.to_s).to include("data-controller")
      expect(result.to_s).to include("select")
    end

    it "renders list-filter controller when searchable" do
      items = [ { value: 1, label: "Option 1" } ]
      component = described_class.new(form: form, method: :category_id, items: items, searchable: true)
      result = render_inline(component)
      expect(result).to have_css("div[data-controller*='list-filter']")
    end

    it "renders button with placeholder when nothing selected" do
      items = [ { value: 1, label: "Option 1" } ]
      component = described_class.new(form: form, method: :category_id, items: items, placeholder: "Choose...")
      result = render_inline(component)
      expect(result).to have_css("button", text: "Choose...")
    end

    it "renders button with selected label" do
      items = [ { value: 1, label: "My Option" } ]
      component = described_class.new(form: form, method: :category_id, items: items, selected: 1)
      result = render_inline(component)
      expect(result).to have_css("button", text: "My Option")
    end

    it "renders options in listbox" do
      items = [ { value: 1, label: "A" }, { value: 2, label: "B" } ]
      component = described_class.new(form: form, method: :category_id, items: items)
      result = render_inline(component)
      expect(result).to have_css("[role='option']", count: 2)
    end

    it "renders search input when searchable" do
      items = [ { value: 1, label: "A" } ]
      component = described_class.new(form: form, method: :category_id, items: items, searchable: true)
      result = render_inline(component)
      expect(result).to have_css("input[type='search']")
    end

    it "does not render search input when not searchable" do
      items = [ { value: 1, label: "A" } ]
      component = described_class.new(form: form, method: :category_id, items: items)
      result = render_inline(component)
      expect(result).not_to have_css("input[type='search']")
    end

    it "marks selected option with aria-selected" do
      items = [ { value: 1, label: "A" }, { value: 2, label: "B" } ]
      component = described_class.new(form: form, method: :category_id, items: items, selected: 1)
      result = render_inline(component)
      expect(result).to have_css("[aria-selected='true']", text: "A")
    end
  end
end
