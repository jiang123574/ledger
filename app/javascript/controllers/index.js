// Import and register all Stimulus controllers
import { application } from "controllers/application"

// Import controllers
import AlertController from "controllers/alert_controller"
import DashboardSectionController from "controllers/dashboard_section_controller"
import DashboardSortableController from "controllers/dashboard_sortable_controller"
import ListFilterController from "controllers/list_filter_controller"
import MenuController from "controllers/menu_controller"
import MobileLayoutController from "controllers/mobile_layout_controller"
import SelectController from "controllers/select_controller"
import TooltipController from "controllers/tooltip_controller"

// Register controllers
application.register("alert--dismissible", AlertController)
application.register("dashboard-section", DashboardSectionController)
application.register("dashboard-sortable", DashboardSortableController)
application.register("list-filter", ListFilterController)
application.register("menu", MenuController)
application.register("mobile-layout", MobileLayoutController)
application.register("select", SelectController)
application.register("tooltip", TooltipController)