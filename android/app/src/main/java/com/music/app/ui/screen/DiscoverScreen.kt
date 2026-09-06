package com.music.app.ui.screen
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.music.app.data.api.MusicApi
import com.music.app.data.model.MusicSource
import com.music.app.data.model.Song
import com.music.app.player.PlayerManager
import com.music.app.ui.components.LoadingView
import com.music.app.ui.components.PullRefreshBox
import com.music.app.ui.components.SectionHeader
import com.music.app.ui.components.SongItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiscoverScreen(onPlaySong: () -> Unit) {
    var hotSongs by remember { mutableStateOf<List<Song>>(emptyList()) }
    var newSongs by remember { mutableStateOf<List<Song>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var isRefreshing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    suspend fun loadData() {
        hotSongs = withContext(Dispatchers.IO) {
            try { MusicApi.get().search("热门", MusicSource.NETEASE) } catch (_: Exception) { emptyList() }
        }
        newSongs = withContext(Dispatchers.IO) {
            try { MusicApi.get().search("新歌", MusicSource.NETEASE) } catch (_: Exception) { emptyList() }
        }
    }

    LaunchedEffect(Unit) {
        isLoading = true
        loadData()
        isLoading = false
    }

    if (isLoading) {
        LoadingView()
        return
    }

    PullRefreshBox(
        isRefreshing = isRefreshing,
        onRefresh = {
            scope.launch {
                isRefreshing = true
                loadData()
                delay(300)
                isRefreshing = false
            }
        },
        modifier = Modifier.fillMaxSize()
    ) {
        LazyColumn(modifier = Modifier.fillMaxSize()) {
            item {
                Text(
                    text = "发现",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(start = 16.dp, top = 16.dp, bottom = 8.dp)
                )
            }
            // 推荐歌单横向滚动
            item {
                SectionHeader(title = "推荐歌单")
                LazyRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp)
                ) {
                    items(listOf("流行", "摇滚", "电子", "民谣", "古典", "爵士")) { genre ->
                        PlaylistCard(genre = genre)
                    }
                }
            }
            // 热门歌曲
            item {
                SectionHeader(title = "热门歌曲")
                Spacer(modifier = Modifier.height(4.dp))
            }
            items(hotSongs.take(10), key = { it.identityKey }) { song ->
                SongItem(
                    song = song,
                    index = hotSongs.indexOf(song),
                    onClick = {
                        PlayerManager.get().playQueue(hotSongs, hotSongs.indexOf(song))
                        onPlaySong()
                    }
                )
            }
            // 新歌推荐
            item {
                SectionHeader(title = "新歌推荐")
                Spacer(modifier = Modifier.height(4.dp))
            }
            items(newSongs.take(10), key = { it.identityKey }) { song ->
                SongItem(
                    song = song,
                    index = newSongs.indexOf(song),
                    onClick = {
                        PlayerManager.get().playQueue(newSongs, newSongs.indexOf(song))
                        onPlaySong()
                    }
                )
            }
            item { Spacer(modifier = Modifier.height(80.dp)) }
        }
    }
}
@Composable
fun PlaylistCard(genre: String) {
    Card(
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.width(120.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.MusicNote,
                    contentDescription = null,
                    modifier = Modifier.size(40.dp),
                    tint = MaterialTheme.colorScheme.primary
                )
            }
            Text(
                text = "${genre}精选",
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.padding(8.dp),
                maxLines = 1
            )
        }
    }
}
