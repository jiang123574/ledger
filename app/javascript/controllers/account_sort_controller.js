import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { updateUrl: String }

  connect() {
    this.draggedElement = null
    this.placeholderElement = null
    this.cloneElement = null      // 拖拽时的克隆元素（跟随鼠标）
    this.startY = 0               // 初始指针 Y 坐标
    this.initialTop = 0           // 被拖元素的初始 offsetTop
    this.currentIndex = -1        // 被拖元素在列表中的原始位置
    this.siblings = []            // 同组所有可排序子元素
    this._boundPointerDown = this._onPointerDown.bind(this)
    this._boundPointerMove = this._onPointerMove.bind(this)
    this._boundPointerUp = this._onPointerUp.bind(this)

    // 委托绑定到容器，避免 N 个元素各自监听
    this.element.addEventListener("pointerdown", this._boundPointerDown)
  }

  // ========== Pointer Event 拖拽（比 HTML5 DnD 快得多）==========

  _onPointerDown(event) {
    const item = event.target.closest("[data-account-id]")
    if (!item || event.button !== 0) return // 只响应左键

    // 避免选中文字
    event.preventDefault()
    item.setPointerCapture(event.pointerId)

    this.draggedElement = item
    this.startY = event.clientY
    this.startX = event.clientX
    this.currentIndex = [...item.parentNode.children].indexOf(item)
    this.siblings = [...item.parentNode.children].filter(el => el.hasAttribute("data-account-id"))

    // 创建克隆元素作为拖拽幽灵（绝对定位，不影响布局）
    const rect = item.getBoundingClientRect()
    this.cloneElement = item.cloneNode(true)
    this.cloneElement.classList.add("account-drag-clone")
    this._cloneOffsetX = event.clientX - rect.left // 指针相对 clone 左上角的偏移
    this._cloneOffsetY = event.clientY - rect.top
    this.cloneElement.style.cssText = `
      position: fixed;
      top: ${rect.top}px;
      left: ${rect.left}px;
      width: ${rect.width}px;
      height: ${rect.height}px;
      z-index: 9999;
      pointer-events: none;
      margin: 0;
      opacity: 0.9;
      box-shadow: 0 8px 30px rgba(0,0,0,0.15);
      transition: none !important;
    `
    document.body.appendChild(this.cloneElement)

    // 原元素变为 placeholder（保留空间）
    item.classList.add("account-drag-placeholder")

    // 绑定 move/up 到 document（防止移出元素后丢失事件）
    document.addEventListener("pointermove", this._boundPointerMove, { passive: false })
    document.addEventListener("pointerup", this._boundPointerUp)
    document.addEventListener("pointercancel", this._boundPointerUp)

    // 设置拖拽中状态
    document.body.classList.add("account-sorting")
  }

  _onPointerMove(event) {
    if (!this.draggedElement || !this.cloneElement) return

    // 用绝对定位 + 偏移量跟随指针（无累积误差）
    this.cloneElement.style.left = (event.clientX - this._cloneOffsetX) + "px"
    this.cloneElement.style.top = (event.clientY - this._cloneOffsetY) + "px"

    // 确定当前位置下方的目标元素
    const clientX = event.clientX
    const clientY = event.clientY
    this.cloneElement.style.display = "none"
    const elemBelow = document.elementFromPoint(clientX, clientY)
    this.cloneElement.style.display = ""

    const target = elemBelow?.closest("[data-account-id]")
    if (target && target !== this.draggedElement && target.parentNode === this.draggedElement.parentNode) {
      this._swapElements(target)
    }
  }

  _onPointerUp(event) {
    if (!this.draggedElement) return

    // 清理 clone 和 placeholder
    if (this.cloneElement) {
      this.cloneElement.remove()
      this.cloneElement = null
    }

    this.draggedElement.classList.remove("account-drag-placeholder")
    document.body.classList.remove("account-sorting")

    // 解绑全局事件
    document.removeEventListener("pointermove", this._boundPointerMove)
    document.removeEventListener("pointerup", this._boundPointerUp)
    document.removeEventListener("pointercancel", this._boundPointerUp)

    // 安全清除所有残留的蓝色边框标记
    this._clearAllPlaceholders()

    // 计算最终位置是否变化
    const newIndex = [...this.draggedElement.parentNode.children]
      .filter(el => el.hasAttribute("data-account-id"))
      .indexOf(this.draggedElement)

    if (newIndex !== this.currentIndex && newIndex >= 0 && this.siblings[newIndex]) {
      const draggedId = this.draggedElement.dataset.accountId
      const targetId = this.siblings[newIndex].dataset.accountId
      if (draggedId !== targetId) {
        this.updateOrder(draggedId, targetId)
      }
    }

    this.draggedElement = null
    this.siblings = []
    this.placeholderElement = null
  }

  // 在 DOM 中交换两个元素的位置
  _swapElements(target) {
    if (target === this.placeholderElement) return

    // 清除之前的 placeholder 标记
    this._clearPlaceholder()

    // 根据被拖元素与目标的当前相对位置决定插入方向
    // 如果被拖元素在目标上方 → 插到目标后面（下方），反之亦然
    const siblings = [...this.draggedElement.parentNode.children]
      .filter(el => el.hasAttribute("data-account-id"))
    const draggedIndex = siblings.indexOf(this.draggedElement)
    const targetIndex = siblings.indexOf(target)
    const isDraggedAboveTarget = draggedIndex < targetIndex

    if (isDraggedAboveTarget) {
      // 被拖元素在目标上方，向下拖 → 放在目标后面
      this.draggedElement.parentNode.insertBefore(this.draggedElement, target.nextSibling)
    } else {
      // 被拖元素在目标下方，向上拖 → 放在目标前面（上方）
      this.draggedElement.parentNode.insertBefore(this.draggedElement, target)
    }

    target.classList.add("border-t-2", "border-blue-500")
    this.placeholderElement = target
  }

  _clearPlaceholder() {
    if (this.placeholderElement) {
      this.placeholderElement.classList.remove("border-t-2", "border-blue-500")
      this.placeholderElement = null
    }
  }

  // 安全清理：移除容器内所有可能残留的蓝色标记
  _clearAllPlaceholders() {
    if (this.element) {
      this.element.querySelectorAll(".border-blue-500").forEach(el => {
        el.classList.remove("border-t-2", "border-blue-500")
      })
    }
    this.placeholderElement = null
  }

  updateOrder(draggedId, targetId) {
    fetch(`/accounts/${draggedId}/reorder`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
      },
      body: JSON.stringify({ target_id: targetId })
    }).catch(err => console.error('Failed to update order:', err))
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this._boundPointerDown)
    document.removeEventListener("pointermove", this._boundPointerMove)
    document.removeEventListener("pointerup", this._boundPointerUp)
    document.removeEventListener("pointercancel", this._boundPointerUp)

    if (this.cloneElement) this.cloneElement.remove()
    if (this.draggedElement) this.draggedElement.classList.remove("account-drag-placeholder")
    document.body.classList.remove("account-sorting")
    this._clearAllPlaceholders()
  }
}
