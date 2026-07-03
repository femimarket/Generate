//
//  VideoCell.kt
//  AndroidGenerate3
//
//  Port of Generate2/VideoCell.swift — auto-muted looping grid video cell.
//

package market.femi.generate

import android.net.Uri
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import coil3.compose.AsyncImage
import java.io.File

// MARK: - Auto-muted looping video view

/**
 * Muted looping autoplay, like the Swift PlayerUIView. Pauses while the app is
 * stopped and falls back to the poster (or dark surface) if the device runs
 * out of video decoders.
 */
@OptIn(UnstableApi::class)
@Composable
internal fun LoopingVideoView(file: File, posterFile: File?, modifier: Modifier = Modifier) {
    var playbackFailed by remember(file) { mutableStateOf(false) }
    if (playbackFailed) {
        Box(modifier.background(Theme.surface)) {
            if (posterFile != null) {
                AsyncImage(
                    model = posterFile,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
        return
    }

    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val player = remember(file) {
        ExoPlayer.Builder(context).build().apply {
            setMediaItem(MediaItem.fromUri(Uri.fromFile(file)))
            volume = 0f
            repeatMode = Player.REPEAT_MODE_ONE
            prepare()
            playWhenReady = true
        }
    }
    DisposableEffect(player, lifecycleOwner) {
        val errorListener = object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                playbackFailed = true
            }
        }
        val lifecycleObserver = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_STOP -> player.pause()
                Lifecycle.Event.ON_START -> player.play()
                else -> Unit
            }
        }
        player.addListener(errorListener)
        lifecycleOwner.lifecycle.addObserver(lifecycleObserver)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(lifecycleObserver)
            player.removeListener(errorListener)
            player.release()
        }
    }
    AndroidView(
        factory = { ctx ->
            PlayerView(ctx).apply {
                useController = false
                resizeMode = AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                setShutterBackgroundColor(android.graphics.Color.BLACK)
            }
        },
        update = { it.player = player },
        onRelease = { it.player = null },
        modifier = modifier,
    )
}

// MARK: - Grid video cell

@Composable
internal fun VideoCell(video: GeneratedVideo, vm: GenerateViewModel) {
    val selecting = vm.isSelectingForVideo
    val likeKey = video.id.toString()
    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .clipToBounds()
            .background(Color.Black)
            .graphicsLayer { alpha = if (selecting) 0.3f else 1f }
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                enabled = !selecting,
            ) { vm.viewingVideo = video }
            .semantics {
                contentDescription = "Video, double tap to watch"
                stateDescription = if (vm.likeStore.isLiked(likeKey)) "Saved" else ""
            },
    ) {
        vm.fileFor(video.file)?.let { file ->
            LoopingVideoView(
                file = file,
                posterFile = vm.fileFor(video.posterFile),
                modifier = Modifier.fillMaxSize(),
            )
        }
        Icon(
            Icons.Filled.PlayCircle,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.85f),
            modifier = Modifier
                .align(Alignment.Center)
                .size(28.dp)
                .shadow(4.dp, CircleShape, clip = false),
        )
        if (!selecting) {
            Box(Modifier.align(Alignment.TopEnd)) {
                HeartButton(
                    isLiked = vm.likeStore.isLiked(likeKey),
                    onToggle = { vm.likeStore.toggle(likeKey) },
                )
            }
        }
    }
}
