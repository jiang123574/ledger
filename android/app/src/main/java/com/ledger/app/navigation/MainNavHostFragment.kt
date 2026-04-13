package com.ledger.app.navigation

import dev.hotwire.turbo.config.TurboPathConfiguration
import dev.hotwire.turbo.session.TurboSessionNavHostFragment
import com.ledger.app.BuildConfig

/**
 * MainNavHostFragment - Turbo Session 导航宿主
 *
 * 管理所有 Tab 的 Turbo Session：
 * - 配置路径解析规则
 * - 注册所有可用的 Fragment 目标
 * - 管理 Session 生命周期
 */
class MainNavHostFragment : TurboSessionNavHostFragment() {

    override val sessionName = "main"

    override val startLocation = BuildConfig.BASE_URL

    override val registeredActivities: List<Class<*>>
        get() = listOf(
            // 后续注册需要原生 Activity 处理的页面（如相机）
        )

    override val registeredFragments: List<Class<*>>
        get() = listOf(
            AccountsTabFragment::class.java,
            BudgetsTabFragment::class.java,
            ReportsTabFragment::class.java,
            SettingsTabFragment::class.java,
        )

    override fun onSessionCreated() {
        super.onSessionCreated()
        // Session 创建后的初始化
        // 后续可在此添加自定义 WebView 设置
    }
}
