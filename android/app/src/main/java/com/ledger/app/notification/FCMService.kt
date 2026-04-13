package com.ledger.app.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.ledger.app.MainActivity
import com.ledger.app.R

/**
 * FCMService - Firebase Cloud Messaging 推送通知服务
 *
 * 功能：
 * - 接收 FCM 推送通知
 * - 处理通知点击跳转
 * - 管理设备 Token 与服务端同步
 *
 * 通知类型：
 * - 账单到期提醒
 * - 定期交易提醒
 * - 应收款到期提醒
 *
 * 使用前提：
 * 1. 在 Firebase Console 创建项目
 * 2. 下载 google-services.json 放到 android/app/
 * 3. 在 build.gradle.kts 中启用 google-services 插件
 *
 * 当前状态：骨架代码，配置 Firebase 后即可启用
 */
class FCMService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "FCMService"
        const val CHANNEL_BILL_REMINDERS = "bill_reminders"
        const val CHANNEL_RECURRING = "recurring_transactions"
        const val CHANNEL_RECEIVABLES = "receivables"
    }

    /**
     * Token 刷新回调
     * 当设备 Token 变化时触发，需要上传到 Ledger 服务端
     */
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "FCM Token refreshed: $token")

        // TODO: 上传 Token 到 Ledger 服务端
        // POST /api/external/fcm_token { token: token, device: "android" }
        uploadTokenToServer(token)
    }

    /**
     * 接收推送通知
     */
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        Log.d(TAG, "From: ${remoteMessage.from}")

        // 处理数据负载
        if (remoteMessage.data.isNotEmpty()) {
            val type = remoteMessage.data["type"] ?: "general"
            val title = remoteMessage.data["title"] ?: "记账本"
            val body = remoteMessage.data["body"] ?: ""
            val deepLink = remoteMessage.data["link"]

            showNotification(type, title, body, deepLink)
        }

        // 处理通知负载（前台时）
        remoteMessage.notification?.let { notification ->
            showNotification(
                type = "general",
                title = notification.title ?: "记账本",
                body = notification.body ?: "",
                deepLink = null
            )
        }
    }

    private fun showNotification(type: String, title: String, body: String, deepLink: String?) {
        createNotificationChannels()

        val channelId = when (type) {
            "bill_reminder" -> CHANNEL_BILL_REMINDERS
            "recurring" -> CHANNEL_RECURRING
            "receivable" -> CHANNEL_RECEIVABLES
            else -> CHANNEL_BILL_REMINDERS
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            deepLink?.let { putExtra("deep_link", it) }
        }

        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(type.hashCode(), notification)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val billChannel = NotificationChannel(
                CHANNEL_BILL_REMINDERS,
                "账单提醒",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "信用卡账单到期提醒"
            }

            val recurringChannel = NotificationChannel(
                CHANNEL_RECURRING,
                "定期交易",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "定期交易自动执行提醒"
            }

            val receivableChannel = NotificationChannel(
                CHANNEL_RECEIVABLES,
                "应收款提醒",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "应收款到期提醒"
            }

            manager.createNotificationChannels(listOf(billChannel, recurringChannel, receivableChannel))
        }
    }

    private fun uploadTokenToServer(token: String) {
        // TODO: 实现 Token 上传
        // 使用 HTTP 请求将 Token 发送到 Ledger 服务端
        // 服务端存储 Token 用于后续推送
        Log.d(TAG, "TODO: Upload token to server: $token")
    }
}
