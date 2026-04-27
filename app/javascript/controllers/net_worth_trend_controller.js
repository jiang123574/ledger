import LineChartController from "controllers/line_chart_controller"

// net_worth_trend 别名控制器
// 兼容旧数据格式: labels, netWorthData
// 转换为通用格式: datasets + segmentColors

export default class extends LineChartController {
  static values = {
    labels: Array,
    netWorthData: Array
  }

  // 监听旧格式数据变化
  netWorthDataValueChanged() {
    this.updateDatasets()
  }

  // 转换数据格式
  updateDatasets() {
    const netWorthData = this.netWorthDataValue || []

    if (netWorthData.length === 0) return

    // 转换为通用 datasets 格式
    this.datasetsValue = [
      {
        label: "净资产",
        data: netWorthData,
        colorVar: "--color-primary",
        fill: true
      }
    ]

    // 启用 segment colors 和 tooltip 变化值
    this.segmentColorsValue = true
    this.showLegendValue = false
    this.showChangeInTooltipValue = true
  }

  async connect() {
    // 先转换数据格式
    this.updateDatasets()
    // 调用父类 connect
    super.connect()
  }
}
