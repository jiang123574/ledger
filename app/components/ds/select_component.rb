# frozen_string_literal: true

module Ds
  # Select Component - Custom dropdown select with search support
  #
  # Usage:
  #   <%= render(Ds::SelectComponent.new(
  #     form: f,
  #     method: :category_id,
  #     items: Category.all,
  #     selected: @transaction.category_id,
  #     placeholder: "Select category"
  #   )) %>
  #
  # With search:
  #   <%= render(Ds::SelectComponent.new(
  #     form: f,
  #     method: :user_id,
  #     items: User.all,
  #     searchable: true
  #   )) %>
  #
  # Custom items:
  #   items = [{ value: 1, label: "Option 1" }, { value: 2, label: "Option 2" }]
  #
  class SelectComponent < BaseComponent
    VARIANTS = %i[simple badge logo].freeze

    attr_reader :form, :method, :items, :selected_value, :placeholder, :variant, :searchable, :options

    def initialize(form:, method:, items:, selected: nil, placeholder: "Select an option", variant: :simple, searchable: false, include_blank: nil, **options)
      @form = form
      @method = method
      @placeholder = placeholder
      @variant = variant
      @searchable = searchable
      @options = options

      normalized_items = normalize_items(items)

      if include_blank
        normalized_items.unshift({
          value: nil,
          label: include_blank,
          object: nil
        })
      end

      @items = normalized_items
      @selected_value = selected
    end

    def selected_item
      items.find { |item| item[:value] == selected_value }
    end

    def call
      tag.div(
        data: {
          controller: "select #{'list-filter' if searchable}",
          action: "dropdown:select->select#select"
        },
        class: "relative"
      ) do
        safe_join([
          hidden_field,
          button,
          dropdown_menu
        ])
      end
    end

    private

    def normalize_items(collection)
      collection.map do |item|
        case item
        when Hash
          {
            value: item[:value],
            label: item[:label],
            object: item[:object]
          }
        else
          {
            value: item.id,
            label: item.name,
            object: item
          }
        end
      end
    end

    def hidden_field
      @form.hidden_field(
        @method,
        value: @selected_value,
        data: { select_target: "input" }
      )
    end

    def button
      tag.button(
        type: "button",
        class: "w-full px-3 py-2 text-left text-sm bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-hidden focus:ring-2 focus:ring-blue-500",
        data: {
          select_target: "button",
          action: "click->select#toggle"
        },
        aria: {
          haspopup: "listbox",
          expanded: @selected_value.present? ? "true" : "false"
        }
      ) do
        selected_item&.dig(:label) || @placeholder
      end
    end

    def dropdown_menu
      tag.div(
        data: { select_target: "menu" },
        class: "absolute z-50 w-full mt-1 bg-white dark:bg-gray-800 rounded-lg shadow-lg border border-gray-200 dark:border-gray-700 hidden opacity-0 -translate-y-1 transition duration-150 ease-out"
      ) do
        safe_join([
          search_input,
          options_list
        ].compact)
      end
    end

    def search_input
      return nil unless @searchable

      tag.div(class: "relative p-2 border-b border-gray-200 dark:border-gray-700") do
        tag.input(
          type: "search",
          placeholder: "Search...",
          autocomplete: "off",
          class: "w-full px-3 py-2 text-sm bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-lg focus:outline-hidden focus:ring-2 focus:ring-blue-500",
          data: {
            list_filter_target: "input",
            action: "list-filter#filter"
          }
        )
      end
    end

    def options_list
      tag.div(
        data: {
          list_filter_target: "list",
          select_target: "content"
        },
        class: "max-h-64 overflow-auto p-1",
        role: "listbox"
      ) do
        safe_join(items.map { |item| render_option(item) })
      end
    end

    def render_option(item)
      is_selected = item[:value] == selected_value

      tag.div(
        class: "flex items-center gap-2 px-3 py-2 text-sm cursor-pointer rounded-md hover:bg-gray-100 dark:hover:bg-gray-700 #{'bg-gray-100 dark:bg-gray-700' if is_selected}",
        role: "option",
        tabindex: "0",
        aria: { selected: is_selected },
        data: {
          action: "click->select#select",
          value: item[:value],
          filter_name: item[:label]
        }
      ) do
        safe_join([
          check_icon(is_selected),
          tag.span(item[:label])
        ])
      end
    end

    def check_icon(is_selected)
      return tag.span(class: "hidden") unless is_selected

      render(Ds::IconComponent.new(name: "check", size: :sm, class: "text-blue-600"))
    end
  end
end
