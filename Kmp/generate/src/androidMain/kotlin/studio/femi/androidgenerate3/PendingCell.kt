//
//  PendingCell.kt
//  AndroidGenerate3
//
//  Port of Generate2/PendingCell.swift.
//

package studio.femi.androidgenerate3

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import coil3.compose.SubcomposeAsyncImage
import java.io.File

// MARK: - Shimmer placeholder (used only by pending cells)

@Composable
internal fun Shimmer(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val phase by transition.animateFloat(
        initialValue = -1f,
        targetValue = 1.5f,
        animationSpec = infiniteRepeatable(
            animation = tween(1600, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "shimmerPhase",
    )
    Box(
        modifier
            .fillMaxSize()
            .clipToBounds()
            .background(Theme.surface)
            .drawBehind {
                val bandWidth = size.width * 0.7f
                val start = phase * size.width
                drawRect(
                    brush = Brush.horizontalGradient(
                        colors = listOf(
                            Color.Transparent,
                            Theme.accentMagenta.copy(alpha = 0.35f),
                            Theme.accentBlue.copy(alpha = 0.35f),
                            Color.Transparent,
                        ),
                        startX = start,
                        endX = start + bandWidth,
                    )
                )
            }
    )
}

@Composable
private fun WorkingOverlay(label: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = Color.White,
        )
    }
}

@Composable
private fun FailedOverlay(label: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Filled.Warning, contentDescription = null, tint = Color.White)
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = Color.White,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 8.dp),
        )
    }
}

// MARK: - Pending image upload cell

@Composable
internal fun PendingImageCell(pending: PendingImage, onDismissFailed: () -> Unit) {
    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .clipToBounds()
            .background(Theme.surface)
            .clickable(enabled = pending.state == PendingState.Failed) { onDismissFailed() },
        contentAlignment = Alignment.Center,
    ) {
        if (pending.state == PendingState.Working) {
            Shimmer()
            WorkingOverlay("Uploading…")
        } else {
            FailedOverlay("Upload failed — tap to dismiss")
        }
    }
}

// MARK: - Pending image-generation cell (derive / fill-line)

@Composable
internal fun PendingGenerationCell(pending: PendingGeneration, onDismissFailed: () -> Unit) {
    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .clipToBounds()
            .background(Theme.surface)
            .clickable(enabled = pending.state == PendingState.Failed) { onDismissFailed() },
        contentAlignment = Alignment.Center,
    ) {
        if (pending.state == PendingState.Working) {
            Shimmer()
            WorkingOverlay("Making…")
        } else {
            FailedOverlay("Failed — tap to dismiss")
        }
    }
}

// MARK: - Pending video cell (poster + shimmer)

@Composable
internal fun PendingVideoCell(
    pending: PendingVideo,
    posterFile: File?,
    onDismissFailed: () -> Unit,
) {
    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .clipToBounds()
            .background(Theme.surface)
            .clickable(enabled = pending.state == PendingState.Failed) { onDismissFailed() },
        contentAlignment = Alignment.Center,
    ) {
        SubcomposeAsyncImage(
            model = posterFile,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            loading = { Shimmer() },
            error = { Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f))) },
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    alpha = if (pending.state == PendingState.Failed) 0.5f else 0.4f
                },
        )
        if (pending.state == PendingState.Working) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                Text(
                    "Making…",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                )
            }
        } else {
            FailedOverlay("Failed — tap to dismiss")
        }
    }
}
