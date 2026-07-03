//
//  ContentView.kt
//  AndroidGenerate3
//
//  Single-file flagship Generate screen — Android port of Generate2/ContentView.swift.
//  Grid → derive → like → compose video → done.
//

package studio.femi.androidgenerate3

import android.app.Activity
import android.content.ClipDescription
import android.content.Context
import android.content.ContextWrapper
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.draganddrop.dragAndDropTarget
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Movie
import androidx.compose.material.icons.outlined.Photo
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draganddrop.DragAndDropEvent
import androidx.compose.ui.draganddrop.DragAndDropTarget
import androidx.compose.ui.draganddrop.mimeTypes
import androidx.compose.ui.draganddrop.toAndroidDragEvent
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import java.util.UUID

// MARK: - App root

/**
 * Root view of the AndroidGenerate3 library. Shows the grid + chrome.
 * The library owns no navigation and emits no internal routes.
 *
 * @param user user / password credentials passed on every Api call.
 * @param onUploadSong fired when the user taps the song-title slot in the toolbar.
 * @param onSelectionModeChanged fired when select-for-video mode toggles, so a
 *   host with its own bottom navigation can hide it — the Android equivalent of
 *   iOS's `.toolbar(.hidden, for: .tabBar)` while selecting.
 */
@Composable
fun ContentView(
    user: String,
    password: String,
    onUploadSong: suspend () -> Unit,
    menuItemName1: String,
    menuItemIcon1: ImageVector,
    onMenuItemTapped1: () -> Unit,
    onSelectionModeChanged: (Boolean) -> Unit = {},
) {
    GenerateTheme {
        Generate(
            user = user,
            password = password,
            onUploadSong = onUploadSong,
            menuItemName1 = menuItemName1,
            menuItemIcon1 = menuItemIcon1,
            onMenuItemTapped1 = onMenuItemTapped1,
            onSelectionModeChanged = onSelectionModeChanged,
        )
    }
}

// MARK: - Theme

object Theme {
    val background = Color(0xFF0A0A12)
    val surface = Color(0xFF171723)
    val onSurface = Color(0xFFF2F2F7)
    val muted = Color.White.copy(alpha = 0.6f)
    val accentMagenta = Color(0xFFFF2BD6)
    val accentBlue = Color(0xFF3AA0FF)

    val accent = Brush.horizontalGradient(listOf(accentMagenta, accentBlue))
}

/** Dark Material theme carrying the Generate palette; equivalent of `.preferredColorScheme(.dark)`. */
@Composable
internal fun GenerateTheme(content: @Composable () -> Unit) {
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            view.context.findActivity()?.window?.let { window ->
                WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = false
            }
        }
    }
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Theme.accentMagenta,
            secondary = Theme.accentBlue,
            background = Theme.background,
            surface = Theme.background,
            surfaceContainer = Theme.surface,
            surfaceContainerHigh = Theme.surface,
            onPrimary = Color.White,
            onBackground = Theme.onSurface,
            onSurface = Theme.onSurface,
            onSurfaceVariant = Theme.muted,
        ),
        content = content,
    )
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

