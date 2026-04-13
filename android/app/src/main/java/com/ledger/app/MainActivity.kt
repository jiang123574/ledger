package com.ledger.app

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.webkit.WebView
import androidx.appcompat.app.AppCompatActivity
import androidx.navigation.fragment.NavHostFragment
import androidx.navigation.ui.setupWithNavController
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.ledger.app.bridge.BiometricBridge
import com.ledger.app.bridge.FilePickerBridge
import com.ledger.app.bridge.NativeBridge
import com.ledger.app.bridge.ShareBridge
import com.ledger.app.turbo.TurboWebViewFragment

/**
 * MainActivity - Ledger Android App 主入口
 *
 * 架构：
 * - Jetpack Navigation 管理底部 Tab 导航
 * - Turbo Native 渲染 Rails 页面
 * - NativeBridge 提供 JS ↔ 原生双向通信
 * - BiometricBridge / FilePickerBridge / ShareBridge 提供原生功能
 */
class MainActivity : AppCompatActivity(), NativeBridge.BridgeCallbacks {

    lateinit var nativeBridge: NativeBridge
        private set
    private lateinit var biometricBridge: BiometricBridge
    private lateinit var filePickerBridge: FilePickerBridge
    private lateinit var shareBridge: ShareBridge

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        setupNavigation()
        setupBridges()
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        intent?.let { handleIncomingIntent(it) }
    }

    private fun setupNavigation() {
        val navHostFragment = supportFragmentManager
            .findFragmentById(R.id.nav_host_fragment) as NavHostFragment
        val navController = navHostFragment.navController

        val bottomNav = findViewById<BottomNavigationView>(R.id.bottom_navigation)
        bottomNav.setupWithNavController(navController)
    }

    private fun setupBridges() {
        // Bridge 初始化在 WebView 就绪后完成
        // 通过 TurboWebViewFragment 回调注入
    }

    /**
     * 由 TurboWebViewFragment 在 WebView 就绪时调用
     */
    fun attachBridgesToWebView(webView: WebView) {
        nativeBridge = NativeBridge(this, webView, this)
        biometricBridge = BiometricBridge(this, nativeBridge)
        filePickerBridge = FilePickerBridge(this, webView)
        shareBridge = ShareBridge(this, nativeBridge)

        // 注入 JS Bridge
        webView.addJavascriptInterface(nativeBridge, NativeBridge.JS_INTERFACE_NAME)

        // 设置 WebChromeClient 以拦截 input[type=file]
        webView.webChromeClient = filePickerBridge.createWebChromeClient()
    }

    // ============================================================
    // NativeBridge.BridgeCallbacks 实现
    // ============================================================

    override fun onBiometricRequested() {
        biometricBridge.authenticate()
    }

    override fun onShareRequested(title: String, text: String) {
        shareBridge.shareText(title, text)
    }

    override fun onFilePickRequested(accept: String) {
        filePickerBridge.pickFile(accept)
    }

    override fun onImagePickRequested() {
        filePickerBridge.pickImage()
    }

    // ============================================================
    // Deep Link 处理
    // ============================================================

    private fun handleIncomingIntent(intent: Intent) {
        // 处理 FCM 通知点击的 deep_link
        val deepLink = intent.getStringExtra("deep_link")
        if (deepLink != null) {
            navigateToUrl(deepLink)
        }

        // 处理系统分享
        if (intent.action == Intent.ACTION_SEND) {
            shareBridge.handleIncomingShare(intent)
        }
    }

    private fun navigateToUrl(url: String) {
        // 通知当前活跃的 Fragment 导航到指定 URL
        val currentFragment = supportFragmentManager
            .findFragmentById(R.id.nav_host_fragment)
            ?.childFragmentManager
            ?.fragments
            ?.firstOrNull()

        if (currentFragment is TurboWebViewFragment) {
            currentFragment.visit(url)
        }
    }

    /**
     * 返回键处理 - 让 Turbo 处理 WebView 内的导航历史
     */
    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        val currentFragment = supportFragmentManager
            .findFragmentById(R.id.nav_host_fragment)
            ?.childFragmentManager
            ?.fragments
            ?.firstOrNull()

        if (currentFragment is TurboWebViewFragment && currentFragment.canGoBack()) {
            currentFragment.goBack()
        } else {
            super.onBackPressed()
        }
    }
}
