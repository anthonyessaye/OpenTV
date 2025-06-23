package com.anthonyessaye.opentv

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class OpenTVApplication: Application() {
    override fun onCreate() {
        super.onCreate()
    }

}