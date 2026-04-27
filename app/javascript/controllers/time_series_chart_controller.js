import MiniLineChartController from "controllers/mini_line_chart_controller"

// time_series_chart 别名控制器
// 兼容旧数据格式: data (对象数组 [{date, value}])
// 启用: tooltip交互、网格线

export default class extends MiniLineChartController {
  static values = {
    data: Array,
    period: String,
    height: { type: Number, default: 300 }
  }

  connect() {
    // 启用交互模式和网格线
    this.interactiveValue = true
    this.showGridValue = true
    this.showEndpointValue = false
    // 使用传入的 height 或默认值
    if (this.hasHeightValue) {
      this.heightValue = this.heightValue
    }
    super.connect()
  }
}
