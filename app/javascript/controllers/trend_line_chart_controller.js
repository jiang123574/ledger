import LineChartController from "controllers/line_chart_controller"

// trend_line_chart 别名控制器
// 兼容旧数据格式: labels, incomeData, expenseData
// 转换为通用格式: datasets

export default class extends LineChartController {
  static values = {
    labels: Array,
    incomeData: Array,
    expenseData: Array
  }

  // 监听旧格式数据变化
  incomeDataValueChanged() {
    this.updateDatasets()
  }

  expenseDataValueChanged() {
    this.updateDatasets()
  }

  // 转换数据格式
  updateDatasets() {
    const incomeData = this.incomeDataValue || []
    const expenseData = this.expenseDataValue || []

    if (incomeData.length === 0 && expenseData.length === 0) return

    // 转换为通用 datasets 格式
    this.datasetsValue = [
      {
        label: "收入",
        data: incomeData,
        colorVar: "--color-income",
        fill: true
      },
      {
        label: "支出",
        data: expenseData,
        colorVar: "--color-expense",
        fill: true
      }
    ]

    // 继承父类的配置
    this.segmentColorsValue = false
    this.showLegendValue = true
    this.showChangeInTooltipValue = false
  }

  async connect() {
    // 先转换数据格式
    this.updateDatasets()
    // 调用父类 connect
    super.connect()
  }
}
