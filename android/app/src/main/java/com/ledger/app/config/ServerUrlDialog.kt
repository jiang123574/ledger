package com.ledger.app.config

import android.content.Context
import android.text.InputType
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AlertDialog

/**
 * ServerUrlDialog - 首次启动弹窗，让用户输入服务器地址
 */
object ServerUrlDialog {

    /**
     * 显示服务器地址配置弹窗
     * @param onConfigured 配置完成后的回调
     */
    fun show(context: Context, currentUrl: String, onConfigured: (String) -> Unit) {
        val layout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(60, 40, 60, 0)
        }

        val hint = TextView(context).apply {
            text = "请输入 Ledger 服务器地址\n例如：http://192.168.1.100:3000/"
            textSize = 14f
        }
        layout.addView(hint)

        val input = EditText(context).apply {
            setText(currentUrl)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            setHint("http://YOUR_SERVER_IP:3000/")
            setSingleLine()
        }
        layout.addView(input)

        AlertDialog.Builder(context)
            .setTitle("服务器地址")
            .setView(layout)
            .setCancelable(false)
            .setPositiveButton("确定") { _, _ ->
                val url = input.text.toString().trim()
                if (url.isNotEmpty()) {
                    if (ServerConfig.isValidUrl(url)) {
                        ServerConfig.setBaseUrl(context, url)
                        onConfigured(url)
                    } else {
                        // URL 格式无效，显示错误提示
                        android.widget.Toast.makeText(
                            context,
                            "请输入有效的 URL（以 http:// 或 https:// 开头）",
                            android.widget.Toast.LENGTH_SHORT
                        ).show()
                    }
                }
            }
            .setNegativeButton("使用默认") { _, _ ->
                val defaultUrl = ServerConfig.getDefaultUrl()
                ServerConfig.setBaseUrl(context, defaultUrl)
                onConfigured(defaultUrl)
            }
            .show()
    }
}
