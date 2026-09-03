package com.music.app.player

import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.music.app.data.api.MusicApi
import com.music.app.data.model.Song
import com.music.app.util.Preferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class PlayerManager(context: Context) {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var player: ExoPlayer? = null
    private var currentLoadJob: Job? = null
    private var retryCount = 0
    private val maxRetries = 2

    private val _currentSong = MutableStateFlow<Song?>(null)
    val currentSong: StateFlow<Song?> = _currentSong.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _isBuffering = MutableStateFlow(false)
    val isBuffering: StateFlow<Boolean> = _isBuffering.asStateFlow()

    private val _progress = MutableStateFlow(0L)
    val progress: StateFlow<Long> = _progress.asStateFlow()

    private val _duration = MutableStateFlow(0L)
    val duration: StateFlow<Long> = _duration.asStateFlow()

    private val _queue = MutableStateFlow<List<Song>>(emptyList())
    val queue: StateFlow<List<Song>> = _queue.asStateFlow()

    private val _currentIndex = MutableStateFlow(-1)
    val currentIndex: StateFlow<Int> = _currentIndex.asStateFlow()

    private val _playMode = MutableStateFlow(PlayMode.LIST)
    val playMode: StateFlow<PlayMode> = _playMode.asStateFlow()

    private var progressJob: Job? = null

    enum class PlayMode { LIST, SINGLE, SHUFFLE }

    init {
        initPlayer()
        startProgressTracking()
    }

    private fun initPlayer() {
        player = ExoPlayer.Builder(appContext).build().apply {
            addListener(object : Player.Listener {
                override fun onIsPlayingChanged(playing: Boolean) {
                    _isPlaying.value = playing
                }

                override fun onPlaybackStateChanged(playbackState: Int) {
                    when (playbackState) {
                        Player.STATE_BUFFERING -> _isBuffering.value = true
                        Player.STATE_READY -> {
                            _isBuffering.value = false
                            _duration.value = duration
                        }
                        Player.STATE_ENDED -> {
                            _isBuffering.value = false
                            if (_playMode.value != PlayMode.SINGLE) {
                                next()
                            } else {
                                seekTo(0)
                                play()
                            }
                        }
                        Player.STATE_IDLE -> _isBuffering.value = false
                    }
                }
            })
        }
    }

    fun playQueue(songs: List<Song>, index: Int = 0) {
        if (songs.isEmpty()) return
        _queue.value = songs
        _currentIndex.value = index
        playSong(songs[index])
    }

    fun playSong(song: Song) {
        currentLoadJob?.cancel()
        retryCount = 0
        _currentSong.value = song
        _isBuffering.value = true
        loadAndPlay(song)
    }

    private fun loadAndPlay(song: Song) {
        currentLoadJob = scope.launch {
            try {
                val cardKey = if (Preferences.get().enableUnblock) Preferences.get().cardKey else ""
                val url = withContext(Dispatchers.IO) {
                    MusicApi.get().getSongUrl(song, cardKey)
                }
                if (url.isNullOrEmpty()) {
                    handlePlaybackFailure(song, "无法获取播放地址")
                    return@launch
                }
                withContext(Dispatchers.Main) {
                    player?.apply {
                        stop()
                        clearMediaItems()
                        setMediaItem(MediaItem.fromUri(url))
                        prepare()
                        play()
                    }
                    _isBuffering.value = false
                    // 应用当前音效（均衡器）预设
                    applyAudioFxInternal()
                }
            } catch (e: Exception) {
                handlePlaybackFailure(song, e.message ?: "播放失败")
            }
        }
    }

    private fun handlePlaybackFailure(song: Song, reason: String) {
        _isBuffering.value = false
        if (retryCount < maxRetries) {
            retryCount++
            scope.launch {
                delay(800)
                if (_currentSong.value?.identityKey == song.identityKey) {
                    loadAndPlay(song)
                }
            }
        } else {
            // 自动跳过到下一首
            scope.launch {
                delay(500)
                if (_queue.value.size > 1) {
                    next()
                }
            }
        }
    }

    fun play() {
        player?.play()
    }

    fun pause() {
        player?.pause()
    }

    fun togglePlay() {
        if (player?.isPlaying == true) pause() else play()
    }

    fun next() {
        val queue = _queue.value
        if (queue.isEmpty()) return
        var nextIndex = when (_playMode.value) {
            PlayMode.SHUFFLE -> (queue.indices).random()
            else -> (_currentIndex.value + 1) % queue.size
        }
        _currentIndex.value = nextIndex
        playSong(queue[nextIndex])
    }

    fun previous() {
        val queue = _queue.value
        if (queue.isEmpty()) return
        val prevIndex = if (_currentIndex.value > 0) _currentIndex.value - 1 else queue.size - 1
        _currentIndex.value = prevIndex
        playSong(queue[prevIndex])
    }

    fun seekTo(positionMs: Long) {
        player?.seekTo(positionMs)
        _progress.value = positionMs
    }

    fun cyclePlayMode() {
        _playMode.value = when (_playMode.value) {
            PlayMode.LIST -> PlayMode.SINGLE
            PlayMode.SINGLE -> PlayMode.SHUFFLE
            PlayMode.SHUFFLE -> PlayMode.LIST
        }
    }

    private fun startProgressTracking() {
        progressJob = scope.launch {
            while (true) {
                player?.let {
                    if (it.isPlaying) {
                        _progress.value = it.currentPosition
                        _duration.value = it.duration.coerceAtLeast(0)
                    }
                }
                delay(500)
            }
        }
    }

    fun release() {
        progressJob?.cancel()
        currentLoadJob?.cancel()
        releaseEqualizer()
        player?.release()
        player = null
    }

    // MARK: - 音效（均衡器）
    private var equalizer: android.media.audiofx.Equalizer? = null
    private var currentAudioFxIndex = Preferences.get().audioFxIndex

    /// 各预设在不同频段上的增益（毫贝）
    private val fxBands: Map<Int, IntArray> = mapOf(
        0 to intArrayOf(0, 0, 0, 0, 0),                       // 默认
        1 to intArrayOf(600, 300, -100, -200, -100),          // 重低音
        2 to intArrayOf(-100, 200, 500, 400, 0),              // 流行
        3 to intArrayOf(500, 300, 0, -200, 300),              // 摇滚
        4 to intArrayOf(0, 0, 0, 0, 600),                     // 古典
        5 to intArrayOf(-200, 200, 400, 400, -200),           // 爵士
        6 to intArrayOf(-100, -100, 300, 500, 400),           // 人声
        7 to intArrayOf(400, 200, -100, -200, 400)            // 金属
    )

    /** 应用音效预设（需在播放中生效；设备不支持时静默降级） */
    fun setAudioFx(index: Int) {
        currentAudioFxIndex = index
        Preferences.get().audioFxIndex = index
        applyAudioFxInternal()
    }

    private fun applyAudioFxInternal() {
        val exo = player ?: return
        if (currentAudioFxIndex <= 0) {
            releaseEqualizer()
            return
        }
        try {
            val sessionId = exo.audioSessionId
            val eq = equalizer ?: android.media.audiofx.Equalizer(0, sessionId).also { equalizer = it }
            eq.enabled = false
            val bands = fxBands[currentAudioFxIndex] ?: return
            val range = eq.bandLevelRange
            val minLevel = range[0].toInt()
            val maxLevel = range[1].toInt()
            val bandCount = minOf(eq.numberOfBands.toInt(), bands.size)
            for (i in 0 until bandCount) {
                var level = bands[i]
                if (level > maxLevel) level = maxLevel
                if (level < minLevel) level = minLevel
                eq.setBandLevel(i.toShort(), level.toShort())
            }
            eq.enabled = true
        } catch (_: Exception) {
            // 设备不支持均衡器：静默降级，不影响播放
        }
    }

    private fun releaseEqualizer() {
        try { equalizer?.release() } catch (_: Exception) {}
        equalizer = null
    }

    companion object {
        @Volatile
        private var instance: PlayerManager? = null
        fun init(context: Context) {
            if (instance == null) {
                synchronized(this) {
                    if (instance == null) instance = PlayerManager(context)
                }
            }
        }
        fun get(): PlayerManager = instance ?: throw IllegalStateException("PlayerManager not initialized")
    }
}
