package com.music.app.ui.theme

import androidx.compose.ui.graphics.Color

// 20 套主题配色（与 iOS 版对齐）
data class ThemeColor(
    val name: String,
    val primary: Color,
    val secondary: Color,
    val gradient: List<Color>
)

val ThemeColors = listOf(
    ThemeColor("默认紫", Color(0xFF6750A4), Color(0xFFB69DF8), listOf(Color(0xFF6750A4), Color(0xFFB69DF8))),
    ThemeColor("珊瑚橙", Color(0xFFFF6B6B), Color(0xFFFFA07A), listOf(Color(0xFFFF6B6B), Color(0xFFFFA07A))),
    ThemeColor("海洋蓝", Color(0xFF2196F3), Color(0xFF03A9F4), listOf(Color(0xFF2196F3), Color(0xFF03A9F4))),
    ThemeColor("薰衣草", Color(0xFF9C27B0), Color(0xFFCE93D8), listOf(Color(0xFF9C27B0), Color(0xFFCE93D8))),
    ThemeColor("玫瑰金", Color(0xFFE91E63), Color(0xFFF48FB1), listOf(Color(0xFFE91E63), Color(0xFFF48FB1))),
    ThemeColor("夕阳红", Color(0xFFFF5722), Color(0xFFFF8A65), listOf(Color(0xFFFF5722), Color(0xFFFF8A65))),
    ThemeColor("极光绿", Color(0xFF00C853), Color(0xFF69F0AE), listOf(Color(0xFF00C853), Color(0xFF69F0AE))),
    ThemeColor("香槟金", Color(0xFFFFD700), Color(0xFFFFECB3), listOf(Color(0xFFFFD700), Color(0xFFFFECB3))),
    ThemeColor("午夜蓝", Color(0xFF1A237E), Color(0xFF3949AB), listOf(Color(0xFF1A237E), Color(0xFF3949AB))),
    ThemeColor("深空灰", Color(0xFF424242), Color(0xFF757575), listOf(Color(0xFF424242), Color(0xFF757575))),
    ThemeColor("樱桃红", Color(0xFFD32F2F), Color(0xFFEF5350), listOf(Color(0xFFD32F2F), Color(0xFFEF5350))),
    ThemeColor("薄荷绿", Color(0xFF1DE9B6), Color(0xFF64FFDA), listOf(Color(0xFF1DE9B6), Color(0xFF64FFDA))),
    ThemeColor("天空蓝", Color(0xFF03A9F4), Color(0xFF81D4FA), listOf(Color(0xFF03A9F4), Color(0xFF81D4FA))),
    ThemeColor("柠檬黄", Color(0xFFFFEB3B), Color(0xFFFFF59D), listOf(Color(0xFFFFEB3B), Color(0xFFFFF59D))),
    ThemeColor("蜜桃粉", Color(0xFFFF80AB), Color(0xFFFFCDD2), listOf(Color(0xFFFF80AB), Color(0xFFFFCDD2))),
    ThemeColor("翡翠绿", Color(0xFF009688), Color(0xFF4DB6AC), listOf(Color(0xFF009688), Color(0xFF4DB6AC))),
    ThemeColor("靛蓝", Color(0xFF3F51B5), Color(0xFF7986CB), listOf(Color(0xFF3F51B5), Color(0xFF7986CB))),
    ThemeColor("琥珀", Color(0xFFFFC107), Color(0xFFFFE082), listOf(Color(0xFFFFC107), Color(0xFFFFE082))),
    ThemeColor("蓝绿", Color(0xFF00BCD4), Color(0xFF4DD0E1), listOf(Color(0xFF00BCD4), Color(0xFF4DD0E1))),
    ThemeColor("深紫", Color(0xFF4A148C), Color(0xFF7B1FA2), listOf(Color(0xFF4A148C), Color(0xFF7B1FA2)))
)

val White = Color(0xFFFFFFFF)
val Black = Color(0xFF000000)
val Gray = Color(0xFF9E9E9E)
val LightGray = Color(0xFFF5F5F5)
val DarkGray = Color(0xFF212121)
