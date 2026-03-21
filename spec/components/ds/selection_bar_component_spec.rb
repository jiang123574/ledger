# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ds::SelectionBarComponent, type: :component do
  it 'renders nothing when count is zero' do
    component = described_class.new(count: 0)
    
    rendered = render_inline(component).to_html
    
    expect(rendered).to be_empty
  end

  it 'renders selection bar when count > 0' do
    component = described_class.new(
      count: 5,
      delete_url: '/transactions/bulk_destroy'
    )
    
    rendered = render_inline(component).to_html
    
    expect(rendered).to include('已选择')
    expect(rendered).to include('5')
    expect(rendered).to include('删除')
    expect(rendered).to include('/transactions/bulk_destroy')
  end

  it 'renders cancel button' do
    component = described_class.new(
      count: 3,
      delete_url: '/transactions/bulk_destroy'
    )
    
    rendered = render_inline(component).to_html
    
    expect(rendered).to include('取消选择')
  end

  it 'renders edit button when edit_url provided' do
    component = described_class.new(
      count: 3,
      delete_url: '/transactions/bulk_destroy',
      edit_url: '/transactions/bulk_edit'
    )
    
    rendered = render_inline(component).to_html
    
    expect(rendered).to include('批量编辑')
    expect(rendered).to include('/transactions/bulk_edit')
  end

  it 'does not render edit button when edit_url is nil' do
    component = described_class.new(
      count: 3,
      delete_url: '/transactions/bulk_destroy'
    )
    
    rendered = render_inline(component).to_html
    
    expect(rendered).not_to include('批量编辑')
  end
end