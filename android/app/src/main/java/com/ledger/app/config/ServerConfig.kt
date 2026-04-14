package com.ledger.app.config

import android.content.Context
import android.content.SharedPreferences

/**
 * ServerConfig - 管理服务器地址配置
 *
 * 存储在 SharedPreferences，首次启动弹窗让用户输入，
 * 后续可在设置页面修改。
 */
object ServerConfig {
    private const val PREFS_NAME = "ledger_server"
    private const val KEY_BASE_URL = "base_url"
    private const val DEFAULT_URL = "http://192.168.10.232:3000/"

    private fun prefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    /**
     * 获取服务器地址（末尾保证有 /）
     */
    fun getBaseUrl(context: Context): String {
        val url = prefs(context).getString(KEY_BASE_URL, null) ?: DEFAULT_URL
        return if (url.endsWith("/")) url else "$url/"
    }

    /**
     * 保存服务器地址
     */
    fun setBaseUrl(context: Context, url: String) {
        val normalized = if (url.endsWith("/")) url else "$url/"
        prefs(context).edit().putString(KEY_BASE_URL, normalized).apply()
    }

    /**
     * 是否已配置过（非首次启动）
     */
    fun isConfigured(context: Context): Boolean {
        return prefs(context).contains(KEY_BASE_URL)
    }
}
