package com.ledger.app

import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.navigation.fragment.NavHostFragment
import androidx.navigation.ui.setupWithNavController
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.turbo.session.TurboSessionNavHostFragment
import dev.hotwire.turbo.views.TurboView

/**
 * MainActivity - Ledger Android App 主入口
 *
 * 架构：
 * - 使用 Jetpack Navigation 管理底部 Tab 导航
 * - 每个 Tab 对应一个 TurboWebViewFragment
 * - Turbo Native 提供 WebView 渲染 + 原生导航体验
 */
class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        setupNavigation()
    }

    private fun setupNavigation() {
        val navHostFragment = supportFragmentManager
            .findFragmentById(R.id.nav_host_fragment) as NavHostFragment
        val navController = navHostFragment.navController

        val bottomNav = findViewById<BottomNavigationView>(R.id.bottom_navigation)
        bottomNav.setupWithNavController(navController)

        // 根据导航切换显示/隐藏底部栏
        navController.addOnDestinationChangedListener { _, destination, _ ->
            when (destination.id) {
                R.id.tab_accounts,
                R.id.tab_budgets,
                R.id.tab_reports,
                R.id.tab_settings -> {
                    bottomNav.visibility = View.VISIBLE
                }
                else -> {
                    bottomNav.visibility = View.VISIBLE
                }
            }
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
