package com.ledger.app.navigation

import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import dev.hotwire.turbo.config.TurboPathConfiguration
import dev.hotwire.turbo.nav.TurboNavGraphDestination
import dev.hotwire.turbo.session.TurboSessionNavHostFragment
import com.ledger.app.BuildConfig
import com.ledger.app.turbo.TurboWebViewFragment
import kotlin.reflect.KClass

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

    override val pathConfigurationLocation = TurboPathConfiguration.Location(
        assetFilePath = "json/configuration.json"
    )

    override val registeredActivities: List<KClass<out AppCompatActivity>>
        get() = listOf(
            // 后续注册需要原生 Activity 处理的页面（如相机）
        )

    override val registeredFragments: List<KClass<out Fragment>>
        get() = listOf(
            TurboWebViewFragment::class,
            AccountsTabFragment::class,
            BudgetsTabFragment::class,
            ReportsTabFragment::class,
            SettingsTabFragment::class,
        )

    override fun onSessionCreated() {
        super.onSessionCreated()
        Log.d("MainNavHost", "Session created, startLocation=$startLocation")
        val props = try {
            session.pathConfiguration.properties(startLocation)
        } catch (e: Exception) {
            Log.e("MainNavHost", "Path config error", e)
            return
        }
        Log.d("MainNavHost", "Path config loaded, uri=${props["uri"]}")
    }
}
