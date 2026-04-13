package com.ledger.app.navigation

import dev.hotwire.turbo.nav.TurboNavGraphDestination
import com.ledger.app.BuildConfig
import com.ledger.app.turbo.TurboWebViewFragment

/**
 * 账户 Tab - 加载 /accounts 页面
 */
@TurboNavGraphDestination(uri = "turbo://fragment/accounts")
class AccountsTabFragment : TurboWebViewFragment() {
    override val startLocation: String
        get() = "${BuildConfig.BASE_URL}/accounts"
}

/**
 * 预算 Tab - 加载 /budgets 页面
 */
@TurboNavGraphDestination(uri = "turbo://fragment/budgets")
class BudgetsTabFragment : TurboWebViewFragment() {
    override val startLocation: String
        get() = "${BuildConfig.BASE_URL}/budgets"
}

/**
 * 报表 Tab - 加载 /reports 页面
 */
@TurboNavGraphDestination(uri = "turbo://fragment/reports")
class ReportsTabFragment : TurboWebViewFragment() {
    override val startLocation: String
        get() = "${BuildConfig.BASE_URL}/reports"
}

/**
 * 设置 Tab - 加载 /settings 页面
 */
@TurboNavGraphDestination(uri = "turbo://fragment/settings")
class SettingsTabFragment : TurboWebViewFragment() {
    override val startLocation: String
        get() = "${BuildConfig.BASE_URL}/settings"
}
