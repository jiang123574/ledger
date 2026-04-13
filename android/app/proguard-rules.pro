# ProGuard rules for Ledger Android app

# Keep Turbo Native classes
-keep class dev.hotwire.turbo.** { *; }

# Keep WebView JavaScript interface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }

# Firebase Cloud Messaging
-keep class com.google.firebase.** { *; }
-keep class com.ledger.app.notification.FCMService { *; }

# Biometric
-keep class androidx.biometric.** { *; }
