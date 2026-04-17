package com.ledger.app.bridge

import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.util.Base64
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.FragmentActivity
import com.ledger.app.MainActivity
import java.io.InputStream

/**
 * FilePickerBridge - 原生文件选择器桥接
 *
 * 功能：
 * 1. 拦截 WebView 的 input[type=file] → 打开原生文件选择器
 * 2. 支持 JS Bridge 方式 pickImage/pickFile
 * 3. 将选择的文件转为 Base64 传回 WebView
 *
 * 使用方式：
 * - Web 端 input[type=file] 自动触发（通过 WebChromeClient）
 * - Web 端 JS 调用 window.LedgerNative.pickImage()
 */
class FilePickerBridge(
    private val activity: FragmentActivity,
    private val webView: WebView,
    private val filePickerLauncher: ActivityResultLauncher<Intent>,
    private val imagePickerLauncher: ActivityResultLauncher<Intent>
) {
    private var filePathCallback: ValueCallback<Array<Uri>>? = null
    private var jsCallbackFunction: String? = null

    /**
     * 创建兼容 WebView input[type=file] 的 WebChromeClient
     */
    fun createWebChromeClient(): WebChromeClient {
        return object : WebChromeClient() {
            override fun onShowFileChooser(
                view: WebView?,
                callback: ValueCallback<Array<Uri>>?,
                params: FileChooserParams?
            ): Boolean {
                filePathCallback?.onReceiveValue(null)
                filePathCallback = callback

                val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = params?.acceptTypes?.firstOrNull() ?: "*/*"
                    if (params?.mode == FileChooserParams.MODE_OPEN_MULTIPLE) {
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    }
                }

                return try {
                    filePickerLauncher.launch(Intent.createChooser(intent, "选择文件"))
                    true
                } catch (e: Exception) {
                    filePathCallback = null
                    false
                }
            }
        }
    }

    /**
     * JS Bridge 方式选择图片
     */
    fun pickImage() {
        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
        imagePickerLauncher.launch(intent)
    }

    /**
     * JS Bridge 方式选择文件
     */
    fun pickFile(accept: String = "*/*") {
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = accept
        }
        filePickerLauncher.launch(Intent.createChooser(intent, "选择文件"))
    }

    /**
     * 处理 WebChromeClient 的文件选择结果
     */
    fun handleFileResult(data: Intent?) {
        val uris = extractUris(data)
        filePathCallback?.onReceiveValue(uris)
        filePathCallback = null
    }

    /**
     * 处理 JS Bridge 的图片选择结果
     */
    fun handleImageResult(data: Intent?) {
        val uri = data?.data ?: return
        convertToBase64AndNotify(uri, "image/jpeg")
    }

    private fun extractUris(data: Intent?): Array<Uri>? {
        if (data == null) return null

        // 多选
        val clipData = data.clipData
        if (clipData != null) {
            val uris = mutableListOf<Uri>()
            for (i in 0 until clipData.itemCount) {
                uris.add(clipData.getItemAt(i).uri)
            }
            return uris.toTypedArray()
        }

        // 单选
        return data.data?.let { arrayOf(it) }
    }

    private fun convertToBase64AndNotify(uri: Uri, mimeType: String) {
        try {
            val inputStream: InputStream? = activity.contentResolver.openInputStream(uri)
            val bytes = inputStream?.readBytes() ?: return
            val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)

            val fileName = getFileName(uri)
            val nativeBridge = (activity as? MainActivity)?.nativeBridge
            nativeBridge?.notifyFileSelected(base64, fileName, mimeType)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getFileName(uri: Uri): String {
        var name = "file"
        activity.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex("_display_name")
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                name = cursor.getString(nameIndex) ?: "file"
            }
        }
        return name
    }
}