/** Port of AccentButtonStyle — gradient capsule with press scale. */
@Composable
internal fun AccentButton(
    text: String,
    modifier: Modifier = Modifier,
    fullWidth: Boolean = true,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.97f else 1f,
        animationSpec = spring(dampingRatio = 0.7f),
        label = "accentButtonScale",
    )
    Box(
        modifier = modifier
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .then(if (fullWidth) Modifier.fillMaxWidth() else Modifier)
            .clip(CircleShape)
            .background(Theme.accent)
            .border(0.5.dp, Color.White.copy(alpha = 0.15f), CircleShape)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                onClick = onClick,
            )
            .padding(vertical = 16.dp, horizontal = if (fullWidth) 0.dp else 28.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text,
            color = Color.White,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

// MARK: - Local models (client-side state)

/**
 * A single timed lyric line. Server-side forced alignment is the production
 * path; SYLT extraction happens in the Api's Rust core.
 */
data class SongLine(
    val id: UUID,
    val index: Int,
    val text: String,
    val startMs: Int,
    val durationMs: Int,
)

data class GeneratedVideo(
    val id: UUID,
    val file: String,
    val posterFile: String,
    val sourceImageIds: List<String>,
)

enum class PendingState { Working, Failed }

/**
 * A video that's being generated in the background. The grid renders this as a
 * shimmer cell so the user can keep doing other things while it cooks.
 */
data class PendingVideo(
    val id: UUID,
    val sourceImageIds: List<String>,
    val posterFile: String,
    val state: PendingState = PendingState.Working,
)

/**
 * An image being uploaded from the user's photo library. Mirrors PendingVideo —
 * the grid shows a shimmer cell while the upload happens in the background.
 */
data class PendingImage(
    val id: UUID,
    val state: PendingState = PendingState.Working,
)

/**
 * An in-flight image generation (derive or fill-line). Rendered as a shimmer
 * cell in the grid so the rest of the UI stays interactive. [lineIndex] is
 * pre-computed at task start so the cell lands in the correct section.
 */
data class PendingGeneration(
    val id: UUID,
    val lineIndex: Int?,
    val state: PendingState = PendingState.Working,
)

// MARK: - Shared enums

enum class GenerationKind { Initial, Derived, Video }

sealed interface Phase {
    data class Generating(val kind: GenerationKind) : Phase
    data object Grid : Phase
    data object Complete : Phase
}

enum class GridFilter(val label: String) { All("All"), Liked("Liked"), Videos("Videos") }

// MARK: - Like store (reused by every image/video cell)

class LikeStore {
    var liked by mutableStateOf(setOf<String>())
        private set

    fun isLiked(key: String): Boolean = key in liked
    fun toggle(key: String) {
        liked = if (key in liked) liked - key else liked + key
    }

    fun setLiked(key: String, value: Boolean) {
        liked = if (value) liked + key else liked - key
    }
}

// MARK: - Drag payload

/** Drag payload label for moving an image between lyric line sections. */
internal const val DRAGGED_IMAGE_LABEL = "studio.femi.androidgenerate3.draggedImage"

// MARK: - Generate (the screen)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun Generate(
    user: String,
    password: String,
    onUploadSong: suspend () -> Unit,
    menuItemName1: String,
    menuItemIcon1: ImageVector,
    onMenuItemTapped1: () -> Unit,
    onSelectionModeChanged: (Boolean) -> Unit = {},
) {
    val vm: GenerateViewModel = viewModel()
    val context = LocalContext.current

    // SwiftUI re-runs `.task` on every appearance; mirror that with a re-scan
    // per composition entry (reload is idempotent).
    LaunchedEffect(Unit) { vm.reload() }

    LaunchedEffect(vm.isSelectingForVideo) {
        onSelectionModeChanged(vm.isSelectingForVideo)
    }

    // Photo picker (PhotosPicker equivalent) — the ViewModel reads and saves
    // the picked bytes so a configuration change can't drop them.
    val appContext = context.applicationContext
    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) vm.addPickedPhoto(appContext.contentResolver, uri)
    }

    // Android back cancels select-for-video mode, matching the toolbar Cancel.
    BackHandler(enabled = vm.isSelectingForVideo) {
        vm.isSelectingForVideo = false
        vm.selectedImageIds.clear()
    }

    Box(Modifier.fillMaxSize().background(Theme.background)) {
        Scaffold(
            containerColor = Theme.background,
            topBar = {
                GenerateTopBar(
                    vm = vm,
                    user = user,
                    password = password,
                    onUploadSong = onUploadSong,
                    onPickPhoto = {
                        photoPicker.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        )
                    },
                    menuItemName1 = menuItemName1,
                    menuItemIcon1 = menuItemIcon1,
                    onMenuItemTapped1 = onMenuItemTapped1,
                )
            },
            bottomBar = {
                AnimatedVisibility(
                    visible = vm.isSelectingForVideo,
                    enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
                    exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
                ) {
                    MakeVideoShelf(vm = vm, user = user, password = password)
                }
            },
        ) { innerPadding ->
            Box(Modifier.fillMaxSize().padding(innerPadding)) {
                when (val phase = vm.phase) {
                    is Phase.Generating -> GeneratingOverlay(phase.kind)
                    Phase.Grid -> GridView(vm = vm, user = user, password = password)
                    Phase.Complete -> CompletionView(onDone = { vm.phase = Phase.Grid })
                }
            }
        }

        // fullScreenCover equivalent — drawn above all chrome.
        vm.viewingVideo?.let { video ->
            VideoPreview(
                video = video,
                videoFile = vm.fileFor(video.file),
                posterFile = vm.fileFor(video.posterFile),
                onDismiss = { vm.viewingVideo = null },
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GenerateTopBar(
    vm: GenerateViewModel,
    user: String,
    password: String,
    onUploadSong: suspend () -> Unit,
    onPickPhoto: () -> Unit,
    menuItemName1: String,
    menuItemIcon1: ImageVector,
    onMenuItemTapped1: () -> Unit,
) {
    val colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
        containerColor = Theme.background,
        titleContentColor = Theme.onSurface,
    )
    if (vm.isSelectingForVideo) {
        CenterAlignedTopAppBar(
            colors = colors,
            navigationIcon = {
                TextButton(onClick = {
                    vm.isSelectingForVideo = false
                    vm.selectedImageIds.clear()
                }) {
                    Text("Cancel", color = Theme.onSurface)
                }
            },
            title = {
                AnimatedContent(targetState = vm.selectedImageIds.size, label = "pickedCount") { count ->
                    Text(
                        "$count of 3 picked",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = Theme.muted,
                    )
                }
            },
        )
    } else {
        var plusMenuExpanded by remember { mutableStateOf(false) }
        CenterAlignedTopAppBar(
            colors = colors,
            navigationIcon = {
                if (vm.isOnGrid) {
                    Box {
                        IconButton(onClick = { plusMenuExpanded = true }) {
                            Icon(
                                Icons.Filled.Add,
                                contentDescription = "Add",
                                tint = Theme.onSurface,
                            )
                        }
                        DropdownMenu(
                            expanded = plusMenuExpanded,
                            onDismissRequest = { plusMenuExpanded = false },
                        ) {
                            DropdownMenuItem(
                                text = { Text("Generate") },
                                leadingIcon = { Icon(Icons.Filled.AutoAwesome, contentDescription = null) },
                                onClick = {
                                    plusMenuExpanded = false
                                    vm.runDefaultGenerate(user, password)
                                },
                            )
                            DropdownMenuItem(
                                text = { Text("Upload from Photos") },
                                leadingIcon = { Icon(Icons.Outlined.Photo, contentDescription = null) },
                                onClick = {
                                    plusMenuExpanded = false
                                    onPickPhoto()
                                },
                            )
                            DropdownMenuItem(
                                text = { Text(menuItemName1) },
                                leadingIcon = { Icon(menuItemIcon1, contentDescription = null) },
                                onClick = {
                                    plusMenuExpanded = false
                                    onMenuItemTapped1()
                                },
                            )
                        }
                    }
                }
            },
            title = {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                    ) {
                        vm.uploadSongThenRefresh(onUploadSong)
                    },
                ) {
                    val song = vm.songFile
                    Text(
                        text = song ?: "No song",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = if (song != null) Theme.onSurface else Theme.muted,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    Icon(
                        Icons.Filled.KeyboardArrowDown,
                        contentDescription = null,
                        tint = Theme.muted,
                        modifier = Modifier.size(18.dp),
                    )
                }
            },
            actions = {
                if (vm.isOnGrid) {
                    val canMakeVideo = vm.canMakeVideo
                    TextButton(
                        onClick = {
                            if (!canMakeVideo) return@TextButton
                            vm.selectedImageIds.clear()
                            vm.isSelectingForVideo = true
                        },
                        enabled = canMakeVideo,
                        modifier = Modifier.semantics {
                            contentDescription = if (canMakeVideo) {
                                "Make video. Pick up to three of your saved pictures"
                            } else {
                                "Make video. Save at least one picture first"
                            }
                        },
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Icon(
                                Icons.Outlined.Movie,
                                contentDescription = null,
                                tint = if (canMakeVideo) Theme.onSurface else Theme.muted,
                                modifier = Modifier.size(18.dp),
                            )
                            Text(
                                "Make Video",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = if (canMakeVideo) Theme.onSurface else Theme.muted,
                            )
                        }
                    }
                }
            },
        )
    }
}

