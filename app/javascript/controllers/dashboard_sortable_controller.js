import { Controller } from "@hotwired/stimulus";

// Dashboard Sortable - Drag-and-drop section reordering with localStorage persistence
export default class extends Controller {
  static targets = ["section"];
  static values = {
    holdDelay: { type: Number, default: 150 }
  };

  connect() {
    this.draggedElement = null;
    this.placeholder = null;
    this.touchStartY = 0;
    this.currentTouchX = 0;
    this.currentTouchY = 0;
    this.isTouching = false;
    this.keyboardGrabbedElement = null;
    this.holdTimer = null;
    this.holdActivated = false;

    // Disable drag on mobile/tablet (< lg breakpoint)
    if (window.innerWidth < 1024) {
      this.sectionTargets.forEach((section) => {
        section.setAttribute("draggable", "false");
      });
    }

    // Restore order from localStorage
    this.restoreOrder();
  }

  isMobile() {
    return window.innerWidth < 1024;
  }

  // ===== Mouse Drag Events =====
  dragStart(event) {
    this.draggedElement = event.currentTarget;
    this.draggedElement.classList.add("opacity-50");
    this.draggedElement.setAttribute("aria-grabbed", "true");
    event.dataTransfer.effectAllowed = "move";
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("opacity-50");
    event.currentTarget.setAttribute("aria-grabbed", "false");
    this.clearPlaceholders();
  }

  dragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = "move";

    const afterElement = this.getDragAfterElement(event.clientX, event.clientY);
    const container = this.element;

    this.clearPlaceholders();

