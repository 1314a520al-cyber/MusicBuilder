package com.music.app.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import com.music.app.util.Preferences

private val DarkColorScheme = darkColorScheme(
    primary = ThemeColors[0].primary,
    secondary = ThemeColors[0].secondary,
    tertiary = ThemeColors[0].secondary
)

private val LightColorScheme = lightColorScheme(
    primary = ThemeColors[0].primary,
    secondary = ThemeColors[0].secondary,
    tertiary = ThemeColors[0].secondary
)

@Composable
fun MusicTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val themeIndex = Preferences.get().themeIndex.coerceIn(0, ThemeColors.size - 1)
    val useDark = Preferences.get().darkMode || darkTheme
    val colorScheme = if (useDark) {
        darkColorScheme(
            primary = ThemeColors[themeIndex].primary,
            secondary = ThemeColors[themeIndex].secondary,
            tertiary = ThemeColors[themeIndex].secondary
        )
    } else {
        lightColorScheme(
            primary = ThemeColors[themeIndex].primary,
            secondary = ThemeColors[themeIndex].secondary,
            tertiary = ThemeColors[themeIndex].secondary
        )
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !useDark
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = MaterialTheme.typography,
        content = content
    )
}