// MARK: - Generating overlay

@Composable
private fun GeneratingOverlay(kind: GenerationKind) {
    val title = when (kind) {
        GenerationKind.Initial -> "Making your pictures"
        GenerationKind.Derived -> "Making new ones"
        GenerationKind.Video -> "Making your video"
    }
    val subtitle = when (kind) {
        GenerationKind.Initial -> "Music's on. Just a moment."
        GenerationKind.Derived -> "Just a moment."
        GenerationKind.Video -> "Almost there."
    }
    Column(
        modifier = Modifier.fillMaxSize().background(Theme.background),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(contentAlignment = Alignment.Center) {
            Box(
                Modifier
                    .size(140.dp)
                    .blur(2.dp)
                    .border(3.dp, Theme.accentMagenta.copy(alpha = 0.4f), CircleShape)
            )
            CircularProgressIndicator(color = Theme.accentMagenta, modifier = Modifier.size(48.dp))
        }
        Spacer(Modifier.height(24.dp))
        Text(
            title,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = Theme.onSurface,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            subtitle,
            style = MaterialTheme.typography.bodyMedium,
            color = Theme.muted,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 32.dp),
        )
    }
}

// MARK: - Heart button (shared by image + video cells)

@Composable
internal fun HeartButton(isLiked: Boolean, onToggle: () -> Unit) {
    val haptics = LocalHapticFeedback.current
    Box(
        modifier = Modifier
            .padding(8.dp)
            .clip(CircleShape)
            .then(
                if (isLiked) Modifier.background(Theme.accent)
                else Modifier.background(Color.Black.copy(alpha = 0.25f))
            )
            .border(
                0.5.dp,
                Color.White.copy(alpha = if (isLiked) 0.35f else 0.4f),
                CircleShape,
            )
            .clickable {
                onToggle()
                haptics.performHapticFeedback(HapticFeedbackType.Confirm)
            }
            .padding(7.dp)
            .semantics {
                contentDescription = if (isLiked) "Saved, double tap to unsave" else "Save"
            },
    ) {
        Icon(
            if (isLiked) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(14.dp),
        )
    }
}

