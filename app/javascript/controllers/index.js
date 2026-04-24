// Import and register all Stimulus controllers
import { application } from "controllers/application"

// Import controllers
import AlertController from "controllers/alert_controller"
import AutoSubmitFormController from "controllers/auto_submit_form_controller"
import BulkSelectController from "controllers/bulk_select_controller"
import ColorThemeController from "controllers/color_theme_controller"
import CreditCardFormController from "controllers/credit_card_form_controller"
import CreditBillEntriesController from "controllers/credit_bill_entries_controller"
import DashboardSectionController from "controllers/dashboard_section_controller"
import DashboardSortableController from "controllers/dashboard_sortable_controller"
import DonutChartController from "controllers/donut_chart_controller"
import DsDisclosureController from "controllers/ds_disclosure_controller"
import ListFilterController from "controllers/list_filter_controller"
import LoadingButtonController from "controllers/loading_button_controller"
import MenuController from "controllers/menu_controller"
import MobileLayoutController from "controllers/mobile_layout_controller"
import NativeBridgeController, { NativeApp } from "controllers/native_bridge_controller"
window.NativeApp = NativeApp
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
import StatsLoaderController from "controllers/stats_loader_controller"
import ChartVisibilityController from "controllers/chart_visibility_controller"
import ReportTabsController from "controllers/report_tabs_controller"
import AssetTrendChartController from "controllers/asset_trend_chart_controller"
import CategoryComparisonController from "controllers/category_comparison_controller"
import FilterPopoverController from "controllers/filter_popover_controller"
import EntryListController from "controllers/entry_list_controller"
import BillStatementController from "controllers/bill_statement_controller"
import BarChartController from "controllers/bar_chart_controller"
import CalendarHeatmapController from "controllers/calendar_heatmap_controller"
import NetWorthTrendController from "controllers/net_worth_trend_controller"
import WaterfallChartController from "controllers/waterfall_chart_controller"
import PageTransitionController from "controllers/page_transition_controller"
import CategoryStatsController from "controllers/category_stats_controller"
import PeriodPickerController from "controllers/period_picker_controller"
import CategoryFilterController from "controllers/category_filter_controller"
import ViewModeController from "controllers/view_mode_controller"
import AccountModalController from "controllers/account_modal_controller"
import AccountPageController from "controllers/account_page_controller"
import TransactionModalController from "controllers/transaction_modal_controller"
import SettleReceivableController from "controllers/settle_receivable_controller"
import ReceivableModalController from "controllers/receivable_modal_controller"
import FlashController from "controllers/flash_controller"

// Register controllers
application.register("alert--dismissible", AlertController)
application.register("auto-submit-form", AutoSubmitFormController)
application.register("bulk-select", BulkSelectController)
application.register("color-theme", ColorThemeController)
application.register("credit-card-form", CreditCardFormController)
application.register("credit-bill-entries", CreditBillEntriesController)
application.register("dashboard-section", DashboardSectionController)
application.register("dashboard-sortable", DashboardSortableController)
application.register("donut-chart", DonutChartController)
application.register("ds-disclosure", DsDisclosureController)
application.register("list-filter", ListFilterController)
application.register("loading-button", LoadingButtonController)
application.register("menu", MenuController)
application.register("mobile-layout", MobileLayoutController)
application.register("native-bridge", NativeBridgeController)
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
application.register("stats-loader", StatsLoaderController)
application.register("chart-visibility", ChartVisibilityController)
application.register("report-tabs", ReportTabsController)
application.register("asset-trend-chart", AssetTrendChartController)
application.register("category-comparison", CategoryComparisonController)
application.register("filter-popover", FilterPopoverController)
application.register("entry-list", EntryListController)
application.register("bill-statement", BillStatementController)
application.register("bar-chart", BarChartController)
application.register("calendar-heatmap", CalendarHeatmapController)
application.register("net-worth-trend", NetWorthTrendController)
application.register("waterfall-chart", WaterfallChartController)
application.register("page-transition", PageTransitionController)
application.register("category-stats", CategoryStatsController)
application.register("period-picker", PeriodPickerController)
application.register("category-filter", CategoryFilterController)
application.register("view-mode", ViewModeController)
application.register("account-modal", AccountModalController)
application.register("account-page", AccountPageController)
application.register("transaction-modal", TransactionModalController)
application.register("settle-receivable", SettleReceivableController)
application.register("receivable-modal", ReceivableModalController)
application.register("flash", FlashController)