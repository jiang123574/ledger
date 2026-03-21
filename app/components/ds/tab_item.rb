# frozen_string_literal: true

module Ds
  class TabItem
    attr_reader :id, :label, :content

    def initialize(id:, label:, content: nil, &block)
      @id = id
      @label = label
      @content = block ? block.call : content
    end

    def active?(active_tab)
      @id.to_s == active_tab.to_s || (active_tab.blank? && @id == :first)
    end
  end
end
