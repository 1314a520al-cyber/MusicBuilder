package com.music.app

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.music.app.ui.screen.DiscoverScreen
import com.music.app.ui.screen.LibraryScreen
import com.music.app.ui.screen.PlayerScreen
import com.music.app.ui.screen.ProfileScreen
import com.music.app.ui.screen.SearchScreen

sealed class Screen(val route: String, val title: String, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    data object Discover : Screen("discover", "发现", Icons.Default.Home)
    data object Search : Screen("search", "搜索", Icons.Default.Search)
    data object Library : Screen("library", "音乐库", Icons.Default.Favorite)
    data object Profile : Screen("profile", "我的", Icons.Default.Person)
}

@Composable
fun MusicApp() {
    var currentScreen by remember { mutableStateOf<Screen>(Screen.Discover) }
    var showPlayer by remember { mutableStateOf(false) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                listOf(Screen.Discover, Screen.Search, Screen.Library, Screen.Profile).forEach { screen ->
                    NavigationBarItem(
                        icon = { Icon(screen.icon, contentDescription = screen.title) },
                        label = { Text(screen.title) },
                        selected = currentScreen.route == screen.route,
                        onClick = { currentScreen = screen }
                    )
                }
            }
        }
    ) { padding ->
        androidx.compose.foundation.layout.Box(modifier = Modifier.padding(padding)) {
            when (currentScreen) {
                is Screen.Discover -> DiscoverScreen(onPlaySong = { showPlayer = true })
                is Screen.Search -> SearchScreen(onPlaySong = { showPlayer = true })
                is Screen.Library -> LibraryScreen(onPlaySong = { showPlayer = true })
                is Screen.Profile -> ProfileScreen()
            }
        }
    }

    if (showPlayer) {
        PlayerScreen(onDismiss = { showPlayer = false })
    }
}
