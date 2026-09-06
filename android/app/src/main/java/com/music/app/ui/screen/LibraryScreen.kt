package com.music.app.ui.screen

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.music.app.data.model.Song
import com.music.app.player.PlayerManager
import com.music.app.ui.components.EmptyView
import com.music.app.ui.components.SongItem
import com.music.app.util.Preferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
fun LibraryScreen(onPlaySong: () -> Unit) {
    var favoriteSongs by remember { mutableStateOf<List<Song>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    // 从收藏中恢复歌曲信息（简化版：实际应从数据库或缓存加载）
    LaunchedEffect(Unit) {
        isLoading = true
        // 收藏的歌曲 ID 列表，实际应用中应缓存完整歌曲信息
        val favIds = Preferences.get().getFavorites()
        // 简化：显示空状态，提示用户在搜索结果中收藏
        favoriteSongs = emptyList()
        isLoading = false
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Text(
            text = "音乐库",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(start = 16.dp, top = 16.dp, bottom = 12.dp)
        )

        if (isLoading) {
            com.music.app.ui.components.LoadingView()
        } else if (favoriteSongs.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(32.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Default.Favorite,
                        contentDescription = null,
                        modifier = Modifier
                            .padding(bottom = 16.dp),
                        tint = MaterialTheme.colorScheme.outline
                    )
                    Text(
                        "暂无收藏歌曲",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 16.sp,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    Text(
                        "在搜索结果中点击爱心收藏歌曲",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 13.sp
                    )
                }
            }
        } else {
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(favoriteSongs, key = { it.identityKey }) { song ->
                    SongItem(
                        song = song,
                        index = favoriteSongs.indexOf(song),
                        onClick = {
                            PlayerManager.get().playQueue(favoriteSongs, favoriteSongs.indexOf(song))
                            onPlaySong()
                        }
                    )
                }
                item { Spacer(modifier = Modifier.height(80.dp)) }
            }
        }
    }
}
