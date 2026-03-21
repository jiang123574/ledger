# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ds::DisclosureComponent, type: :component do
  it 'renders with title' do
    component = described_class.new(title: '筛选选项')

    rendered = render_inline(component) { 'Content here' }.to_html

    expect(rendered).to include('筛选选项')
  end

  it 'renders content in details' do
    component = described_class.new(title: '测试')

    rendered = render_inline(component) { '隐藏内容' }

    expect(rendered.to_html).to include('隐藏内容')
  end

  it 'supports open state' do
    component = described_class.new(title: '测试', open: true)

    rendered = render_inline(component) { '内容' }

    expect(rendered.to_html).to include('open')
  end

  it 'supports custom summary_content' do
    component = described_class.new

    rendered = render_inline(component) do |c|
      c.with_summary_content { 'Custom Summary' }
      'Content here'
    end

    expect(rendered.to_html).to include('Custom Summary')
  end

  it 'supports different rounded sizes' do
    [ :sm, :md, :lg, :xl, :none ].each do |size|
      component = described_class.new(title: '测试', rounded: size)

      rendered = render_inline(component) { '内容' }

      expect(rendered.to_html).to include('details')
    end
  end
end
