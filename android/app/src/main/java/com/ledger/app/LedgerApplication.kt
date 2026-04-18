package com.ledger.app

import android.app.Application

class LedgerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    companion object {
        lateinit var instance: LedgerApplication
            private set
    }
}
