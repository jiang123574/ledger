import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chart"]
  static values = {
    data: Object,
    height: Number
  }

  connect() {
    this.draw()
  }

  dataValueChanged() {
    this.draw()
  }

  draw() {
    const chart = this.chartTarget
    if (!chart) return

    const data = this.dataValue
    if (!data || !data.nodes || !data.links || data.nodes.length === 0) {
      chart.innerHTML = '<text x="50%" y="50%" text-anchor="middle" fill="#6c757d">暂无数据</text>'
      return
    }

    const width = chart.clientWidth || 600
    const height = this.heightValue || 400
    const padding = { top: 20, right: 120, bottom: 20, left: 20 }

    chart.setAttribute("viewBox", `0 0 ${width} ${height}`)
    chart.innerHTML = ""

    const nodes = data.nodes
    const links = data.links

    const nodeIndex = {}
    nodes.forEach((node, i) => { nodeIndex[node.name] = i })

    const sourceLinks = {}
    const targetLinks = {}
    links.forEach(link => {
      if (!sourceLinks[link.source]) sourceLinks[link.source] = []
      if (!targetLinks[link.target]) targetLinks[link.target] = []
      sourceLinks[link.source].push(link)
      targetLinks[link.target].push(link)
    })

    const nodeHeight = 30
    const nodePadding = 10
    const totalNodeHeight = nodes.length * (nodeHeight + nodePadding) - nodePadding
    const startY = (height - totalNodeHeight) / 2

    nodes.forEach((node, i) => {
      const nodeY = startY + i * (nodeHeight + nodePadding)
      const sourceTotal = (sourceLinks[node.name] || []).reduce((sum, l) => sum + l.value, 0)
      const targetTotal = (targetLinks[node.name] || []).reduce((sum, l) => sum + l.value, 0)
      const thickness = Math.max(Math.abs(sourceTotal - targetTotal), Math.abs(sourceTotal), Math.abs(targetTotal), 20)

      const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect")
      rect.setAttribute("x", padding.left)
      rect.setAttribute("y", nodeY)
      rect.setAttribute("width", 10)
      rect.setAttribute("height", nodeHeight)
      rect.setAttribute("fill", node.color || "#3b82f6")
      rect.setAttribute("rx", "2")
      chart.appendChild(rect)

      const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
      label.setAttribute("x", padding.left + 15)
      label.setAttribute("y", nodeY + nodeHeight / 2 + 4)
      label.setAttribute("fill", "#1a1a1a")
      label.setAttribute("font-size", "12")
      label.setAttribute("font-weight", "500")
      label.textContent = `${node.name} ¥${thickness.toFixed(0)}`
      chart.appendChild(label)
    })

    const linkGroup = document.createElementNS("http://www.w3.org/2000/svg", "g")
    linkGroup.setAttribute("fill", "none")

    links.forEach((link, linkIndex) => {
      const sourceNode = nodes.find(n => n.name === link.source)
      const targetNode = nodes.find(n => n.name === link.target)
      if (!sourceNode || !targetNode) return

      const sourceIndex = nodes.indexOf(sourceNode)
      const targetIndex = nodes.indexOf(targetNode)
      const sourceY = startY + sourceIndex * (nodeHeight + nodePadding)
      const targetY = startY + targetIndex * (nodeHeight + nodePadding)

      const linkHeight = Math.max(link.value / 100, 5)
      const midX = width / 2

      const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
      const d = `
        M ${padding.left + 10} ${sourceY + nodeHeight / 2 - linkHeight / 2}
        C ${midX} ${sourceY + nodeHeight / 2 - linkHeight / 2},
          ${midX} ${targetY + nodeHeight / 2 - linkHeight / 2},
          ${width - padding.right} ${targetY + nodeHeight / 2 - linkHeight / 2}
        L ${width - padding.right} ${targetY + nodeHeight / 2 + linkHeight / 2}
        C ${midX} ${targetY + nodeHeight / 2 + linkHeight / 2},
          ${midX} ${sourceY + nodeHeight / 2 + linkHeight / 2},
          ${padding.left + 10} ${sourceY + nodeHeight / 2 + linkHeight / 2}
        Z
      `
      path.setAttribute("d", d)
      path.setAttribute("fill", link.color || "rgba(59, 130, 246, 0.3)")
      path.setAttribute("stroke", link.color || "rgba(59, 130, 246, 0.5)")
      path.setAttribute("stroke-width", "1")
      path.style.transition = "fill 0.2s, stroke 0.2s"
      
      path.addEventListener("mouseenter", () => {
        path.setAttribute("fill", link.color || "rgba(59, 130, 246, 0.5)")
        path.setAttribute("stroke", link.color || "rgba(59, 130, 246, 0.8)")
      })
      path.addEventListener("mouseleave", () => {
        path.setAttribute("fill", link.color || "rgba(59, 130, 246, 0.3)")
        path.setAttribute("stroke", link.color || "rgba(59, 130, 246, 0.5)")
      })
      
      linkGroup.appendChild(path)

      const linkLabel = document.createElementNS("http://www.w3.org/2000/svg", "text")
      linkLabel.setAttribute("x", midX)
      linkLabel.setAttribute("y", (sourceY + targetY + nodeHeight) / 2 + 4)
      linkLabel.setAttribute("text-anchor", "middle")
      linkLabel.setAttribute("fill", "#6c757d")
      linkLabel.setAttribute("font-size", "10")
      linkLabel.textContent = `¥${link.value.toFixed(0)}`
      linkGroup.appendChild(linkLabel)
    })

    chart.appendChild(linkGroup)
  }
}
