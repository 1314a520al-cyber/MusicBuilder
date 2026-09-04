package com.music.app.data.model

import kotlinx.serialization.Serializable

enum class MusicSource(val displayName: String) {
    NETEASE("网易云"),
    QQ("QQ音乐"),
    KUGOU("酷狗");

    companion object {
        fun fromOrdinal(ordinal: Int): MusicSource = entries.getOrElse(ordinal) { NETEASE }
    }
}

@Serializable
data class Song(
    val id: String,
    val name: String,
    val artist: String,
    val album: String,
    val coverUrl: String = "",
    val duration: Long = 0,
    val source: MusicSource = MusicSource.NETEASE,
    val isVip: Boolean = false,
    val url: String = "",
    val lyric: String = "",
    val hash: String = "",
    val albumAudioId: String = ""
) {
    val identityKey: String get() = "${source.name}_$id"
}

@Serializable
data class Playlist(
    val id: String,
    val name: String,
    val coverUrl: String = "",
    val songCount: Int = 0,
    val source: MusicSource = MusicSource.NETEASE,
    val songs: List<Song> = emptyList()
)

data class LyricLine(
    val time: Long,
    val text: String,
    val translation: String = ""
)
