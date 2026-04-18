package com.ledger.app.bridge

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/**
 * BiometricBridge - 生物识别认证桥接
 *
 * 功能：
 * - 检测设备是否支持生物识别
 * - 触发指纹/面部识别
 * - 将结果通过 JS Bridge 通知 Web 端
 *
 * Web 端使用：
 *   window.LedgerNative.requestBiometric()
 *   window.addEventListener('native:biometric', (e) => {
 *     if (e.detail.success) { /* 登录成功 */ }
 *   })
 */
class BiometricBridge(
    private val activity: FragmentActivity,
    private val nativeBridge: NativeBridge
) {
    /**
     * 检查设备是否支持生物识别
     */
    fun isAvailable(): Boolean {
        val biometricManager = BiometricManager.from(activity)
        return biometricManager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG or
            BiometricManager.Authenticators.BIOMETRIC_WEAK
        ) == BiometricManager.BIOMETRIC_SUCCESS
    }

    /**
     * 触发生物识别认证
     */
    fun authenticate() {
        if (!isAvailable()) {
            nativeBridge.notifyBiometricResult(false, "设备不支持生物识别")
            return
        }

        val executor = ContextCompat.getMainExecutor(activity)

        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                super.onAuthenticationSucceeded(result)
                nativeBridge.notifyBiometricResult(true)
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                super.onAuthenticationError(errorCode, errString)
                nativeBridge.notifyBiometricResult(false, errString.toString())
            }

            override fun onAuthenticationFailed() {
                super.onAuthenticationFailed()
                // 单次失败不回调，BiometricPrompt 会自动重试
            }
        }

        val biometricPrompt = BiometricPrompt(activity, executor, callback)

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("身份验证")
            .setSubtitle("使用指纹或面部识别登录记账本")
            .setNegativeButtonText("使用密码")
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.BIOMETRIC_WEAK
            )
            .build()

        biometricPrompt.authenticate(promptInfo)
    }
}
