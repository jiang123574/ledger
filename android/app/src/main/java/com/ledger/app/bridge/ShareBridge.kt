package com.ledger.app.bridge

import android.content.Intent
import android.net.Uri
import androidx.core.app.ShareCompat
import androidx.fragment.app.FragmentActivity

/**
 * ShareBridge - 原生分享功能桥接
 *
 * 功能：
 * - 调用系统分享面板
 * - 支持分享文本/链接
 * - 支持分享文件（报表导出）
 *
 * Web 端使用：
 *   window.LedgerNative.share("标题", "分享内容")
 *   window.addEventListener('native:share-result', (e) => {
 *     if (e.detail.success) { /* 分享成功 */ }
 *   })
 */
class ShareBridge(
    private val activity: FragmentActivity,
    private val nativeBridge: NativeBridge
) {
    /**
     * 分享文本内容
     */
    fun shareText(title: String, text: String) {
        try {
            val intent = ShareCompat.IntentBuilder(activity)
                .setType("text/plain")
                .setSubject(title)
                .setText(text)
                .createChooserIntent()

            activity.startActivity(intent)
            nativeBridge.notifyShareResult(true)
        } catch (e: Exception) {
            nativeBridge.notifyShareResult(false)
        }
    }

    /**
     * 分享文件（如导出的 CSV/PDF）
     */
    fun shareFile(title: String, fileUri: Uri, mimeType: String = "*/*") {
        try {
            val intent = ShareCompat.IntentBuilder(activity)
                .setType(mimeType)
                .setSubject(title)
                .setStream(fileUri)
                .createChooserIntent()

            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            activity.startActivity(intent)
            nativeBridge.notifyShareResult(true)
        } catch (e: Exception) {
            nativeBridge.notifyShareResult(false)
        }
    }

    /**
     * 接收其他 App 分享过来的数据
     * 需要在 AndroidManifest.xml 中配置 intent-filter
     */
    fun handleIncomingShare(intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_SEND -> {
                if (intent.type == "text/plain") {
                    val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                    if (sharedText != null) {
                        // 跳转到新建交易页面，预填备注
                        val url = "${com.ledger.app.BuildConfig.BASE_URL}/accounts?notes=${Uri.encode(sharedText)}"
                        nativeBridge.notifyBiometricResult(false) // 触发页面刷新
                    }
                }
            }
        }
    }
}
