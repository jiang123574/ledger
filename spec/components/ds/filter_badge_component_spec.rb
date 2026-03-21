# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ds::FilterBadgeComponent, type: :component do
  it 'renders label and value' do
    component = described_class.new(label: '类型', value: '收入')

    rendered = render_inline(component).to_html

    expect(rendered).to include('类型')
    expect(rendered).to include('收入')
  end

  it 'renders remove link when remove_url provided' do
    component = described_class.new(
      label: '类型',
      value: '收入',
      remove_url: '/transactions?type='
    )

    rendered = render_inline(component).to_html

    expect(rendered).to include('/transactions?type=')
    expect(rendered).to include('M6 18L18 6') # x icon path
  end

  it 'does not render remove link when remove_url is nil' do
    component = described_class.new(label: '类型', value: '收入')

    rendered = render_inline(component).to_html

    expect(rendered).not_to include('href=')
  end

  it 'has correct styling classes' do
    component = described_class.new(label: '类型', value: '收入')

    rendered = render_inline(component).to_html

    expect(rendered).to include('inline-flex')
    expect(rendered).to include('rounded-full')
    expect(rendered).to include('text-xs')
  end
end
