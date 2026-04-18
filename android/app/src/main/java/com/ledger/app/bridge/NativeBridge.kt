package com.ledger.app.bridge

import android.webkit.JavascriptInterface
import android.webkit.WebView
import androidx.fragment.app.FragmentActivity
import org.json.JSONObject

/**
 * NativeBridge - 原生与 WebView 的 JS 通信桥梁
 *
 * Web 端通过 window.LedgerNative 调用原生功能：
 *
 * JavaScript 调用示例：
 *   // 检测是否为原生 App
 *   window.LedgerNative.isNativeApp()  // → true
 *
 *   // 获取 App 版本
 *   window.LedgerNative.getAppVersion()  // → "1.0.0"
 *
 *   // 触发生物识别登录
 *   window.LedgerNative.requestBiometric()
 *
 *   // 分享内容
 *   window.LedgerNative.share("标题", "内容")
 *
 *   // 选择文件（图片）
 *   window.LedgerNative.pickImage()
 *
 * 原生 → Web 通信通过 evaluateJavascript：
 *   webView.evaluateJavascript("window.dispatchEvent(new CustomEvent('native:biometric', {detail: {success: true}}))")
 */
class NativeBridge(
    private val activity: FragmentActivity,
    private val webView: WebView,
    private val callbacks: BridgeCallbacks
) {
    companion object {
        const val JS_INTERFACE_NAME = "LedgerNative"
    }

    interface BridgeCallbacks {
        fun onBiometricRequested()
        fun onShareRequested(title: String, text: String)
        fun onFilePickRequested(accept: String)
        fun onImagePickRequested()
    }

    @JavascriptInterface
    fun isNativeApp(): Boolean = true

    @JavascriptInterface
    fun getAppVersion(): String {
        return try {
            val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
            info.versionName ?: "1.0.0"
        } catch (e: Exception) {
            "1.0.0"
        }
    }

    @JavascriptInterface
    fun requestBiometric() {
        activity.runOnUiThread {
            callbacks.onBiometricRequested()
        }
    }

    @JavascriptInterface
    fun share(title: String, text: String) {
        activity.runOnUiThread {
            callbacks.onShareRequested(title, text)
        }
    }

    @JavascriptInterface
    fun pickFile(accept: String = "*/*") {
        activity.runOnUiThread {
            callbacks.onFilePickRequested(accept)
        }
    }

    @JavascriptInterface
    fun pickImage() {
        activity.runOnUiThread {
            callbacks.onImagePickRequested()
        }
    }

    // ============================================================
    // 原生 → JS 通信方法
    // ============================================================

    /**
     * 通知 Web 端生物识别结果
     */
    fun notifyBiometricResult(success: Boolean, error: String? = null) {
        val detail = JSONObject().apply {
            put("success", success)
            error?.let { put("error", it) }
        }
        evaluateJs("window.dispatchEvent(new CustomEvent('native:biometric', {detail: $detail}))")
    }

    /**
     * 通知 Web 端文件选择结果
     * @param base64Data 文件的 Base64 编码数据
     * @param fileName 文件名
     * @param mimeType MIME 类型
     */
    fun notifyFileSelected(base64Data: String, fileName: String, mimeType: String) {
        val detail = JSONObject().apply {
            put("data", base64Data)
            put("name", fileName)
            put("type", mimeType)
        }
        evaluateJs("window.dispatchEvent(new CustomEvent('native:file-selected', {detail: $detail}))")
    }

    /**
     * 通知 Web 端分享结果
     */
    fun notifyShareResult(success: Boolean) {
        val detail = JSONObject().apply {
            put("success", success)
        }
        evaluateJs("window.dispatchEvent(new CustomEvent('native:share-result', {detail: $detail}))")
    }

    private fun evaluateJs(script: String) {
        webView.evaluateJavascript(script, null)
    }
}
