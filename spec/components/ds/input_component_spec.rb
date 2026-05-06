# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::InputComponent, type: :component do
  describe "text field" do
    it "calls text_field with correct parameters" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:text_field).with(
        :name,
        hash_including(class: include("w-full"), placeholder: nil, required: false)
      ).and_return("<input>".html_safe)

      render_inline(described_class.new(form: form, field: :name, type: :text))
    end

    it "passes placeholder to text_field" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:text_field).with(
        :name,
        hash_including(placeholder: "Enter name")
      ).and_return("<input>".html_safe)

      render_inline(described_class.new(form: form, field: :name, type: :text, placeholder: "Enter name"))
    end

    it "passes required to text_field" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:text_field).with(
        :name,
        hash_including(required: true)
      ).and_return("<input>".html_safe)

      render_inline(described_class.new(form: form, field: :name, type: :text, required: true))
    end
  end

  describe "email field" do
    it "calls email_field with correct field name" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:email_field).with(:email, anything).and_return("<input>".html_safe)

      render_inline(described_class.new(form: form, field: :email, type: :email))
    end
  end

  describe "password field" do
    it "calls password_field with correct field name" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:password_field).with(:password, anything).and_return("<input>".html_safe)

      render_inline(described_class.new(form: form, field: :password, type: :password))
    end
  end

  describe "number field" do
    it "calls number_field with correct field name" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:number_field).with(:amount, anything).and_return("<input>".html_safe)

      render_inline(described_class.new(form: form, field: :amount, type: :number))
    end
  end

  describe "textarea" do
    it "calls text_area with correct field name and rows" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:text_area).with(:notes, hash_including(rows: 3)).and_return("<textarea>".html_safe)

      render_inline(described_class.new(form: form, field: :notes, type: :textarea))
    end
  end

  describe "select" do
    it "calls select with choices and include_blank" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:select).with(
        :category,
        [ "A", "B" ],
        hash_including(include_blank: "Select..."),
        anything
      ).and_return("<select>".html_safe)

      render_inline(described_class.new(form: form, field: :category, type: :select, choices: [ "A", "B" ], placeholder: "Select..."))
    end
  end

  describe "prefix" do
    it "renders prefix wrapper and passes modified class to field" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:number_field).with(
        :price,
        hash_including(class: include("pl-8"))
      ).and_return("<input>".html_safe)

      render_inline(described_class.new(form: form, field: :price, type: :number, prefix: "$"))
      expect(page).to have_css("div.relative")
      expect(page).to have_css("span", text: "$")
    end
  end

  describe "base classes" do
    it "base_classes includes w-full" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      allow(form).to receive(:text_field).and_return("<input>".html_safe)
      component = described_class.new(form: form, field: :name, type: :text)
      expect(component.send(:base_classes)).to include("w-full")
    end

    it "base_classes includes rounded-lg" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      allow(form).to receive(:text_field).and_return("<input>".html_safe)
      component = described_class.new(form: form, field: :name, type: :text)
      expect(component.send(:base_classes)).to include("rounded-lg")
    end

    it "base_classes includes border" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      allow(form).to receive(:text_field).and_return("<input>".html_safe)
      component = described_class.new(form: form, field: :name, type: :text)
      expect(component.send(:base_classes)).to include("border")
    end
  end

  describe "custom class" do
    it "base_classes includes custom html_class" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      allow(form).to receive(:text_field).and_return("<input>".html_safe)
      component = described_class.new(form: form, field: :name, type: :text, html_class: "custom-input")
      expect(component.send(:base_classes)).to include("custom-input")
    end

    it "passes custom class to form field" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:text_field).with(
        :name,
        hash_including(class: include("custom-input"))
      ).and_return("<input>".html_safe)

      render_inline(described_class.new(form: form, field: :name, type: :text, html_class: "custom-input"))
    end
  end

  describe "combinations" do
    it "passes all options to text_field" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:text_field).with(
        :name,
        hash_including(
          placeholder: "Enter name",
          required: true,
          class: include("w-full", "custom")
        )
      ).and_return("<input>".html_safe)

      render_inline(described_class.new(
        form: form,
        field: :name,
        type: :text,
        placeholder: "Enter name",
        required: true,
        html_class: "custom"
      ))
    end

    it "renders number input with prefix wrapper" do
      form = instance_double(ActionView::Helpers::FormBuilder)
      expect(form).to receive(:number_field).with(
        :price,
        hash_including(class: include("pl-8", "price-input"))
      ).and_return("<input>".html_safe)

      render_inline(described_class.new(
        form: form,
        field: :price,
        type: :number,
        prefix: "$",
        html_class: "price-input"
      ))
      expect(page).to have_css("div.relative")
      expect(page).to have_css("span", text: "$")
    end
  end
end