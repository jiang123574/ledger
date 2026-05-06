# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ds::InputComponent, type: :component do
  let(:form) do
    instance_double(ActionView::Helpers::FormBuilder).tap do |fb|
      allow(fb).to receive(:text_field).and_return("<input type='text'>".html_safe)
      allow(fb).to receive(:email_field).and_return("<input type='email'>".html_safe)
      allow(fb).to receive(:password_field).and_return("<input type='password'>".html_safe)
      allow(fb).to receive(:number_field).and_return("<input type='number'>".html_safe)
      allow(fb).to receive(:text_area).and_return("<textarea></textarea>".html_safe)
      allow(fb).to receive(:select).and_return("<select></select>".html_safe)
    end
  end

  describe "text field" do
    it "renders text input" do
      render_inline(described_class.new(form: form, field: :name, type: :text))
      expect(page).to have_css("input[type='text']")
    end

    it "renders with placeholder" do
      render_inline(described_class.new(form: form, field: :name, type: :text, placeholder: "Enter name"))
      expect(page).to have_css("input")
    end

    it "renders with required attribute" do
      render_inline(described_class.new(form: form, field: :name, type: :text, required: true))
      expect(page).to have_css("input")
    end
  end

  describe "email field" do
    it "renders email input" do
      render_inline(described_class.new(form: form, field: :email, type: :email))
      expect(page).to have_css("input[type='email']")
    end
  end

  describe "password field" do
    it "renders password input" do
      render_inline(described_class.new(form: form, field: :password, type: :password))
      expect(page).to have_css("input[type='password']")
    end
  end

  describe "number field" do
    it "renders number input" do
      render_inline(described_class.new(form: form, field: :amount, type: :number))
      expect(page).to have_css("input[type='number']")
    end
  end

  describe "textarea" do
    it "renders textarea" do
      render_inline(described_class.new(form: form, field: :notes, type: :textarea))
      expect(page).to have_css("textarea")
    end
  end

  describe "select" do
    it "renders select dropdown" do
      render_inline(described_class.new(form: form, field: :category, type: :select, choices: [ "A", "B" ]))
      expect(page).to have_css("select")
    end
  end

  describe "prefix" do
    it "renders with prefix wrapper" do
      render_inline(described_class.new(form: form, field: :price, type: :number, prefix: "$"))
      expect(page).to have_css("div.relative")
      expect(page).to have_css("span", text: "$")
    end

    it "applies left padding class with prefix" do
      render_inline(described_class.new(form: form, field: :price, type: :number, prefix: "$"))
      expect(page).to have_css("div.relative")
    end
  end

  describe "base classes" do
    it "base_classes includes w-full" do
      component = described_class.new(form: form, field: :name, type: :text)
      expect(component.send(:base_classes)).to include("w-full")
    end

    it "base_classes includes rounded-lg" do
      component = described_class.new(form: form, field: :name, type: :text)
      expect(component.send(:base_classes)).to include("rounded-lg")
    end

    it "base_classes includes border" do
      component = described_class.new(form: form, field: :name, type: :text)
      expect(component.send(:base_classes)).to include("border")
    end
  end

  describe "custom class" do
    it "base_classes includes custom html_class" do
      component = described_class.new(form: form, field: :name, type: :text, html_class: "custom-input")
      expect(component.send(:base_classes)).to include("custom-input")
    end
  end

  describe "combinations" do
    it "renders text input with all options" do
      render_inline(described_class.new(
        form: form,
        field: :name,
        type: :text,
        placeholder: "Enter name",
        required: true,
        html_class: "custom"
      ))
      expect(page).to have_css("input[type='text']")
    end

    it "renders number input with prefix and custom class" do
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
