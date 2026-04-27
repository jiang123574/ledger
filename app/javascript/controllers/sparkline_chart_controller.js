import MiniLineChartController from "controllers/mini_line_chart_controller"

// sparkline_chart 别名控制器
// 兼容旧数据格式: data (简单数组)
// 默认配置: 无交互、显示末尾点

export default class extends MiniLineChartController {
  // 直接继承，数据格式相同
  // 默认值已匹配: interactive=false, showEndpoint=true, showGrid=false
}