    if (afterElement == null) {
      this.showPlaceholder(container.lastElementChild, "after");
    } else {
      this.showPlaceholder(afterElement, "before");
    }
  }

  drop(event) {
    event.preventDefault();
    event.stopPropagation();

    const afterElement = this.getDragAfterElement(event.clientX, event.clientY);
    const container = this.element;

    if (afterElement == null) {
      container.appendChild(this.draggedElement);
    } else {
      container.insertBefore(this.draggedElement, afterElement);
    }

    this.clearPlaceholders();
    this.saveOrder();
  }

  // ===== Touch Events =====
  touchStart(event) {
    if (this.isMobile()) return;

    const section = event.currentTarget.closest("[data-dashboard-sortable-target='section']");
    if (!section) return;

    if (section.getAttribute("draggable") === "false") return;

    this.pendingSection = section;
    this.touchStartX = event.touches[0].clientX;
    this.touchStartY = event.touches[0].clientY;
    this.currentTouchX = this.touchStartX;
    this.currentTouchY = this.touchStartY;
    this.holdActivated = false;

    this.holdTimer = setTimeout(() => {
      this.activateDrag();
    }, this.holdDelayValue);
  }

  activateDrag() {
    if (!this.pendingSection) return;

    this.holdActivated = true;
    this.isTouching = true;
    this.draggedElement = this.pendingSection;
    this.draggedElement.classList.add("opacity-50", "scale-[1.02]");
    this.draggedElement.setAttribute("aria-grabbed", "true");

    if (navigator.vibrate) {
      navigator.vibrate(30);
    }
  }

  touchMove(event) {
    if (this.isMobile()) return;
    if (!this.holdActivated || !this.isTouching || !this.draggedElement) return;

    event.preventDefault();
    this.currentTouchX = event.touches[0].clientX;
    this.currentTouchY = event.touches[0].clientY;

    const afterElement = this.getDragAfterElement(this.currentTouchX, this.currentTouchY);
    this.clearPlaceholders();

    if (afterElement == null) {
      this.showPlaceholder(this.element.lastElementChild, "after");
    } else {
      this.showPlaceholder(afterElement, "before");
    }
  }

  touchEnd() {
    if (this.isMobile()) {
      this.cancelHold();
      return;
    }

    this.cancelHold();

    if (!this.holdActivated || !this.isTouching || !this.draggedElement) {
      this.resetTouchState();
      return;
    }

    const afterElement = this.getDragAfterElement(this.currentTouchX, this.currentTouchY);
    const container = this.element;

    if (afterElement == null) {
      container.appendChild(this.draggedElement);
    } else {
      container.insertBefore(this.draggedElement, afterElement);
    }

    this.draggedElement.classList.remove("opacity-50", "scale-[1.02]");
    this.draggedElement.setAttribute("aria-grabbed", "false");
    this.clearPlaceholders();
    this.saveOrder();

    this.resetTouchState();
  }

  cancelHold() {
    if (this.holdTimer) {
      clearTimeout(this.holdTimer);
      this.holdTimer = null;
    }
  }

  resetTouchState() {
    this.isTouching = false;
    this.draggedElement = null;
    this.pendingSection = null;
    this.holdActivated = false;
  }

  // ===== Keyboard Navigation =====
  handleKeyDown(event) {
    const currentSection = event.currentTarget;

    switch (event.key) {
      case "ArrowUp":
        event.preventDefault();
        if (this.keyboardGrabbedElement === currentSection) {
          this.moveUp(currentSection);
        }
        break;
      case "ArrowDown":
        event.preventDefault();
        if (this.keyboardGrabbedElement === currentSection) {
          this.moveDown(currentSection);
        }
        break;
      case "Enter":
      case " ":
        event.preventDefault();
        this.toggleGrabMode(currentSection);
        break;
      case "Escape":
        if (this.keyboardGrabbedElement) {
          event.preventDefault();
          this.releaseKeyboardGrab();
        }
        break;
    }
  }

  toggleGrabMode(section) {
    if (this.keyboardGrabbedElement === section) {
      this.releaseKeyboardGrab();
    } else {
      this.grabWithKeyboard(section);
    }
  }

  grabWithKeyboard(section) {
    if (this.keyboardGrabbedElement) {
      this.releaseKeyboardGrab();
    }

    this.keyboardGrabbedElement = section;
    section.setAttribute("aria-grabbed", "true");
    section.classList.add("ring-2", "ring-blue-500", "ring-offset-2");
  }

  releaseKeyboardGrab() {
    if (this.keyboardGrabbedElement) {
      this.keyboardGrabbedElement.setAttribute("aria-grabbed", "false");
      this.keyboardGrabbedElement.classList.remove(
        "ring-2",
        "ring-blue-500",
        "ring-offset-2"
      );
      this.keyboardGrabbedElement = null;
      this.saveOrder();
    }
  }

  moveUp(section) {
    const previousSibling = section.previousElementSibling;
    if (previousSibling?.hasAttribute("data-section-key")) {
      this.element.insertBefore(section, previousSibling);
      section.focus();
    }
  }

  moveDown(section) {
    const nextSibling = section.nextElementSibling;
    if (nextSibling?.hasAttribute("data-section-key")) {
      this.element.insertBefore(nextSibling, section);
      section.focus();
    }
  }

  // ===== Helper Methods =====
  getDragAfterElement(pointerX, pointerY) {
    const draggableElements = this.sectionTargets.filter(
      (section) => section !== this.draggedElement
    );

    if (draggableElements.length === 0) return null;

    let closest = null;
    let minDistance = Number.POSITIVE_INFINITY;

    draggableElements.forEach((child) => {
      const rect = child.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;

      const dx = pointerX - centerX;
      const dy = pointerY - centerY;
      const distance = Math.sqrt(dx * dx + dy * dy);

      if (distance < minDistance) {
        minDistance = distance;
        closest = child;
      }
    });

    return closest;
  }

  showPlaceholder(element, position) {
    if (!element) return;

    if (position === "before") {
      element.classList.add("border-t-4", "border-blue-500");
    } else {
      element.classList.add("border-b-4", "border-blue-500");
    }
  }

  clearPlaceholders() {
    this.sectionTargets.forEach((section) => {
      section.classList.remove(
        "border-t-4",
        "border-b-4",
        "border-blue-500"
      );
    });
  }

  // ===== Persistence =====
  saveOrder() {
    const order = this.sectionTargets.map(
      (section) => section.dataset.sectionKey
    );
    localStorage.setItem("dashboard_section_order", JSON.stringify(order));
  }

  restoreOrder() {
    const savedOrder = localStorage.getItem("dashboard_section_order");
    if (!savedOrder) return;

    try {
      const order = JSON.parse(savedOrder);
      const container = this.element;

      order.forEach((key) => {
        const section = this.sectionTargets.find(
          (s) => s.dataset.sectionKey === key
        );
        if (section) {
          container.appendChild(section);
        }
      });
    } catch (e) {
      console.error("Failed to restore dashboard section order:", e);
    }
  }
}