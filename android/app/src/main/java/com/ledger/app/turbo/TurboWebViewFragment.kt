package com.ledger.app.turbo

import android.os.Bundle
import android.view.View
import dev.hotwire.turbo.errors.TurboVisitError
import dev.hotwire.turbo.fragments.TurboWebFragment
import dev.hotwire.turbo.nav.TurboNavGraphDestination
import com.ledger.app.BuildConfig
import com.ledger.app.MainActivity

/**
 * TurboWebViewFragment - Turbo Native WebView 容器
 *
 * 每个 Tab 使用一个独立的 TurboWebViewFragment 实例，
 * 加载对应的 Rails 页面，提供原生导航体验。
 *
 * 特性：
 * - 自动注入 Turbo Native User-Agent（Rails 端据此隐藏 Web 专属元素）
 * - 注入 JS Bridge（NativeBridge）用于原生功能调用
 * - 支持下拉刷新
 * - 支持 WebView 内前进后退
 * - Loading 状态指示
 */
@TurboNavGraphDestination(uri = "turbo://fragment/webview")
open class TurboWebViewFragment : TurboWebFragment() {

    // 每个子类需要覆盖此路径
    open val startLocation: String
        get() = BuildConfig.BASE_URL

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        configureWebView()
    }

    override fun onColdBootPageCompleted(location: String) {
        super.onColdBootPageCompleted(location)
        // Cold boot 完成后注入 Bridge
        attachBridge()
    }

    override fun onVisitStarted(location: String) {
        super.onVisitStarted(location)
    }

    override fun onVisitCompleted(location: String, completedOffline: Boolean) {
        super.onVisitCompleted(location, completedOffline)
    }

    override fun onVisitErrorReceived(location: String, error: TurboVisitError) {
        super.onVisitErrorReceived(location, error)
    }

    private fun configureWebView() {
        session.webView.apply {
            // 启用 JavaScript（Hotwire/Stimulus 依赖）
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true

            // 设置 User-Agent，Rails 端据此检测 Turbo Native
            settings.userAgentString = buildUserAgent(settings.userAgentString)

            // 启用缩放（报表页面可能需要）
            settings.setSupportZoom(true)
            settings.builtInZoomControls = true
            settings.displayZoomControls = false

            // 混合内容（开发环境 HTTP 加载 HTTPS 资源）
            settings.mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
        }
    }

    /**
     * 将 Bridge 注入到当前 WebView
     */
    private fun attachBridge() {
        val webView = session.webView
        (activity as? MainActivity)?.attachBridgesToWebView(webView)
    }

    private fun buildUserAgent(defaultUA: String): String {
        return "$defaultUA Turbo Native/${BuildConfig.VERSION_NAME}"
    }

    /**
     * 导航到指定 URL
     */
    fun visit(url: String) {
        session.webView.loadUrl(url)
    }

    /**
     * 是否可以后退（WebView 历史）
     */
    fun canGoBack(): Boolean {
        return session.webView.canGoBack()
    }

    /**
     * 后退一步
     */
    fun goBack() {
        session.webView.goBack()
    }
}
