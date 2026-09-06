package com.music.app.ui.components

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.changedToUp
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp

/**
 * 轻量下拉刷新容器：不依赖 material3 版本。
 * 通过嵌套滚动感知列表顶部下拉，松手且超过阈值时触发 onRefresh。
 */
@Composable
fun PullRefreshBox(
    isRefreshing: Boolean,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit
) {
    val density = LocalDensity.current
    val thresholdPx = with(density) { 68.dp.toPx() }
    val maxPullPx = with(density) { 120.dp.toPx() }
    var pullOffset by remember { mutableFloatStateOf(0f) }

    val connection = remember {
        object : NestedScrollConnection {
            override fun onPostScroll(
                consumed: Offset,
                available: Offset,
                source: NestedScrollSource
            ): Offset {
                val dy = available.y
                if (dy > 0 && !isRefreshing) {
                    pullOffset = (pullOffset + dy * 0.5f).coerceAtMost(maxPullPx)
                    return Offset(0f, dy)
                }
                return Offset.Zero
            }
        }
    }

    Box(
        modifier = modifier
            .nestedScroll(connection)
            .pointerInput(Unit) {
                awaitEachGesture {
                    awaitFirstDown()
                    // 等待手指抬起
                    do {
                        val event = awaitPointerEvent()
                    } while (event.changes.none { it.changedToUp() })
                    if (pullOffset >= thresholdPx && !isRefreshing) {
                        onRefresh()
                    }
                    pullOffset = 0f
                }
            }
    ) {
        content()
        if (pullOffset > 0f || isRefreshing) {
            CircularProgressIndicator(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 10.dp)
                    .size(26.dp),
                color = MaterialTheme.colorScheme.primary,
                strokeWidth = 2.5.dp
            )
        }
    }
}