// MARK: - Make-video shelf

/** Commit shelf while picking pictures for a video (Photos pattern). */
@Composable
private fun MakeVideoShelf(vm: GenerateViewModel, user: String, password: String) {
    Surface(color = Theme.surface.copy(alpha = 0.97f)) {
        Box(
            Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 16.dp, vertical = 16.dp)
        ) {
            val hasSelection = vm.selectedImageIds.isNotEmpty()
            AccentButton(
                text = "Make video",
                enabled = hasSelection,
                modifier = Modifier.graphicsLayer { alpha = if (hasSelection) 1f else 0.5f },
                onClick = { vm.makeVideo(user, password) },
            )
        }
    }
}

// MARK: - Grid

/** Heterogeneous grid cell — the Kotlin stand-in for SwiftUI's per-type ForEach runs. */
private sealed interface Cell {
    data class PImage(val pending: PendingImage) : Cell
    data class PVideo(val pending: PendingVideo) : Cell
    data class PGen(val pending: PendingGeneration) : Cell
    data class Img(val file: String) : Cell
    data class Vid(val video: GeneratedVideo) : Cell
}

private val Cell.key: String
    get() = when (this) {
        is Cell.PImage -> "pi-${pending.id}"
        is Cell.PVideo -> "pv-${pending.id}"
        is Cell.PGen -> "pg-${pending.id}"
        is Cell.Img -> "img-$file"
        is Cell.Vid -> "vid-${video.id}"
    }

