package com.music.app.player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.music.app.MainActivity
import com.music.app.R

class MusicPlaybackService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    private var player: ExoPlayer? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        player = ExoPlayer.Builder(this).build()
        mediaSession = MediaSession.Builder(this, player!!).build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = mediaSession

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_TOGGLE -> {
                player?.let { if (it.isPlaying) it.pause() else it.play() }
            }
            ACTION_NEXT -> player?.seekToNextMediaItem()
            ACTION_PREV -> player?.seekToPreviousMediaItem()
        }
        return super.onStartCommand(intent, flags, startId)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "音乐播放",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "音乐播放控制"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        mediaSession?.run {
            player.release()
            release()
        }
        mediaSession = null
        player = null
        super.onDestroy()
    }

    companion object {
        const val CHANNEL_ID = "music_playback"
        const val ACTION_TOGGLE = "com.music.app.TOGGLE"
        const val ACTION_NEXT = "com.music.app.NEXT"
        const val ACTION_PREV = "com.music.app.PREV"
    }
}
