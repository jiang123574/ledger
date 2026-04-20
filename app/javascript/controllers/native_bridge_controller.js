import { Controller } from "@hotwired/stimulus"

// NativeBridge Controller
// 检测原生 App 环境并提供 JS ↔ 原生通信 API
//
// 用法：
//   <div data-controller="native-bridge">
//     <button data-action="native-bridge#share">分享</button>
//   </div>
//
// 全局检测：
//   import { NativeApp } from "controllers/native_bridge_controller"
//   if (NativeApp.isNative) { ... }
//
// Android 端通过 window.LedgerNative 注入接口

export const NativeApp = {
  get isNative() {
    return typeof window.LedgerNative !== "undefined" && window.LedgerNative?.isNativeApp?.()
  },

  get version() {
    return window.LedgerNative?.getAppVersion?.() || null
  },

  share(title, text) {
    if (!this.isNative) return false
    window.LedgerNative.share(title, text)
    return true
  },

  pickFile(accept = "*/*") {
    if (!this.isNative) return false
    window.LedgerNative.pickFile(accept)
    return true
  },

  pickImage() {
    if (!this.isNative) return false
    window.LedgerNative.pickImage()
    return true
  },

  requestBiometric() {
    if (!this.isNative) return false
    window.LedgerNative.requestBiometric()
    return true
  },

  // 监听原生事件
  onFileSelected(callback) {
    window.addEventListener("native:file-selected", (e) => callback(e.detail))
  },

  onBiometricResult(callback) {
    window.addEventListener("native:biometric", (e) => callback(e.detail))
  },

  onShareResult(callback) {
    window.addEventListener("native:share-result", (e) => callback(e.detail))
  }
}

export default class extends Controller {
  static targets = ["shareBtn", "fileInput"]
  static values = {
    shareTitle: String,
    shareText: String,
    fileAccept: { type: String, default: "*/*" }
  }

  connect() {
    if (NativeApp.isNative) {
      this.element.classList.add("native-app")
      this.element.dataset.nativeApp = "true"

      // 显示原生专属元素（分享按钮等）
      if (this.hasShareBtnTarget) {
        this.shareBtnTarget.classList.remove("hidden")
        this.shareBtnTarget.classList.add("inline-flex")
      }
    }
  }

  // 分享当前页面/内容
  share() {
    const title = this.shareTitleValue || document.title
    const text = this.shareTextValue || window.location.href

    if (!NativeApp.share(title, text)) {
      // Fallback: Web Share API
      if (navigator.share) {
        navigator.share({ title, text, url: window.location.href })
      } else {
        // 最终 fallback: 复制链接
        navigator.clipboard?.writeText(window.location.href)
        this.showToast("链接已复制")
      }
    }
  }

  // 使用原生文件选择器
  pickFile() {
    if (!NativeApp.pickFile(this.fileAcceptValue)) {
      // Fallback: 标准 input[type=file]
      this.fileInputTarget?.click()
    }
  }

  // 使用原生图片选择器
  pickImage() {
    if (!NativeApp.pickImage()) {
      this.fileInputTarget?.click()
    }
  }

  // Toast 提示
  showToast(message) {
    const toast = document.createElement("div")
    toast.className = "fixed bottom-20 left-1/2 -translate-x-1/2 px-4 py-2 bg-gray-800 text-white text-sm rounded-lg z-[100] animate-fade-in"
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => toast.remove(), 2000)
  }
}