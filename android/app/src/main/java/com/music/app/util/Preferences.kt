package com.music.app.util

import android.content.Context
import android.content.SharedPreferences
import com.music.app.data.model.MusicSource

class Preferences(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("music_prefs", Context.MODE_PRIVATE)

    var currentSource: MusicSource
        get() = MusicSource.fromOrdinal(prefs.getInt("current_source", 0))
        set(value) = prefs.edit().putInt("current_source", value.ordinal).apply()

    var cardKey: String
        get() = prefs.getString("card_key", "") ?: ""
        set(value) = prefs.edit().putString("card_key", value).apply()

    var themeIndex: Int
        get() = prefs.getInt("theme_index", 0)
        set(value) = prefs.edit().putInt("theme_index", value).apply()

    var darkMode: Boolean
        get() = prefs.getBoolean("dark_mode", false)
        set(value) = prefs.edit().putBoolean("dark_mode", value).apply()

    var lyricFontSize: Int
        get() = prefs.getInt("lyric_font_size", 17)
        set(value) = prefs.edit().putInt("lyric_font_size", value).apply()

    var progressStyle: Int
        get() = prefs.getInt("progress_style", 0)
        set(value) = prefs.edit().putInt("progress_style", value).apply()

    var enableUnblock: Boolean
        get() = prefs.getBoolean("enable_unblock", true)
        set(value) = prefs.edit().putBoolean("enable_unblock", value).apply()

    // 音效（均衡器）预设索引，-1 表示关闭
    var audioFxIndex: Int
        get() = prefs.getInt("audio_fx_index", -1)
        set(value) = prefs.edit().putInt("audio_fx_index", value).apply()

    // 收藏歌曲（本地存储）
    fun getFavorites(): Set<String> = prefs.getStringSet("favorites", emptySet()) ?: emptySet()

    fun isFavorite(songId: String): Boolean = getFavorites().contains(songId)

    fun toggleFavorite(songId: String): Boolean {
        val favorites = getFavorites().toMutableSet()
        val isFav = if (favorites.contains(songId)) {
            favorites.remove(songId)
            false
        } else {
            favorites.add(songId)
            true
        }
        prefs.edit().putStringSet("favorites", favorites).apply()
        return isFav
    }

    companion object {
        @Volatile
        private var instance: Preferences? = null
        fun init(context: Context) {
            if (instance == null) {
                synchronized(this) {
                    if (instance == null) instance = Preferences(context.applicationContext)
                }
            }
        }
        fun get(): Preferences = instance ?: throw IllegalStateException("Preferences not initialized")
    }
}
