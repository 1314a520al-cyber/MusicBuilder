package com.music.app

import android.app.Application
import com.music.app.player.PlayerManager
import com.music.app.util.Preferences

class MusicApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Preferences.init(this)
        PlayerManager.init(this)
    }
}
