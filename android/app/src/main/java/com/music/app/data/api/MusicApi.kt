package com.music.app.data.api

import com.music.app.data.model.MusicSource
import com.music.app.data.model.Song
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class MusicApi {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()

    private val headers = mapOf(
        "User-Agent" to "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15",
        "Referer" to "https://music.163.com/"
    )

    suspend fun search(keyword: String, source: MusicSource, page: Int = 1, limit: Int = 30): List<Song> = withContext(Dispatchers.IO) {
        when (source) {
            MusicSource.NETEASE -> searchNetEase(keyword, page, limit)
            MusicSource.QQ -> searchQQ(keyword, page, limit)
            MusicSource.KUGOU -> searchKugou(keyword, page, limit)
        }
    }

    private fun searchNetEase(keyword: String, page: Int, limit: Int): List<Song> {
        val url = "https://music.163.com/api/search/get?s=${java.net.URLEncoder.encode(keyword, "UTF-8")}&type=1&offset=${(page - 1) * limit}&limit=$limit"
        val json = getJson(url) ?: return emptyList()
        val songs = mutableListOf<Song>()
        try {
            val result = json.optJSONObject("result") ?: return emptyList()
            val array = result.optJSONArray("songs") ?: return emptyList()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val artists = obj.optJSONArray("artists")
                val artistName = if (artists != null && artists.length() > 0) {
                    (0 until artists.length()).joinToString(" / ") { artists.getJSONObject(it).optString("name") }
                } else ""
                val album = obj.optJSONObject("album")
                songs.add(
                    Song(
                        id = obj.optString("id"),
                        name = obj.optString("name"),
                        artist = artistName,
                        album = album?.optString("name") ?: "",
                        coverUrl = album?.optString("picUrl") ?: "",
                        duration = obj.optLong("duration", 0),
                        source = MusicSource.NETEASE,
                        isVip = obj.optInt("fee", 0) == 1
                    )
                )
            }
        } catch (_: Exception) {}
        return songs
    }

    private fun searchQQ(keyword: String, page: Int, limit: Int): List<Song> {
        val url = "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w=${java.net.URLEncoder.encode(keyword, "UTF-8")}&p=$page&n=$limit&format=json"
        val json = getJson(url, referer = "https://y.qq.com/") ?: return emptyList()
        val songs = mutableListOf<Song>()
        try {
            val data = json.optJSONObject("data") ?: return emptyList()
            val song = data.optJSONObject("song") ?: return emptyList()
            val list = song.optJSONArray("list") ?: return emptyList()
            for (i in 0 until list.length()) {
                val obj = list.getJSONObject(i)
                songs.add(
                    Song(
                        id = obj.optString("songmid"),
                        name = obj.optString("songname"),
                        artist = obj.optJSONArray("singer")?.let { arr ->
                            (0 until arr.length()).joinToString(" / ") { arr.getJSONObject(it).optString("name") }
                        } ?: "",
                        album = obj.optString("albumname"),
                        duration = obj.optLong("interval", 0) * 1000,
                        source = MusicSource.QQ,
                        isVip = obj.optInt("pay", 0) > 0
                    )
                )
            }
        } catch (_: Exception) {}
        return songs
    }

    private fun searchKugou(keyword: String, page: Int, limit: Int): List<Song> {
        val url = "https://mobilecdn.kugou.com/api/v3/search/song?keyword=${java.net.URLEncoder.encode(keyword, "UTF-8")}&page=$page&pagesize=$limit&format=json"
        val json = getJson(url, referer = "https://www.kugou.com/") ?: return emptyList()
        val songs = mutableListOf<Song>()
        try {
            val data = json.optJSONObject("data") ?: return emptyList()
            val info = data.optJSONArray("info") ?: return emptyList()
            for (i in 0 until info.length()) {
                val obj = info.getJSONObject(i)
                songs.add(
                    Song(
                        id = obj.optString("hash"),
                        name = obj.optString("songname"),
                        artist = obj.optString("singername"),
                        album = obj.optString("album_name"),
                        duration = obj.optLong("duration", 0) * 1000,
                        source = MusicSource.KUGOU,
                        isVip = false,
                        hash = obj.optString("hash"),
                        albumAudioId = obj.optString("album_audio_id")
                    )
                )
            }
        } catch (_: Exception) {}
        return songs
    }

    suspend fun getSongUrl(song: Song, cardKey: String = ""): String? = withContext(Dispatchers.IO) {
        when (song.source) {
            MusicSource.NETEASE -> getNetEaseUrl(song, cardKey)
            MusicSource.QQ -> getQQUrl(song, cardKey)
            MusicSource.KUGOU -> getKugouUrl(song, cardKey)
        }
    }

    private fun getNetEaseUrl(song: Song, cardKey: String): String? {
        // 优先使用第三方解锁音源（需要卡密）
        if (cardKey.isNotEmpty()) {
            val unblockUrl = "https://source.shiqianjiang.cn/api/music/url?source=netease&songId=${song.id}&quality=standard&key=$cardKey"
            val json = getJson(unblockUrl)
            try {
                val url = json?.optString("url") ?: ""
                if (url.isNotEmpty()) return url
            } catch (_: Exception) {}
        }
        // 官方接口（免费歌曲）
        val url = "https://music.163.com/api/song/enhance/player/url?id=${song.id}&ids=[${song.id}]&br=320000"
        val json = getJson(url) ?: return null
        return try {
            val array = json.optJSONArray("data") ?: return null
            if (array.length() > 0) array.getJSONObject(0).optString("url") else null
        } catch (_: Exception) { null }
    }

    private fun getQQUrl(song: Song, cardKey: String): String? {
        if (cardKey.isNotEmpty()) {
            val unblockUrl = "https://source.shiqianjiang.cn/api/music/url?source=qq&songId=${song.id}&quality=standard&key=$cardKey"
            val json = getJson(unblockUrl)
            try {
                val url = json?.optString("url") ?: ""
                if (url.isNotEmpty()) return url
            } catch (_: Exception) {}
        }
        return null
    }

    private fun getKugouUrl(song: Song, cardKey: String): String? {
        if (cardKey.isNotEmpty()) {
            val unblockUrl = "https://source.shiqianjiang.cn/api/music/url?source=kugou&songId=${song.hash}&quality=standard&key=$cardKey"
            val json = getJson(unblockUrl)
            try {
                val url = json?.optString("url") ?: ""
                if (url.isNotEmpty()) return url
            } catch (_: Exception) {}
        }
        // 酷狗官方接口
        val hash = song.hash.ifEmpty { song.id }
        val url = "https://www.kugou.com/yy/index.php?r=play/getdata&hash=$hash&album_id=${song.albumAudioId}"
        val json = getJson(url, referer = "https://www.kugou.com/") ?: return null
        return try {
            val data = json.optJSONObject("data") ?: return null
            data.optString("play_url")
        } catch (_: Exception) { null }
    }

    suspend fun getLyric(song: Song): String = withContext(Dispatchers.IO) {
        when (song.source) {
            MusicSource.NETEASE -> getNetEaseLyric(song.id)
            MusicSource.QQ -> ""
            MusicSource.KUGOU -> ""
        }
    }

    private fun getNetEaseLyric(id: String): String {
        val url = "https://music.163.com/api/song/lyric?id=$id&lv=1&kv=1&tv=-1"
        val json = getJson(url) ?: return ""
        return try {
            json.optJSONObject("lrc")?.optString("lyric") ?: ""
        } catch (_: Exception) { "" }
    }

    private fun getJson(url: String, referer: String = "https://music.163.com/"): JSONObject? {
        return try {
            val request = Request.Builder()
                .url(url)
                .apply {
                    headers.forEach { (k, v) -> addHeader(k, v) }
                    addHeader("Referer", referer)
                }
                .build()
            client.newCall(request).execute().use { response ->
                val body = response.body?.string() ?: return null
                JSONObject(body)
            }
        } catch (_: Exception) { null }
    }

    companion object {
        @Volatile
        private var instance: MusicApi? = null
        fun get(): MusicApi = instance ?: synchronized(this) {
            instance ?: MusicApi().also { instance = it }
        }
    }
}
