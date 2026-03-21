# frozen_string_literal: true

module Ds
  class SelectionBarComponent < BaseComponent
    def initialize(count: 0, delete_url: nil, edit_url: nil)
      @count = count
      @delete_url = delete_url
      @edit_url = edit_url
    end

    def call
      return "".html_safe if @count.zero?

      content_tag(:div,
        class: "fixed bottom-0 left-0 right-0 z-40 bg-container border-t border-border shadow-lg",
        data: { bulk_select_target: "selectionBar" }) do
        content_tag(:div, class: "max-w-7xl mx-auto px-4 py-3 flex items-center justify-between") do
          safe_join([
            content_tag(:span, class: "text-sm text-primary") do
              safe_join([
                "已选择 ",
                content_tag(:strong, data: { bulk_select_count: true }, class: "font-semibold") { @count.to_s },
                " 笔交易"
              ])
            end,
            content_tag(:div, class: "flex items-center gap-3") do
              safe_join([
                if @edit_url
                  link_to("批量编辑", @edit_url, class: "px-3 py-1.5 text-sm font-medium rounded-lg bg-gray-200 text-primary hover:bg-gray-300 transition-smooth")
                end,
                button_to("删除", @delete_url,
                  method: :delete,
                  data: { turbo_confirm: "确定要删除选中的交易吗？" },
                  class: "px-3 py-1.5 text-sm font-medium rounded-lg bg-red-600 text-white hover:bg-red-700 transition-smooth"
                ),
                link_to("取消选择", "#",
                  class: "px-3 py-1.5 text-sm font-medium rounded-lg border border-border text-secondary hover:bg-surface transition-smooth",
                  data: { action: "click->bulk-select#clearSelection" }
                )
              ])
            end
          ])
        end
      end
    end
  end
end
