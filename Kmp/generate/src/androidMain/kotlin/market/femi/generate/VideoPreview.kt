//
//  VideoPreview.kt
//  AndroidGenerate3
//
//  Full-screen video playback for the grid's video cell tap. Port of
//  Generate2/VideoPreview.swift — unmuted playback with audio focus, the
//  Android equivalent of switching AVAudioSession to .playback.
//

package market.femi.generate

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import coil3.compose.AsyncImage
import java.io.File

@Composable
internal fun VideoPreview(
    video: GeneratedVideo,
    videoFile: File?,
    posterFile: File?,
    onDismiss: () -> Unit,
) {
    BackHandler(onBack = onDismiss)
    var firstFrameRendered by remember { mutableStateOf(false) }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        if (videoFile != null) {
            val context = LocalContext.current
            val player = remember(videoFile) {
                ExoPlayer.Builder(context).build().apply {
                    // The user tapped to watch — that's consent for sound. Grab
                    // audio focus like iOS's .playback session category.
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(C.USAGE_MEDIA)
                            .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                            .build(),
                        /* handleAudioFocus = */ true,
                    )
                    setMediaItem(MediaItem.fromUri(Uri.fromFile(videoFile)))
                    volume = 1f
                    prepare()
                    playWhenReady = true
                }
            }
            val lifecycleOwner = LocalLifecycleOwner.current
            DisposableEffect(player, lifecycleOwner) {
                val listener = object : Player.Listener {
                    override fun onRenderedFirstFrame() {
                        firstFrameRendered = true
                    }
                }
                // Pause when the app is backgrounded — audio must not keep
                // playing after Home, unlike a released iOS fullScreenCover.
                val lifecycleObserver = LifecycleEventObserver { _, event ->
                    when (event) {
                        Lifecycle.Event.ON_STOP -> player.pause()
                        Lifecycle.Event.ON_START -> player.play()
                        else -> Unit
                    }
                }
                player.addListener(listener)
                lifecycleOwner.lifecycle.addObserver(lifecycleObserver)
                onDispose {
                    lifecycleOwner.lifecycle.removeObserver(lifecycleObserver)
                    player.removeListener(listener)
                    player.release()
                }
            }
            AndroidView(
                factory = { ctx ->
                    PlayerView(ctx).apply {
                        useController = true
                        setShutterBackgroundColor(android.graphics.Color.BLACK)
                    }
                },
                update = { it.player = player },
                onRelease = { it.player = null },
                modifier = Modifier.fillMaxSize(),
            )
        }
        if (!firstFrameRendered) {
            AsyncImage(
                model = posterFile,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
            CircularProgressIndicator(
                color = Color.White,
                modifier = Modifier.align(Alignment.Center).size(48.dp),
            )
        }
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .statusBarsPadding()
                .padding(16.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.35f))
                .clickable(onClick = onDismiss)
                .padding(12.dp),
        ) {
            Icon(Icons.Filled.Close, contentDescription = "Close", tint = Color.White)
        }
    }
}
