package com.music.app.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Article
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.RepeatOne
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.music.app.data.model.LyricLine
import com.music.app.data.model.Song
import com.music.app.player.PlayerManager
import com.music.app.ui.theme.ThemeColors
import com.music.app.util.Preferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlayerScreen(onDismiss: () -> Unit) {
    val sheetState = rememberModalBottomSheetState()
    val currentSong by PlayerManager.get().currentSong.collectAsState()
    val isPlaying by PlayerManager.get().isPlaying.collectAsState()
    val isBuffering by PlayerManager.get().isBuffering.collectAsState()
    val progress by PlayerManager.get().progress.collectAsState()
    val duration by PlayerManager.get().duration.collectAsState()
    val playMode by PlayerManager.get().playMode.collectAsState()

    var showLyric by remember { mutableStateOf(false) }
    var lyrics by remember { mutableStateOf<List<LyricLine>>(emptyList()) }
    var isFav by remember(currentSong?.identityKey) {
        mutableStateOf(currentSong?.let { Preferences.get().isFavorite(it.identityKey) } ?: false)
    }

    val themeIndex = Preferences.get().themeIndex.coerceIn(0, ThemeColors.size - 1)
    val theme = ThemeColors[themeIndex]

    // 加载歌词
    LaunchedEffect(currentSong?.id) {
        currentSong?.let { song ->
            lyrics = withContext(Dispatchers.IO) {
                try {
                    val lyricText = com.music.app.data.api.MusicApi.get().getLyric(song)
                    parseLyric(lyricText)
                } catch (_: Exception) {
                    emptyList()
                }
            }
        }
    }

    // 歌词自动滚动
    val listState = rememberLazyListState()
    LaunchedEffect(progress) {
        if (showLyric && lyrics.isNotEmpty()) {
            val currentLine = lyrics.indexOfLast { it.time <= progress }
            if (currentLine >= 0) {
                listState.animateScrollToItem(currentLine)
            }
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        modifier = Modifier.fillMaxSize()
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(
                            theme.primary.copy(alpha = 0.15f),
                            MaterialTheme.colorScheme.surface
                        )
                    )
                )
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                // 顶部栏
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.KeyboardArrowDown, contentDescription = "收起")
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = currentSong?.name ?: "未播放",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                    IconButton(onClick = { showLyric = !showLyric }) {
                        Icon(
                            if (showLyric) Icons.Default.Close else Icons.Default.Favorite,
                            contentDescription = "歌词"
                        )
                    }
                }

                if (showLyric) {
                    // 歌词显示
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f)
                    ) {
                        if (lyrics.isEmpty()) {
                            Box(
                                modifier = Modifier.fillMaxSize(),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    "暂无歌词",
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontSize = 14.sp
                                )
                            }
                        } else {
                            LazyColumn(
                                state = listState,
                                modifier = Modifier.fillMaxSize(),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center
                            ) {
                                itemsIndexed(lyrics) { index, line ->
                                    val isCurrent = lyrics.indexOfLast { it.time <= progress } == index
                                    Text(
                                        text = line.text,
                                        fontSize = if (isCurrent) Preferences.get().lyricFontSize.sp
                                        else (Preferences.get().lyricFontSize - 2).sp,
                                        color = if (isCurrent) theme.primary
                                        else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                                        fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal,
                                        textAlign = TextAlign.Center,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(vertical = 8.dp, horizontal = 24.dp)
                                            .clickable {
                                                PlayerManager.get().seekTo(line.time)
                                            }
                                    )
                                }
                            }
                        }
                    }
                } else {
                    // 封面显示
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f),
                        contentAlignment = Alignment.Center
                    ) {
                        currentSong?.let { song ->
                            if (song.coverUrl.isNotEmpty()) {
                                AsyncImage(
                                    model = song.coverUrl,
                                    contentDescription = song.name,
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier
                                        .size(280.dp)
                                        .clip(RoundedCornerShape(16.dp))
                                )
                            } else {
                                Box(
                                    modifier = Modifier
                                        .size(280.dp)
                                        .clip(RoundedCornerShape(16.dp))
                                        .background(theme.primary.copy(alpha = 0.3f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        song.name.take(1),
                                        fontSize = 80.sp,
                                        color = Color.White,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }
                    }
                }

                // 歌曲信息
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 8.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = currentSong?.name ?: "未播放",
                                fontSize = 20.sp,
                                fontWeight = FontWeight.Bold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = currentSong?.artist ?: "",
                                fontSize = 14.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                        IconButton(onClick = {
                            currentSong?.let { song ->
                                isFav = Preferences.get().toggleFavorite(song.identityKey)
                            }
                        }) {
                            Icon(
                                if (isFav) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                                contentDescription = "收藏",
                                tint = if (isFav) Color(0xFFFF6B6B) else MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    }
                }

                // 进度条（多种样式，点击/拖动跳转）
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp)
                ) {
                    val progressStyle = Preferences.get().progressStyle
                    val pct = if (duration > 0) (progress.toDouble() / duration).coerceIn(0.0, 1.0) else 0.0
                    StyleProgressBar(
                        pct = pct,
                        style = progressStyle,
                        accent = theme.primary,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(20.dp),
                        onSeek = { fraction ->
                            if (duration > 0) {
                                PlayerManager.get().seekTo((fraction * duration).toLong())
                            }
                        }
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = formatTime(progress),
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = formatTime(duration),
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // 播放控制
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 16.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = { PlayerManager.get().cyclePlayMode() }) {
                        Icon(
                            when (playMode) {
                                PlayerManager.PlayMode.SINGLE -> Icons.Default.RepeatOne
                                PlayerManager.PlayMode.SHUFFLE -> Icons.Default.Shuffle
                                else -> Icons.Default.Repeat
                            },
                            contentDescription = "播放模式",
                            tint = theme.primary,
                            modifier = Modifier.size(24.dp)
                        )
                    }

                    IconButton(onClick = { PlayerManager.get().previous() }) {
                        Icon(
                            Icons.Default.SkipPrevious,
                            contentDescription = "上一首",
                            modifier = Modifier.size(36.dp)
                        )
                    }

                    Box(
                        modifier = Modifier
                            .size(64.dp)
                            .clip(CircleShape)
                            .background(theme.primary)
                            .clickable { PlayerManager.get().togglePlay() },
                        contentAlignment = Alignment.Center
                    ) {
                        if (isBuffering) {
                            androidx.compose.material3.CircularProgressIndicator(
                                color = Color.White,
                                modifier = Modifier.size(28.dp),
                                strokeWidth = 3.dp
                            )
                        } else {
                            Icon(
                                if (isPlaying) Icons.Filled.Pause
                                else Icons.Filled.PlayArrow,
                                contentDescription = if (isPlaying) "暂停" else "播放",
                                tint = Color.White,
                                modifier = Modifier.size(32.dp)
                            )
                        }
                    }

                    IconButton(onClick = { PlayerManager.get().next() }) {
                        Icon(
                            Icons.Default.SkipNext,
                            contentDescription = "下一首",
                            modifier = Modifier.size(36.dp)
                        )
                    }

                    IconButton(onClick = { showLyric = !showLyric }) {
                        Icon(
                            androidx.compose.material.icons.Icons.Default.Article,
                            contentDescription = "歌词",
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

/**
 * 自定义进度条：点击/拖动跳转，支持多种视觉样式。
 * style: 0 默认 / 1 流光 / 2 辉光 / 3 极光 / 4 波浪 / 5 霓虹 / 6 能量 / 7 光谱
 */
@Composable
fun StyleProgressBar(
    pct: Double,
    style: Int,
    accent: Color,
    modifier: Modifier,
    onSeek: (Double) -> Unit
) {
    val density = androidx.compose.ui.platform.LocalDensity.current
    var barWidthPx by remember { mutableStateOf(0f) }

    fun handleDrag(xPx: Float, width: Float) {
        if (width <= 0) return
        val fraction = (xPx / width).coerceIn(0f, 1f).toDouble()
        onSeek(fraction)
    }

    Box(
        modifier = modifier
            .pointerInput(Unit) {
                detectTapGestures { offset ->
                    handleDrag(offset.x, size.width.toFloat())
                }
            }
            .pointerInput(Unit) {
                detectDragGestures(
                    onDrag = { change, _ ->
                        change.consume()
                        handleDrag(change.position.x, size.width.toFloat())
                    }
                )
            }
            .onSizeChanged { barWidthPx = it.width.toFloat() }
            .drawBehind {
                barWidthPx = size.width
                val trackH = 4.dp.toPx()
                val trackY = size.height / 2 - trackH / 2
                val fillWidth = size.width * pct.toFloat()

                // 轨道底
                drawRoundRect(
                    color = accent.copy(alpha = 0.15f),
                    topLeft = androidx.compose.ui.geometry.Offset(0f, trackY),
                    size = androidx.compose.ui.geometry.Size(size.width, trackH),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(trackH / 2)
                )

                // 已播放段
                if (fillWidth > 0) {
                    when (style) {
                        1 -> {
                            // 流光：青色→主题色渐变
                            drawRoundRect(
                                brush = androidx.compose.ui.graphics.Brush.horizontalGradient(
                                    listOf(androidx.compose.ui.graphics.Color(0xFF64FFDA), accent)
                                ),
                                topLeft = androidx.compose.ui.geometry.Offset(0f, trackY),
                                size = androidx.compose.ui.geometry.Size(fillWidth, trackH),
                                cornerRadius = androidx.compose.ui.geometry.CornerRadius(trackH / 2)
                            )
                        }
                        2 -> {
                            // 辉光：高亮 + 底部光晕
                            drawRoundRect(
                                color = accent,
                                topLeft = androidx.compose.ui.geometry.Offset(0f, trackY),
                                size = androidx.compose.ui.geometry.Size(fillWidth, trackH),
                                cornerRadius = androidx.compose.ui.geometry.CornerRadius(trackH / 2)
                            )
                            drawRoundRect(
                                color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.55f),
                                topLeft = androidx.compose.ui.geometry.Offset(0f, trackY),
                                size = androidx.compose.ui.geometry.Size(fillWidth, trackH * 0.4f),
                                cornerRadius = androidx.compose.ui.geometry.CornerRadius(trackH / 2)
                            )
                        }
                        3 -> {
                            // 极光：垂直渐变
                            drawRoundRect(
                                brush = androidx.compose.ui.graphics.Brush.verticalGradient(
                                    listOf(accent.copy(alpha = 0.6f), accent, androidx.compose.ui.graphics.Color.White.copy(alpha = 0.8f))
                                ),
                                topLeft = androidx.compose.ui.geometry.Offset(0f, trackY),
                                size = androidx.compose.ui.geometry.Size(fillWidth, trackH),
                                cornerRadius = androidx.compose.ui.geometry.CornerRadius(trackH / 2)
                            )
                        }
                        4 -> {
                            // 波浪：多段圆点
                            val segW = trackH * 2.2f
                            var sx = 0f
                            while (sx < fillWidth) {
                                drawCircle(
                                    color = accent,
                                    radius = trackH / 2,
                                    center = androidx.compose.ui.geometry.Offset(sx + segW / 2, trackY + trackH / 2)
                                )
                                sx += segW
                            }
                        }
                        5 -> {
                            // 霓虹双线
                            drawRoundRect(
                                color = accent.copy(alpha = 0.5f),
                                topLeft = androidx.compose.ui.geometry.Offset(0f, trackY - 3.dp.toPx()),
                                size = androidx.compose.ui.geometry.Size(fillWidth, 2.dp.toPx()),
                                cornerRadius = androidx.compose.ui.geometry.CornerRadius(1.dp.toPx())
                            )
                            drawRoundRect(
                                color = accent,
                                topLeft = androidx.compose.ui.geometry.Offset(0f, trackY),
                                size = androidx.compose.ui.geometry.Size(fillWidth, trackH),
                                cornerRadius = androidx.compose.ui.geometry.CornerRadius(trackH / 2)
                            )
                        }
                        6 -> {
                            // 能量分段
                            val n = 12
                            val gap = 3.dp.toPx()
                            val segW = (size.width - gap * (n - 1)) / n
                            for (i in 0 until n) {
                                val segStart = i * (segW + gap)
                                val segEnd = segStart + segW
                                val on = fillWidth >= segEnd || (fillWidth > segStart && fillWidth < segEnd)
                                drawRoundRect(
                                    color = if (on) accent else accent.copy(alpha = 0.15f),
                                    topLeft = androidx.compose.ui.geometry.Offset(segStart, trackY),
                                    size = androidx.compose.ui.geometry.Size(segW, trackH),
                                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(trackH / 2)
                                )
                            }
                        }
                        7 -> {
                            // 光谱渐变
                            drawRoundRect(
                                brush = androidx.compose.ui.graphics.Brush.horizontalGradient(
                                    listOf(
                                        androidx.compose.ui.graphics.Color(0xFFFF5252),
                                        androidx.compose.ui.graphics.Color(0xFFFFEB3B),
                                        androidx.compose.ui.graphics.Color(0xFF4CAF50),
                                        androidx.compose.ui.graphics.Color(0xFF2196F3),
                                        androidx.compose.ui.graphics.Color(0xFF9C27B0)
                                    )
                                ),
                                topLeft = androidx.compose.ui.geometry.Offset(0f, trackY),
                                size = androidx.compose.ui.geometry.Size(fillWidth, trackH),
                                cornerRadius = androidx.compose.ui.geometry.CornerRadius(trackH / 2)
                            )
                        }
                        else -> {
                            // 默认：主题色
                            drawRoundRect(
                                color = accent,
                                topLeft = androidx.compose.ui.geometry.Offset(0f, trackY),
                                size = androidx.compose.ui.geometry.Size(fillWidth, trackH),
                                cornerRadius = androidx.compose.ui.geometry.CornerRadius(trackH / 2)
                            )
                        }
                    }
                    // 滑块
                    drawCircle(
                        color = androidx.compose.ui.graphics.Color.White,
                        radius = 5.dp.toPx(),
                        center = androidx.compose.ui.geometry.Offset(fillWidth, trackY + trackH / 2)
                    )
                    drawCircle(
                        color = accent,
                        radius = 3.5.dp.toPx(),
                        center = androidx.compose.ui.geometry.Offset(fillWidth, trackY + trackH / 2)
                    )
                }
            }
    )
}

fun formatTime(ms: Long): String {    val seconds = ms / 1000
    val minutes = seconds / 60
    val secs = seconds % 60
    return String.format("%d:%02d", minutes, secs)
}

fun parseLyric(lyricText: String): List<LyricLine> {
    val lines = mutableListOf<LyricLine>()
    val regex = Regex("\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)")
    lyricText.lines().forEach { line ->
        regex.find(line)?.let { match ->
            val minutes = match.groupValues[1].toIntOrNull() ?: 0
            val seconds = match.groupValues[2].toIntOrNull() ?: 0
            val millis = match.groupValues[3].toIntOrNull() ?: 0
            val text = match.groupValues[4].trim()
            if (text.isNotEmpty()) {
                val time = (minutes * 60L + seconds) * 1000 + millis * (if (match.groupValues[3].length == 3) 1 else 10)
                lines.add(LyricLine(time = time, text = text))
            }
        }
    }
    return lines.sortedBy { it.time }
}
