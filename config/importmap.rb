# Pin npm packages by running ./bin/importmap

pin "application"
pin "web_vitals"

# Pin controllers manually (Propshaft compatibility)
pin "controllers", to: "controllers/index.js"
pin "controllers/application", to: "controllers/application.js"
pin "controllers/index", to: "controllers/index.js"
pin "controllers/alert_controller", to: "controllers/alert_controller.js"
pin "controllers/auto_submit_form_controller", to: "controllers/auto_submit_form_controller.js"
pin "controllers/bulk_select_controller", to: "controllers/bulk_select_controller.js"
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

# Hotwire via esm.sh (better CDN with proper module resolution)
pin "@hotwired/stimulus", to: "https://esm.sh/@hotwired/stimulus@3.2.2"
pin "@hotwired/turbo", to: "https://esm.sh/@hotwired/turbo@8.0.4"
pin "@hotwired/turbo-rails", to: "https://esm.sh/@hotwired/turbo-rails@8.0.4"

# Stimulus loading helper - inline helper
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# Floating UI for positioning
pin "@floating-ui/utils", to: "https://unpkg.com/@floating-ui/utils@0.2.8/dist/floating-ui.utils.mjs"
pin "@floating-ui/utils/dom", to: "https://unpkg.com/@floating-ui/utils@0.2.8/dist/floating-ui.utils.dom.mjs"
pin "@floating-ui/core", to: "https://unpkg.com/@floating-ui/core@1.6.0/dist/floating-ui.core.mjs"
pin "@floating-ui/dom", to: "https://unpkg.com/@floating-ui/dom@1.6.5/dist/floating-ui.dom.mjs"

# Chart.js for charts
pin "chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"