@Composable
private fun CellContent(cell: Cell, vm: GenerateViewModel) {
    when (cell) {
        is Cell.PImage -> PendingImageCell(
            pending = cell.pending,
            onDismissFailed = { vm.pendingImages.removeAll { it.id == cell.pending.id } },
        )
        is Cell.PVideo -> PendingVideoCell(
            pending = cell.pending,
            posterFile = vm.fileFor(cell.pending.posterFile),
            onDismissFailed = { vm.pendingVideos.removeAll { it.id == cell.pending.id } },
        )
        is Cell.PGen -> PendingGenerationCell(
            pending = cell.pending,
            onDismissFailed = { vm.pendingGenerations.removeAll { it.id == cell.pending.id } },
        )
        is Cell.Img -> ImageCell(image = cell.file, vm = vm)
        is Cell.Vid -> VideoCell(video = cell.video, vm = vm)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun GridView(vm: GenerateViewModel, user: String, password: String) {
    val filteredImages = when (vm.filter) {
        GridFilter.All, GridFilter.Videos -> vm.images.toList()
        GridFilter.Liked -> vm.images.filter { vm.likeStore.isLiked(it) }
    }
    val visibleVideos = when (vm.filter) {
        GridFilter.All, GridFilter.Videos -> vm.videos.toList()
        GridFilter.Liked -> vm.videos.filter { vm.likeStore.isLiked(it.id.toString()) }
    }
    val visiblePendingVideos = when (vm.filter) {
        GridFilter.All, GridFilter.Videos -> vm.pendingVideos.toList()
        GridFilter.Liked -> emptyList()
    }
    val visiblePendingImages =
        if (vm.filter == GridFilter.All) vm.pendingImages.toList() else emptyList()
    val visiblePendingGenerations =
        if (vm.filter == GridFilter.All) vm.pendingGenerations.toList() else emptyList()

    val imagesEmpty = vm.filter == GridFilter.Videos ||
        (filteredImages.isEmpty() && visiblePendingImages.isEmpty() && visiblePendingGenerations.isEmpty())
    val videosEmpty = visibleVideos.isEmpty() && visiblePendingVideos.isEmpty()
    val hasNoContent = imagesEmpty && videosEmpty

    val audiolines = vm.audiolines
    val shouldSection = vm.filter == GridFilter.All && audiolines != null

    Column(Modifier.fillMaxSize()) {
        FilterBar(filter = vm.filter, onSelect = { vm.filter = it })
        when {
            hasNoContent -> EmptyState(vm.filter)
            shouldSection && audiolines != null -> SectionedGrid(
                vm = vm,
                user = user,
                password = password,
                audiolines = audiolines,
                filteredImages = filteredImages,
                visibleVideos = visibleVideos,
                visiblePendingVideos = visiblePendingVideos,
                visiblePendingImages = visiblePendingImages,
                visiblePendingGenerations = visiblePendingGenerations,
            )
            else -> FlatGrid(
                vm = vm,
                filteredImages = filteredImages,
                visibleVideos = visibleVideos,
                visiblePendingVideos = visiblePendingVideos,
                visiblePendingImages = visiblePendingImages,
                visiblePendingGenerations = visiblePendingGenerations,
            )
        }
    }
}

/** Non-lazy 3-column grid used inside sectioned lists (cells per section are few). */
@Composable
private fun CellGridRows(cells: List<Cell>, vm: GenerateViewModel, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.padding(horizontal = 2.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        cells.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                row.forEach { cell ->
                    Box(Modifier.weight(1f)) { CellContent(cell, vm) }
                }
                repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** Drop target that assigns a dragged image to a lyric line. */
private fun lineDropTarget(vm: GenerateViewModel, line: SongLine): DragAndDropTarget =
    object : DragAndDropTarget {
        override fun onDrop(event: DragAndDropEvent): Boolean {
            val clip = event.toAndroidDragEvent().clipData ?: return false
            // Typed payload check — the equivalent of Swift's
            // `.dropDestination(for: DraggedImage.self)` rejecting foreign drags.
            if (clip.description?.label?.toString() != DRAGGED_IMAGE_LABEL) return false
            var dropped = false
            for (i in 0 until clip.itemCount) {
                val filename = clip.getItemAt(i).text?.toString() ?: continue
                vm.assignImageToLine(filename, line)
                dropped = true
            }
            return dropped
        }
    }

private fun isImageDrag(event: DragAndDropEvent): Boolean {
    if (!event.mimeTypes().contains(ClipDescription.MIMETYPE_TEXT_PLAIN)) return false
    return event.toAndroidDragEvent().clipDescription?.label?.toString() == DRAGGED_IMAGE_LABEL
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SectionedGrid(
    vm: GenerateViewModel,
    user: String,
    password: String,
    audiolines: List<SongLine>,
    filteredImages: List<String>,
    visibleVideos: List<GeneratedVideo>,
    visiblePendingVideos: List<PendingVideo>,
    visiblePendingImages: List<PendingImage>,
    visiblePendingGenerations: List<PendingGeneration>,
) {
    val unassignedPendings = visiblePendingGenerations.filter { it.lineIndex == null }
    val unassignedImages = filteredImages.filter { vm.imageLineIndex[it] == null }
    val unassignedCells: List<Cell> =
        visiblePendingImages.map { Cell.PImage(it) } +
            visiblePendingVideos.map { Cell.PVideo(it) } +
            unassignedPendings.map { Cell.PGen(it) } +
            unassignedImages.map { Cell.Img(it) }

    LazyColumn(Modifier.fillMaxSize()) {
        if (unassignedCells.isNotEmpty()) {
            item(key = "unassigned") {
                CellGridRows(unassignedCells, vm, Modifier.padding(top = 6.dp))
            }
        }
        audiolines.forEach { line ->
            val imagesForLine = filteredImages.filter { vm.imageLineIndex[it] == line.index }
            val pendingsForLine = visiblePendingGenerations.filter { it.lineIndex == line.index }
            val videosForLine = visibleVideos.filter { vm.videoLineIndex[it.file] == line.index }
            val count = imagesForLine.size + pendingsForLine.size + videosForLine.size

            stickyHeader(key = "header-${line.index}") {
                LineHeader(
                    line = line,
                    count = count,
                    vm = vm,
                    onFillLine = { vm.fillLine(user, password, line) },
                )
            }
            val cells: List<Cell> =
                pendingsForLine.map { Cell.PGen(it) } +
                    imagesForLine.map { Cell.Img(it) } +
                    videosForLine.map { Cell.Vid(it) }
            if (cells.isNotEmpty()) {
                item(key = "cells-${line.index}") {
                    val target = remember(line) { lineDropTarget(vm, line) }
                    CellGridRows(
                        cells,
                        vm,
                        Modifier
                            .padding(top = 4.dp)
                            .dragAndDropTarget(
                                shouldStartDragAndDrop = ::isImageDrag,
                                target = target,
                            ),
                    )
                }
            }
        }
        val orphanVideos = visibleVideos.filter { vm.videoLineIndex[it.file] == null }
        if (orphanVideos.isNotEmpty()) {
            item(key = "orphan-videos") {
                CellGridRows(
                    orphanVideos.map { Cell.Vid(it) },
                    vm,
                    Modifier.padding(top = 12.dp),
                )
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun LineHeader(
    line: SongLine,
    count: Int,
    vm: GenerateViewModel,
    onFillLine: () -> Unit,
) {
    var menuExpanded by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    val target = remember(line) { lineDropTarget(vm, line) }
    Box(
        Modifier
            .fillMaxWidth()
            .background(Theme.background)
            .dragAndDropTarget(shouldStartDragAndDrop = ::isImageDrag, target = target)
            .combinedClickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = {},
                onLongClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    menuExpanded = true
                },
            )
            .padding(horizontal = 16.dp)
            .padding(top = 28.dp, bottom = 10.dp)
            .semantics { contentDescription = line.text },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                line.text,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Theme.onSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                if (count == 0) "No pictures yet"
                else "$count ${if (count == 1) "picture" else "pictures"}",
                style = MaterialTheme.typography.bodyMedium,
                color = Theme.muted,
            )
        }
        DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
            DropdownMenuItem(
                text = { Text("Make pictures for this line") },
                leadingIcon = { Icon(Icons.Filled.AutoAwesome, contentDescription = null) },
                onClick = {
                    menuExpanded = false
                    onFillLine()
                },
            )
        }
    }
}

@Composable
private fun FlatGrid(
    vm: GenerateViewModel,
    filteredImages: List<String>,
    visibleVideos: List<GeneratedVideo>,
    visiblePendingVideos: List<PendingVideo>,
    visiblePendingImages: List<PendingImage>,
    visiblePendingGenerations: List<PendingGeneration>,
) {
    val cells: List<Cell> = buildList {
        if (vm.filter != GridFilter.Videos) {
            visiblePendingImages.forEach { add(Cell.PImage(it)) }
            visiblePendingGenerations.forEach { add(Cell.PGen(it)) }
            filteredImages.forEach { add(Cell.Img(it)) }
        }
        visiblePendingVideos.forEach { add(Cell.PVideo(it)) }
        visibleVideos.forEach { add(Cell.Vid(it)) }
    }
    LazyVerticalGrid(
        columns = GridCells.Fixed(3),
        verticalArrangement = Arrangement.spacedBy(2.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        contentPadding = PaddingValues(start = 2.dp, end = 2.dp, top = 6.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        items(cells, key = { it.key }) { cell ->
            Box(Modifier.animateItem()) { CellContent(cell, vm) }
        }
    }
}

@Composable
private fun EmptyState(filter: GridFilter) {
    val icon = when (filter) {
        GridFilter.All -> Icons.Outlined.PhotoLibrary
        GridFilter.Liked -> Icons.Outlined.FavoriteBorder
        GridFilter.Videos -> Icons.Outlined.Movie
    }
    val title = when (filter) {
        GridFilter.All -> "No pictures yet"
        GridFilter.Liked -> "Nothing hearted yet"
        GridFilter.Videos -> "No videos yet"
    }
    val body = when (filter) {
        GridFilter.All -> "Tap Start to make your first ones."
        GridFilter.Liked -> "Hold a picture to heart it. Hearted pictures can become videos."
        GridFilter.Videos -> "Heart a few pictures, then make a video."
    }
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Theme.muted, modifier = Modifier.size(48.dp))
        Spacer(Modifier.height(16.dp))
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = Theme.onSurface,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            body,
            style = MaterialTheme.typography.bodyMedium,
            color = Theme.muted,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 40.dp),
        )
    }
}

@Composable
private fun FilterBar(filter: GridFilter, onSelect: (GridFilter) -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        GridFilter.entries.forEach { f ->
            val selected = filter == f
            Box(
                modifier = Modifier
                    .clip(CircleShape)
                    .background(
                        if (selected) Theme.accentMagenta.copy(alpha = 0.25f)
                        else Color.White.copy(alpha = 0.08f)
                    )
                    .then(
                        if (selected) {
                            Modifier.border(1.dp, Theme.accentMagenta.copy(alpha = 0.6f), CircleShape)
                        } else Modifier
                    )
                    .clickable { onSelect(f) }
                    .padding(horizontal = 14.dp, vertical = 8.dp),
            ) {
                Text(
                    f.label,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = if (selected) Theme.onSurface else Theme.muted,
                )
            }
        }
        Spacer(Modifier.weight(1f))
    }
}

// MARK: - Completion

@Composable
private fun CompletionView(onDone: () -> Unit) {
    val pulse = rememberInfiniteTransition(label = "completionPulse")
    val t by pulse.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1600, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulse",
    )
    Column(
        modifier = Modifier.fillMaxSize().background(Theme.background),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))
        Box(contentAlignment = Alignment.Center) {
            Box(
                Modifier
                    .size((200 + 60 * t).dp)
                    .blur(30.dp)
                    .background(Theme.accentMagenta.copy(alpha = 0.2f + 0.3f * t), CircleShape)
            )
            Icon(
                Icons.Filled.Verified,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier
                    .size(96.dp)
                    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                    .drawWithCache {
                        onDrawWithContent {
                            drawContent()
                            drawRect(Theme.accent, blendMode = BlendMode.SrcAtop)
                        }
                    },
            )
        }
        Spacer(Modifier.height(32.dp))
        Text(
            "You did it.",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = Theme.onSurface,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            "That's a video. Make more whenever you want.",
            style = MaterialTheme.typography.bodyLarge,
            color = Theme.muted,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 32.dp),
        )
        Spacer(Modifier.weight(1f))
        AccentButton(
            text = "Done",
            onClick = onDone,
            modifier = Modifier.padding(horizontal = 24.dp).padding(bottom = 48.dp),
        )
    }
}
