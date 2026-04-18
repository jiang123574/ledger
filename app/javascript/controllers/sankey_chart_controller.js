import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chart"]
  static values = {
    data: Object,
    height: Number
  }

  connect() {
    requestAnimationFrame(() => this.draw())
    this.resizeObserver = new ResizeObserver(() => this.draw())
    this.resizeObserver.observe(this.element)
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
  }

  dataValueChanged() {
    requestAnimationFrame(() => this.draw())
  }

  getColors() {
    const style = getComputedStyle(document.documentElement)
    return {
      income: style.getPropertyValue('--color-income').trim() || '#ef4444',
      expense: style.getPropertyValue('--color-expense').trim() || '#22c55e',
      incomeRgb: style.getPropertyValue('--color-income-rgb').trim() || '239, 68, 68',
      expenseRgb: style.getPropertyValue('--color-expense-rgb').trim() || '34, 197, 94'
    }
  }

  draw() {
    const chart = this.chartTarget
    if (!chart) return

    const data = this.dataValue
    if (!data || !data.nodes || !data.links || data.nodes.length === 0) {
      chart.innerHTML = '<text x="50%" y="50%" text-anchor="middle" fill="#6c757d">暂无数据</text>'
      return
    }

    const colors = this.getColors()
    const nodes = data.nodes
    const links = data.links

    const incomeNodes = nodes.filter(n => n.type === "income")
    const expenseNodes = nodes.filter(n => n.type === "expense")
    const centerNodes = nodes.filter(n => n.type === "center_income" || n.type === "center_expense")

    const width = chart.clientWidth || 600
    const height = this.heightValue || 400
    const padding = { top: 20, right: 100, bottom: 20, left: 100 }

    chart.setAttribute("viewBox", `0 0 ${width} ${height}`)
    chart.innerHTML = ""

    const availableHeight = height - padding.top - padding.bottom
    const minNodeHeight = 6
    const nodePadding = 3

    const nodePositions = {}

    const totalIncome = links.filter(l => l.type === "income").reduce((s, l) => s + l.value, 0)
    const totalExpense = links.filter(l => l.type === "expense").reduce((s, l) => s + l.value, 0)

    const layoutColumnProportional = (nodeList, x, linkType) => {
      const columnLinks = links.filter(l => l.type === linkType)
      const columnTotal = columnLinks.reduce((s, l) => s + l.value, 0)
      
      if (nodeList.length === 0) return
      
      const nodeCount = nodeList.length
      const totalPadding = (nodeCount - 1) * nodePadding
      const maxAvailableForNodes = availableHeight - totalPadding
      
      const proportions = nodeList.map((node) => {
        const link = linkType === "income" 
          ? columnLinks.find(l => l.source === node.name)
          : columnLinks.find(l => l.target === node.name)
        const amount = link ? link.value : 0
        return columnTotal > 0 ? amount / columnTotal : (1 / nodeCount)
      })

      let rawHeights = proportions.map(p => p * maxAvailableForNodes)
      
      const minTotalHeight = nodeCount * minNodeHeight
      const rawTotal = rawHeights.reduce((s, h) => s + h, 0)
      
      if (rawTotal < minTotalHeight) {
        rawHeights = rawHeights.map(() => minNodeHeight)
      } else if (rawTotal > maxAvailableForNodes) {
        const scale = maxAvailableForNodes / rawTotal
        rawHeights = rawHeights.map(h => h * scale)
      }

      rawHeights = rawHeights.map(h => Math.max(minNodeHeight, h))

      let actualTotal = rawHeights.reduce((s, h) => s + h, 0) + totalPadding
      if (actualTotal > availableHeight) {
        const scale = availableHeight / actualTotal
        rawHeights = rawHeights.map(h => h * scale)
        rawHeights = rawHeights.map(h => Math.max(minNodeHeight, h))
      }

      let currentY = padding.top
      nodeList.forEach((node, i) => {
        nodePositions[node.name] = { x, y: currentY, node, height: rawHeights[i] }
        currentY += rawHeights[i] + nodePadding
      })
    }

    layoutColumnProportional(incomeNodes, padding.left, "income")
    layoutColumnProportional(expenseNodes, width - padding.right, "expense")

    const maxTotal = Math.max(totalIncome, totalExpense, 1)
    const centerMaxHeight = availableHeight * 0.25
    
    const centerIncomeH = Math.max(minNodeHeight, Math.min(centerMaxHeight, (totalIncome / maxTotal) * centerMaxHeight))
    const centerExpenseH = Math.max(minNodeHeight, Math.min(centerMaxHeight, (totalExpense / maxTotal) * centerMaxHeight))

    const centerTotalHeight = centerIncomeH + centerExpenseH + nodePadding
    const centerStartY = padding.top + (availableHeight - centerTotalHeight) / 2

    nodePositions["总收入"] = {
      x: width / 2,
      y: centerStartY,
      node: centerNodes.find(n => n.name === "总收入"),
      height: centerIncomeH
    }

    nodePositions["总支出"] = {
      x: width / 2,
      y: centerStartY + centerIncomeH + nodePadding,
      node: centerNodes.find(n => n.name === "总支出"),
      height: centerExpenseH
    }

    nodes.forEach((node) => {
      const pos = nodePositions[node.name]
      if (!pos) return

      const nodeColor = node.type === "income" || node.type === "center_income"
        ? colors.income
        : colors.expense

      const h = pos.height || minNodeHeight

      const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect")
      rect.setAttribute("x", pos.x)
      rect.setAttribute("y", pos.y)
      rect.setAttribute("width", 10)
      rect.setAttribute("height", h)
      rect.setAttribute("fill", nodeColor)
      rect.setAttribute("rx", "1")
      chart.appendChild(rect)

      const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
      const isLeft = node.type === "income"
      label.setAttribute("x", isLeft ? pos.x - 4 : pos.x + 14)
      label.setAttribute("y", pos.y + h / 2 + 3)
      label.setAttribute("text-anchor", isLeft ? "end" : "start")
      label.setAttribute("fill", "currentColor")
      label.setAttribute("font-size", "9")
      label.setAttribute("font-weight", "500")
      label.textContent = node.name
      chart.appendChild(label)
    })

    const linkGroup = document.createElementNS("http://www.w3.org/2000/svg", "g")
    linkGroup.setAttribute("fill", "none")

    links.forEach((link) => {
      const sourcePos = nodePositions[link.source]
      const targetPos = nodePositions[link.target]
      if (!sourcePos || !targetPos) return

      const sourceH = sourcePos.height || minNodeHeight
      const targetH = targetPos.height || minNodeHeight

      const linkType = link.type === "income" ? "income" : (link.type === "expense" ? "expense" : "flow")
      const rgb = linkType === "income" || linkType === "flow" ? colors.incomeRgb : colors.expenseRgb

      const linkH = linkType === "income" ? sourceH : targetH

      const sourceY = sourcePos.y + sourceH / 2
      const targetY = targetPos.y + targetH / 2

      const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
      
      let d
      if (linkType === "flow") {
        const flowWidth = Math.min(sourceH, targetH)
        const offsetX = (10 - flowWidth) / 2
        d = `
          M ${sourcePos.x + offsetX} ${sourcePos.y + sourceH}
          L ${sourcePos.x + offsetX + flowWidth} ${sourcePos.y + sourceH}
          L ${sourcePos.x + offsetX + flowWidth} ${targetPos.y}
          L ${sourcePos.x + offsetX} ${targetPos.y}
          Z
        `
      } else {
        d = `
          M ${sourcePos.x + 10} ${sourceY - linkH / 2}
          C ${(sourcePos.x + targetPos.x) / 2} ${sourceY - linkH / 2},
            ${(sourcePos.x + targetPos.x) / 2} ${targetY - linkH / 2},
            ${targetPos.x} ${targetY - linkH / 2}
          L ${targetPos.x} ${targetY + linkH / 2}
          C ${(sourcePos.x + targetPos.x) / 2} ${targetY + linkH / 2},
            ${(sourcePos.x + targetPos.x) / 2} ${sourceY + linkH / 2},
            ${sourcePos.x + 10} ${sourceY + linkH / 2}
          Z
        `
      }
      path.setAttribute("d", d)
      path.setAttribute("fill", `rgba(${rgb}, 0.25)`)
      path.setAttribute("stroke", `rgba(${rgb}, 0.4)`)
      path.setAttribute("stroke-width", "1")
      path.style.transition = "fill 0.2s"
      
      path.addEventListener("mouseenter", () => {
        path.setAttribute("fill", `rgba(${rgb}, 0.4)`)
      })
      path.addEventListener("mouseleave", () => {
        path.setAttribute("fill", `rgba(${rgb}, 0.25)`)
      })
      
      linkGroup.appendChild(path)

      if (link.value >= 500) {
        const linkLabel = document.createElementNS("http://www.w3.org/2000/svg", "text")
        linkLabel.setAttribute("x", (sourcePos.x + targetPos.x) / 2)
        linkLabel.setAttribute("y", (sourceY + targetY) / 2 + 3)
        linkLabel.setAttribute("text-anchor", "middle")
        linkLabel.setAttribute("fill", "#6c757d")
        linkLabel.setAttribute("font-size", "8")
        linkLabel.textContent = `¥${link.value.toFixed(0)}`
        linkGroup.appendChild(linkLabel)
      }
    })

    chart.appendChild(linkGroup)
  }
}
