import { Controller } from "@hotwired/stimulus"

// NativeApp 全局工具对象
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

  share() {
    const title = this.shareTitleValue || document.title
    const text = this.shareTextValue || window.location.href

    if (!NativeApp.share(title, text)) {
      if (navigator.share) {
        navigator.share({ title, text, url: window.location.href })
      } else {
        navigator.clipboard?.writeText(window.location.href)
      }
    }
  }

  pickFile() {
    if (!NativeApp.pickFile(this.fileAcceptValue)) {
      this.fileInputTarget?.click()
    }
  }

  pickImage() {
    if (!NativeApp.pickImage()) {
      this.fileInputTarget?.click()
    }
  }
}
