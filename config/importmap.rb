# Pin npm packages by running ./bin/importmap

pin "application"
pin "bill_formatters"
pin "entry_card_renderer"
pin "web_vitals"
pin "selectors"

# Pin controllers manually (Propshaft compatibility)
pin "controllers", to: "controllers/index.js"
pin "controllers/application", to: "controllers/application.js"
pin "controllers/index", to: "controllers/index.js"
pin "controllers/alert_controller", to: "controllers/alert_controller.js"
pin "controllers/auto_submit_form_controller", to: "controllers/auto_submit_form_controller.js"
pin "controllers/bulk_select_controller", to: "controllers/bulk_select_controller.js"
pin "controllers/budget_gauge_controller", to: "controllers/budget_gauge_controller.js"
pin "controllers/category_donut_chart_controller", to: "controllers/category_donut_chart_controller.js"
pin "controllers/color_theme_controller", to: "controllers/color_theme_controller.js"
pin "controllers/credit_bill_entries_controller", to: "controllers/credit_bill_entries_controller.js"
pin "controllers/entry_list_controller", to: "controllers/entry_list_controller.js"
pin "controllers/credit_card_form_controller", to: "controllers/credit_card_form_controller.js"
pin "controllers/dashboard_section_controller", to: "controllers/dashboard_section_controller.js"
pin "controllers/dashboard_sortable_controller", to: "controllers/dashboard_sortable_controller.js"
pin "controllers/donut_chart_controller", to: "controllers/donut_chart_controller.js"
pin "controllers/ds_disclosure_controller", to: "controllers/ds_disclosure_controller.js"
pin "controllers/haptic_controller", to: "controllers/haptic_controller.js"
pin "controllers/list_filter_controller", to: "controllers/list_filter_controller.js"
pin "controllers/loading_button_controller", to: "controllers/loading_button_controller.js"
pin "controllers/menu_controller", to: "controllers/menu_controller.js"
pin "controllers/mobile_layout_controller", to: "controllers/mobile_layout_controller.js"
pin "controllers/page_skeleton_controller", to: "controllers/page_skeleton_controller.js"
pin "controllers/page_transition_controller", to: "controllers/page_transition_controller.js"
pin "controllers/sankey_chart_controller", to: "controllers/sankey_chart_controller.js"
pin "controllers/select_controller", to: "controllers/select_controller.js"
pin "controllers/sparkline_chart_controller", to: "controllers/sparkline_chart_controller.js"
pin "controllers/stagger_list_controller", to: "controllers/stagger_list_controller.js"
pin "controllers/theme_controller", to: "controllers/theme_controller.js"
pin "controllers/time_series_chart_controller", to: "controllers/time_series_chart_controller.js"
pin "controllers/tooltip_controller", to: "controllers/tooltip_controller.js"
pin "controllers/account_sort_controller", to: "controllers/account_sort_controller.js"
pin "controllers/stats_loader_controller", to: "controllers/stats_loader_controller.js"
pin "controllers/chart_visibility_controller", to: "controllers/chart_visibility_controller.js"
pin "controllers/trend_line_chart_controller", to: "controllers/trend_line_chart_controller.js"
pin "controllers/report_tabs_controller", to: "controllers/report_tabs_controller.js"
pin "controllers/asset_trend_chart_controller", to: "controllers/asset_trend_chart_controller.js"
pin "controllers/category_comparison_controller", to: "controllers/category_comparison_controller.js"
pin "controllers/filter_popover_controller", to: "controllers/filter_popover_controller.js"
pin "controllers/bill_statement_controller", to: "controllers/bill_statement_controller.js"
pin "controllers/utils/chartjs_helper", to: "controllers/utils/chartjs_helper.js"

# Hotwired packages - vendored for production reliability
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/turbo", to: "@hotwired--turbo.js" # @8.0.23
pin "@hotwired/turbo-rails", to: "@hotwired--turbo-rails.js" # @8.0.23

# Stimulus loading helper - inline helper
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# Floating UI for positioning - vendored for production reliability
pin "@floating-ui/utils", to: "@floating-ui--utils.js" # @0.2.11
pin "@floating-ui/utils/dom", to: "@floating-ui--utils--dom.js" # @0.2.11
pin "@floating-ui/core", to: "@floating-ui--core.js" # @1.7.5
pin "@floating-ui/dom", to: "@floating-ui--dom.js" # @1.7.6

# Chart.js - loaded via UMD script tag
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
pin "@rails/actioncable/src", to: "@rails--actioncable--src.js" # @8.1.300
