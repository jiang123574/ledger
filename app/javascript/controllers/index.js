// Import and register all Stimulus controllers
import { application } from "controllers/application"

// Import controllers
import AlertController from "controllers/alert_controller"
import AutoSubmitFormController from "controllers/auto_submit_form_controller"
import BulkSelectController from "controllers/bulk_select_controller"
import ColorThemeController from "controllers/color_theme_controller"
import CreditCardFormController from "controllers/credit_card_form_controller"
import DashboardSectionController from "controllers/dashboard_section_controller"
import DashboardSortableController from "controllers/dashboard_sortable_controller"
import DonutChartController from "controllers/donut_chart_controller"
import DsDisclosureController from "controllers/ds_disclosure_controller"
import ListFilterController from "controllers/list_filter_controller"
import LoadingButtonController from "controllers/loading_button_controller"
import MenuController from "controllers/menu_controller"
import MobileLayoutController from "controllers/mobile_layout_controller"
import PageSkeletonController from "controllers/page_skeleton_controller"
import PageTransitionController from "controllers/page_transition_controller"
import SankeyChartController from "controllers/sankey_chart_controller"
import SelectController from "controllers/select_controller"
import BudgetGaugeController from "controllers/budget_gauge_controller"
import CategoryDonutChartController from "controllers/category_donut_chart_controller"
import TrendLineChartController from "controllers/trend_line_chart_controller"
import SparklineChartController from "controllers/sparkline_chart_controller"
import StaggerListController from "controllers/stagger_list_controller"
import ThemeController from "controllers/theme_controller"
import TimeSeriesChartController from "controllers/time_series_chart_controller"
import TooltipController from "controllers/tooltip_controller"
import AccountSortController from "controllers/account_sort_controller"

// Register controllers
application.register("alert--dismissible", AlertController)
application.register("auto-submit-form", AutoSubmitFormController)
application.register("bulk-select", BulkSelectController)
application.register("color-theme", ColorThemeController)
application.register("credit-card-form", CreditCardFormController)
application.register("dashboard-section", DashboardSectionController)
application.register("dashboard-sortable", DashboardSortableController)
application.register("donut-chart", DonutChartController)
application.register("ds-disclosure", DsDisclosureController)
application.register("list-filter", ListFilterController)
application.register("loading-button", LoadingButtonController)
application.register("menu", MenuController)
application.register("mobile-layout", MobileLayoutController)
application.register("page-skeleton", PageSkeletonController)
application.register("page-transition", PageTransitionController)
application.register("sankey-chart", SankeyChartController)
application.register("select", SelectController)
application.register("budget-gauge", BudgetGaugeController)
application.register("category-donut-chart", CategoryDonutChartController)
application.register("trend-line-chart", TrendLineChartController)
application.register("sparkline-chart", SparklineChartController)
application.register("stagger-list", StaggerListController)
application.register("theme", ThemeController)
application.register("time-series-chart", TimeSeriesChartController)
application.register("tooltip", TooltipController)
application.register("account-sort", AccountSortController)
