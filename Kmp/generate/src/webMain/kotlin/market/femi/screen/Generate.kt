@file:OptIn(
    ExperimentalUuidApi::class,
    ExperimentalEncodingApi::class,
    ExperimentalFoundationApi::class,
)

package market.femi.screen

// Generate screen — the flagship grid: make pictures → heart → compose video.
// Verbatim port of Generate2/ContentView.swift plus its cell files (ImageCell,
// VideoCell, PendingCell, VideoPreview). Grid renders images/videos sectioned
// under the song's lyric lines (SYLT) when a song is loaded; a bottom shelf
// commits 1–3 hearted pictures into a music-video via qwen (prompt) → LTX-2.
// State lives in the composable, mirroring the Swift @State dump. Dark navy Theme.

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeContentPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.BrokenImage
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import market.femi.api.NativeVideo
import market.femi.api.NativeVideoState
import market.femi.api.clipAudio
import market.femi.api.decodeImageBitmap
import market.femi.api.jsDateNow
import market.femi.api.pickFile
import market.femi.api.readBlob
import market.femi.api.revokeBlobUrl
import market.femi.api.readFileBytes
import market.femi.api.toByteArray
import market.femi.api.ChatMessage
import market.femi.api.ProjectService
import market.femi.api.Role
import market.femi.api.flux2Pro
import market.femi.api.ltx2_3a2v
import market.femi.api.nanoBanana2
import market.femi.api.qwen3_6_35b_a3b
import market.femi.api.zImageTurbo
import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi
import kotlin.uuid.ExperimentalUuidApi
import kotlin.uuid.Uuid

// MARK: - Theme

private object Theme {
    val background = Color(0.039f, 0.039f, 0.071f)
    val surface = Color(0.090f, 0.090f, 0.137f)
    val onSurface = Color(0.949f, 0.949f, 0.969f)
    val muted = Color.White.copy(alpha = 0.6f)
    val accentMagenta = Color(1.0f, 0.169f, 0.839f)
    val accentBlue = Color(0.227f, 0.627f, 1.0f)
    val accent = Brush.horizontalGradient(listOf(accentMagenta, accentBlue))
}

// MARK: - Models (mirror the Swift structs)

private enum class GenState { Working, Failed }

private data class GeneratedVideo(
    val id: Uuid = Uuid.random(),
    val file: String,
    val posterFile: String,
    val sourceImageIds: List<String>,
)

private data class PendingVideo(
    val id: Uuid = Uuid.random(),
    val sourceImageIds: List<String>,
    val posterFile: String,
    val state: GenState = GenState.Working,
)

private data class PendingImage(val id: Uuid = Uuid.random(), val state: GenState = GenState.Working)

private data class PendingGeneration(
    val id: Uuid = Uuid.random(),
    val lineIndex: Int?,
    val state: GenState = GenState.Working,
)

private enum class GenerationKind { Initial, Derived, Video }

private sealed interface Phase {
    data class Generating(val kind: GenerationKind) : Phase
    data object Grid : Phase
    data object Complete : Phase
}

private enum class GridFilter(val label: String) { All("All"), Liked("Liked"), Videos("Videos") }

// MARK: - Like store (shared by every image/video cell)

private class LikeStore {
    val liked = mutableStateListOf<String>()
    fun isLiked(key: String) = liked.contains(key)
    fun toggle(key: String) { if (liked.contains(key)) liked.remove(key) else liked.add(key) }
    fun setLiked(key: String, value: Boolean) {
        if (value) { if (!liked.contains(key)) liked.add(key) } else liked.remove(key)
    }
}

// MARK: - File-private helpers

private fun sniffExt(bytes: ByteArray): String {
    fun at(i: Int) = if (i < bytes.size) bytes[i].toInt() and 0xFF else -1
    return when {
        at(0) == 0x89 && at(1) == 0x50 && at(2) == 0x4E && at(3) == 0x47 -> "png"
        at(0) == 0xFF && at(1) == 0xD8 && at(2) == 0xFF -> "jpg"
        at(0) == 0x47 && at(1) == 0x49 && at(2) == 0x46 -> "gif"
        at(0) == 0x52 && at(8) == 0x57 && at(9) == 0x45 && at(10) == 0x42 && at(11) == 0x50 -> "webp"
        else -> "png"
    }
}

/// Persist bytes returned by an Api method to OPFS under a fresh local filename.
/// `ext` is sniffed from the bytes when not supplied (video callers pass "mp4").
private suspend fun saveResponseData(
    data: ByteArray,
    ext: String? = null,
    prompt: String? = null,
    model: String? = null,
    subject: List<String>? = null,
): String {
    val finalExt = ext ?: sniffExt(data)
    val name = "gen-${Uuid.random()}.$finalExt"
    ProjectService.saveFile(data, named = name, prompt = prompt, model = model, subject = subject)
    return name
}

/// Read a project file from OPFS as raw bytes — the new Api contract for
/// `image` / `audio` parameters (which then base64-encode for the FFI).
private suspend fun bytesOf(file: String): ByteArray = readFileBytes(file).toByteArray()

private val imageExts = setOf("png", "jpg", "jpeg", "webp", "gif", "heic", "heif")

private const val DEFAULT_PROMPT =
    "cinematic music video still, vivid color grade, dramatic lighting, expressive performer mid-motion, " +
        "shallow depth of field, 35mm film grain, emotional and atmospheric"

// MARK: - Generate (the screen)

@Composable
fun GenerateImage(user: String, password: String, onEngineer: () -> Unit = {}) {
    val scope = rememberCoroutineScope()

    // All screen state — mirrors the Swift @State dump.
    var phase by remember { mutableStateOf<Phase>(Phase.Grid) }
    var filter by remember { mutableStateOf(GridFilter.All) }
    var isSelectingForVideo by remember { mutableStateOf(false) }
    val selectedImageIds = remember { mutableStateListOf<String>() }
    var viewingVideo by remember { mutableStateOf<GeneratedVideo?>(null) }
    val images = remember { mutableStateListOf<String>() }
    val imageLineIndex = remember { mutableStateMapOf<String, Int>() }
    val videoLineIndex = remember { mutableStateMapOf<String, Int>() }
    val videos = remember { mutableStateListOf<GeneratedVideo>() }
    val pendingVideos = remember { mutableStateListOf<PendingVideo>() }
    val pendingImages = remember { mutableStateListOf<PendingImage>() }
    val pendingGenerations = remember { mutableStateListOf<PendingGeneration>() }
    var audiolines by remember { mutableStateOf<List<SongLine>?>(null) }
    val likeStore = remember { LikeStore() }
    var songName by remember { mutableStateOf<String?>(null) }
    var menuExpanded by remember { mutableStateOf(false) }
    var movingImage by remember { mutableStateOf<String?>(null) }

    val canMakeVideo = images.any { likeStore.isLiked(it) }

    // ---- lyric extraction (off-main SYLT read, then assign lines to loose images) ----
    fun extractAudiolines(filename: String) {
        scope.launch {
            val lines = LyricExtractor.read(filename)
            if (lines.isEmpty()) return@launch
            audiolines = lines
            var nextLine = 0
            for (i in images.indices) {
                if (imageLineIndex[images[i]] == null) {
                    imageLineIndex[images[i]] = lines[nextLine % lines.size].index
                    nextLine++
                }
            }
        }
    }

    // ---- initial load: rehydrate grid from disk ----
    LaunchedEffect(Unit) {
        val existingImages = images.toSet()
        val existingVideos = videos.map { it.file }.toSet()
        for (filename in ProjectService.getAllGenerations()) {
            val ext = filename.substringAfterLast('.', "").lowercase()
            when {
                ext in imageExts -> if (filename !in existingImages) {
                    images.add(filename)
                    ProjectService.getSubject(filename)?.mapNotNull { it.toIntOrNull() }?.firstOrNull()?.let {
                        imageLineIndex[filename] = it
                    }
                }
                ext == "mp4" -> if (filename !in existingVideos) {
                    videos.add(GeneratedVideo(file = filename, posterFile = "", sourceImageIds = emptyList()))
                    ProjectService.getSubject(filename)?.mapNotNull { it.toIntOrNull() }?.firstOrNull()?.let {
                        videoLineIndex[filename] = it
                    }
                }
            }
        }
        for (image in images) if (ProjectService.getLike(image)) likeStore.setLiked(image, true)
        val song = ProjectService.getAudio()
        songName = song
        if (song != null) extractAudiolines(song)
    }

    // ---- song upload (toolbar principal) ----
    fun uploadSong() {
        scope.launch {
            val name = pickFile().firstOrNull() ?: return@launch
            val bytes = runCatching { bytesOf(name) }.getOrNull() ?: return@launch
            ProjectService.saveAudio(bytes, name)
            audiolines = null
            val song = ProjectService.getAudio()
            songName = song
            if (song != null) extractAudiolines(song)
        }
    }

    // ---- upload from photos ----
    fun uploadPhoto() {
        scope.launch {
            val name = pickFile().firstOrNull() ?: return@launch
            val bytes = runCatching { bytesOf(name) }.getOrNull() ?: return@launch
            val newName = "upload-${Uuid.random()}.jpg"
            ProjectService.saveFile(bytes, named = newName)
            images.add(newName)
        }
    }

    // ---- 3-model fan-out (default Generate) ----
    fun runDefaultGenerate() {
        val pendings = List(3) { PendingGeneration(lineIndex = null) }
        val queue = pendings.map { it.id }.toMutableList()
        pendingGenerations.addAll(pendings)
        val models: List<Pair<String, suspend () -> ByteArray>> = listOf(
            "Flux2Pro" to { flux2Pro(user, password, DEFAULT_PROMPT) },
            "NanoBanana2" to { nanoBanana2(user, password, DEFAULT_PROMPT) },
            "ZImageTurbo" to { zImageTurbo(user, password, DEFAULT_PROMPT) },
        )
        scope.launch {
            val jobs = models.map { (model, call) ->
                launch {
                    val data = runCatching { call() }.getOrNull()
                    if (data != null) {
                        val file = saveResponseData(data, model = model)
                        if (queue.isNotEmpty()) {
                            val pid = queue.removeAt(0)
                            pendingGenerations.removeAll { it.id == pid }
                            images.add(file)
                        }
                    }
                }
            }
            jobs.forEach { it.join() }
            for (pid in queue) {
                val i = pendingGenerations.indexOfFirst { it.id == pid }
                if (i >= 0) pendingGenerations[i] = pendingGenerations[i].copy(state = GenState.Failed)
            }
        }
    }

    // ---- per-line generate (contextMenu on a section header) ----
    fun fillLine(line: SongLine) {
        val lineIndex = line.index
        val prompt = line.text
        val pendings = List(3) { PendingGeneration(lineIndex = lineIndex) }
        val queue = pendings.map { it.id }.toMutableList()
        pendingGenerations.addAll(pendings)
        val models: List<Pair<String, suspend () -> ByteArray>> = listOf(
            "Flux2Pro" to { flux2Pro(user, password, prompt) },
            "NanoBanana2" to { nanoBanana2(user, password, prompt) },
            "ZImageTurbo" to { zImageTurbo(user, password, prompt) },
        )
        scope.launch {
            val jobs = models.map { (model, call) ->
                launch {
                    val data = runCatching { call() }.getOrNull()
                    if (data != null) {
                        val file = saveResponseData(data, prompt = prompt, model = model, subject = listOf("line:$lineIndex"))
                        if (queue.isNotEmpty()) {
                            val pid = queue.removeAt(0)
                            pendingGenerations.removeAll { it.id == pid }
                            images.add(file)
                            imageLineIndex[file] = lineIndex
                        }
                    }
                }
            }
            jobs.forEach { it.join() }
            for (pid in queue) {
                val i = pendingGenerations.indexOfFirst { it.id == pid }
                if (i >= 0) pendingGenerations[i] = pendingGenerations[i].copy(state = GenState.Failed)
            }
        }
    }

    // ---- move an image to a lyric line (the Swift drag→section reassignment) ----
    fun moveImageToLine(image: String, line: SongLine) {
        movingImage = null
        imageLineIndex[image] = line.index
        scope.launch {
            val data = runCatching { bytesOf(image) }.getOrNull() ?: return@launch
            ProjectService.saveFile(
                data,
                named = image,
                prompt = ProjectService.getPrompt(image),
                model = ProjectService.getModel(image),
                subject = listOf("${line.index}", line.text),
            )
        }
    }

    // ---- compose the video from the picked pictures ----
    fun makeVideo() {
        val ids = selectedImageIds.toList()
        val primary = ids.firstOrNull() ?: return
        isSelectingForVideo = false
        selectedImageIds.clear()
        val pending = PendingVideo(sourceImageIds = ids, posterFile = primary)
        pendingVideos.add(pending)
        scope.launch {
            // Faithful to Swift (`ProjectService.getAudio()!`): the app assumes a song is
            // always loaded. No song → this throws and no video is made (product edge case).
            val audioFile = ProjectService.getAudio()!!
            val imagePrompts = ids.mapNotNull { ProjectService.getPrompt(it) }
            val imageData = bytesOf(primary)

            val lineIndex = imageLineIndex[primary]
            val line = lineIndex?.let { li -> audiolines?.firstOrNull { it.index == li } }
            val audioData: ByteArray =
                if (line != null) runCatching { clipAudio(bytesOf(audioFile), line.startMs, 10_000) }.getOrElse { bytesOf(audioFile) }
                else bytesOf(audioFile)

            val instruction = buildString {
                append("Convert these ${imagePrompts.size} image prompts into a timestamped music-video prompt ")
                append("with exactly ${imagePrompts.size} multishot timestamps. Under 100 words. ")
                append("Return only the prompt itself — no title, no preamble, no commentary, no trailing notes, no markdown.\n\n")
                append(imagePrompts.joinToString("\n---\n"))
            }
            val chatReply = qwen3_6_35b_a3b(user, password, listOf(ChatMessage(Role.User, instruction)))
            val prompt = chatReply.lastOrNull()?.content
            if (prompt.isNullOrEmpty()) {
                val idx = pendingVideos.indexOfFirst { it.id == pending.id }
                if (idx >= 0) pendingVideos[idx] = pendingVideos[idx].copy(state = GenState.Failed)
                return@launch
            }
            val videoData = ltx2_3a2v(
                user, password,
                imageB64 = Base64.encode(imageData),
                audioB64 = Base64.encode(audioData),
                prompt = prompt,
            )
            val lineSubject = if (lineIndex != null && line != null) listOf("$lineIndex", line.text) else null
            val file = saveResponseData(videoData, ext = "mp4", prompt = prompt, model = "Ltx23A2V", subject = lineSubject)
            pendingVideos.removeAll { it.id == pending.id }
            videos.add(GeneratedVideo(file = file, posterFile = primary, sourceImageIds = ids))
            imageLineIndex[primary]?.let { videoLineIndex[file] = it }
        }
    }

    // ---- derived visible lists (mirror GridView computed vars) ----
    val filteredImages = when (filter) {
        GridFilter.All, GridFilter.Videos -> images.toList()
        GridFilter.Liked -> images.filter { likeStore.isLiked(it) }
    }
    val visibleVideos = when (filter) {
        GridFilter.All, GridFilter.Videos -> videos.toList()
        GridFilter.Liked -> videos.filter { likeStore.isLiked(it.id.toString()) }
    }
    val visiblePendingVideos = when (filter) {
        GridFilter.All, GridFilter.Videos -> pendingVideos.toList()
        GridFilter.Liked -> emptyList()
    }
    val visiblePendingImages = if (filter == GridFilter.All) pendingImages.toList() else emptyList()
    val visiblePendingGenerations = if (filter == GridFilter.All) pendingGenerations.toList() else emptyList()
    val shouldSection = filter == GridFilter.All && audiolines != null

    CompositionLocalProvider(LocalBrandFont provides brandFamily()) {
        Box(Modifier.fillMaxSize().background(Theme.background)) {
            Column(
                Modifier
                    .safeContentPadding()
                    .widthIn(max = 620.dp)
                    .fillMaxSize()
                    .align(Alignment.TopCenter),
            ) {
                // ---- top bar ----
                TopBar(
                    isSelectingForVideo = isSelectingForVideo,
                    selectedCount = selectedImageIds.size,
                    songName = songName,
                    canMakeVideo = canMakeVideo,
                    menuExpanded = menuExpanded,
                    onMenuExpandedChange = { menuExpanded = it },
                    onGenerate = { menuExpanded = false; runDefaultGenerate() },
                    onUploadPhoto = { menuExpanded = false; uploadPhoto() },
                    onEngineer = { menuExpanded = false; onEngineer() },
                    onSong = { uploadSong() },
                    onMakeVideoTap = {
                        if (canMakeVideo) {
                            selectedImageIds.clear()
                            isSelectingForVideo = true
                        }
                    },
                    onCancelSelection = {
                        isSelectingForVideo = false
                        selectedImageIds.clear()
                    },
                )

                // ---- content ----
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    when (val p = phase) {
                        is Phase.Generating -> GeneratingOverlay(p.kind)
                        Phase.Complete -> CompletionView(onDone = { phase = Phase.Grid })
                        Phase.Grid -> {
                            Column(Modifier.fillMaxSize()) {
                                FilterBar(filter) { filter = it }
                                GridBody(
                                    filter = filter,
                                    shouldSection = shouldSection,
                                    audiolines = audiolines,
                                    filteredImages = filteredImages,
                                    visibleVideos = visibleVideos,
                                    visiblePendingImages = visiblePendingImages,
                                    visiblePendingVideos = visiblePendingVideos,
                                    visiblePendingGenerations = visiblePendingGenerations,
                                    imageLineIndex = imageLineIndex,
                                    videoLineIndex = videoLineIndex,
                                    isSelectingForVideo = isSelectingForVideo,
                                    selectedImageIds = selectedImageIds,
                                    likeStore = likeStore,
                                    bottomMargin = if (isSelectingForVideo) 80.dp else 0.dp,
                                    onToggleImageLike = { img ->
                                        likeStore.toggle(img)
                                        scope.launch { ProjectService.like(img, likeStore.isLiked(img)) }
                                    },
                                    onToggleVideoLike = { likeStore.toggle(it) },
                                    onSelectImage = { img ->
                                        if (!likeStore.isLiked(img)) return@GridBody
                                        val i = selectedImageIds.indexOf(img)
                                        if (i >= 0) selectedImageIds.removeAt(i)
                                        else if (selectedImageIds.size < 3) selectedImageIds.add(img)
                                    },
                                    onLongPressImage = { img -> if (audiolines != null) movingImage = img },
                                    onViewVideo = { viewingVideo = it },
                                    onFillLine = { fillLine(it) },
                                    onDismissPendingImage = { p -> pendingImages.removeAll { it.id == p.id } },
                                    onDismissPendingVideo = { p -> pendingVideos.removeAll { it.id == p.id } },
                                    onDismissPendingGeneration = { p -> pendingGenerations.removeAll { it.id == p.id } },
                                )
                            }
                        }
                    }
                }
            }

            // ---- make-video shelf (bottom inset) ----
            if (isSelectingForVideo) {
                MakeVideoShelf(
                    enabled = selectedImageIds.isNotEmpty(),
                    onMakeVideo = { makeVideo() },
                    modifier = Modifier.align(Alignment.BottomCenter).widthIn(max = 620.dp),
                )
            }

            // ---- move-to-line picker (overlays everything) ----
            val moving = movingImage
            val lines = audiolines
            if (moving != null && lines != null) {
                MoveToLineSheet(
                    lines = lines,
                    onPick = { moveImageToLine(moving, it) },
                    onDismiss = { movingImage = null },
                )
            }

            // ---- full-screen video preview (overlays everything) ----
            viewingVideo?.let { video ->
                VideoPreview(video = video, onDismiss = { viewingVideo = null })
            }
        }
    }
}

// MARK: - Top bar

@Composable
private fun TopBar(
    isSelectingForVideo: Boolean,
    selectedCount: Int,
    songName: String?,
    canMakeVideo: Boolean,
    menuExpanded: Boolean,
    onMenuExpandedChange: (Boolean) -> Unit,
    onGenerate: () -> Unit,
    onUploadPhoto: () -> Unit,
    onEngineer: () -> Unit,
    onSong: () -> Unit,
    onMakeVideoTap: () -> Unit,
    onCancelSelection: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (isSelectingForVideo) {
            Text(
                "Cancel",
                modifier = Modifier.clickable { onCancelSelection() },
                color = Theme.onSurface,
                fontFamily = LocalBrandFont.current,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
            )
            Spacer(Modifier.weight(1f))
            Text(
                "$selectedCount of 3 picked",
                color = Theme.muted,
                fontFamily = LocalBrandFont.current,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.weight(1f))
            Spacer(Modifier.width(56.dp))
        } else {
            Box {
                Icon(
                    Icons.Default.Add,
                    contentDescription = "Add",
                    tint = Theme.onSurface,
                    modifier = Modifier.size(26.dp).clickable { onMenuExpandedChange(true) },
                )
                DropdownMenu(expanded = menuExpanded, onDismissRequest = { onMenuExpandedChange(false) }) {
                    DropdownMenuItem(text = { Text("Generate") }, leadingIcon = { Icon(Icons.Default.AutoAwesome, null) }, onClick = onGenerate)
                    DropdownMenuItem(text = { Text("Upload from Photos") }, leadingIcon = { Icon(Icons.Default.PhotoLibrary, null) }, onClick = onUploadPhoto)
                    DropdownMenuItem(text = { Text("Engineer") }, leadingIcon = { Icon(Icons.Default.Tune, null) }, onClick = onEngineer)
                }
            }
            Spacer(Modifier.weight(1f))
            Row(
                modifier = Modifier.widthIn(max = 200.dp).clickable { onSong() },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    songName ?: "No song",
                    color = if (songName != null) Theme.onSurface else Theme.muted,
                    fontFamily = LocalBrandFont.current,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Icon(Icons.Default.KeyboardArrowDown, contentDescription = null, tint = Theme.muted, modifier = Modifier.size(18.dp))
            }
            Spacer(Modifier.weight(1f))
            Row(
                modifier = Modifier.clickable(enabled = canMakeVideo) { onMakeVideoTap() },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(
                    Icons.Default.Movie,
                    contentDescription = null,
                    tint = if (canMakeVideo) Theme.onSurface else Theme.muted,
                    modifier = Modifier.size(18.dp),
                )
                Text(
                    "Make Video",
                    color = if (canMakeVideo) Theme.onSurface else Theme.muted,
                    fontFamily = LocalBrandFont.current,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

// MARK: - Filter bar

@Composable
private fun FilterBar(filter: GridFilter, onSelect: (GridFilter) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        GridFilter.entries.forEach { f ->
            val selected = filter == f
            Text(
                f.label,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(if (selected) Theme.accentMagenta.copy(alpha = 0.25f) else Color.White.copy(alpha = 0.08f))
                    .then(
                        if (selected) Modifier.border(1.dp, Theme.accentMagenta.copy(alpha = 0.6f), CircleShape) else Modifier,
                    )
                    .clickable { onSelect(f) }
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                color = if (selected) Theme.onSurface else Theme.muted,
                fontFamily = LocalBrandFont.current,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

// MARK: - Grid body

@Composable
private fun GridBody(
    filter: GridFilter,
    shouldSection: Boolean,
    audiolines: List<SongLine>?,
    filteredImages: List<String>,
    visibleVideos: List<GeneratedVideo>,
    visiblePendingImages: List<PendingImage>,
    visiblePendingVideos: List<PendingVideo>,
    visiblePendingGenerations: List<PendingGeneration>,
    imageLineIndex: Map<String, Int>,
    videoLineIndex: Map<String, Int>,
    isSelectingForVideo: Boolean,
    selectedImageIds: List<String>,
    likeStore: LikeStore,
    bottomMargin: androidx.compose.ui.unit.Dp,
    onToggleImageLike: (String) -> Unit,
    onToggleVideoLike: (String) -> Unit,
    onSelectImage: (String) -> Unit,
    onLongPressImage: (String) -> Unit,
    onViewVideo: (GeneratedVideo) -> Unit,
    onFillLine: (SongLine) -> Unit,
    onDismissPendingImage: (PendingImage) -> Unit,
    onDismissPendingVideo: (PendingVideo) -> Unit,
    onDismissPendingGeneration: (PendingGeneration) -> Unit,
) {
    // empty-state parity
    val imagesEmpty = filter == GridFilter.Videos ||
        (filteredImages.isEmpty() && visiblePendingImages.isEmpty() && visiblePendingGenerations.isEmpty())
    val videosEmpty = visibleVideos.isEmpty() && visiblePendingVideos.isEmpty()
    if (imagesEmpty && videosEmpty) {
        EmptyState(filter)
        return
    }

    val gridState = rememberLazyGridState()
    LazyVerticalGrid(
        columns = GridCells.Fixed(3),
        state = gridState,
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
        contentPadding = PaddingValues(start = 2.dp, top = 6.dp, end = 2.dp, bottom = bottomMargin),
    ) {
        if (shouldSection && audiolines != null) {
            val unassignedPendings = visiblePendingGenerations.filter { it.lineIndex == null }
            val unassignedImages = filteredImages.filter { imageLineIndex[it] == null }

            items(visiblePendingImages, key = { "pi-${it.id}" }, span = { GridItemSpan(1) }) {
                PendingImageCell(it, onDismissPendingImage)
            }
            items(visiblePendingVideos, key = { "pv-${it.id}" }, span = { GridItemSpan(1) }) {
                PendingVideoCell(it, onDismissPendingVideo)
            }
            items(unassignedPendings, key = { "pg-${it.id}" }, span = { GridItemSpan(1) }) {
                PendingGenerationCell(it, onDismissPendingGeneration)
            }
            items(unassignedImages, key = { "img-$it" }, span = { GridItemSpan(1) }) { img ->
                ImageCell(img, isSelectingForVideo, selectedImageIds, likeStore, onToggleImageLike, onSelectImage, onLongPressImage)
            }

            audiolines.forEach { line ->
                val imagesForLine = filteredImages.filter { imageLineIndex[it] == line.index }
                val pendingsForLine = visiblePendingGenerations.filter { it.lineIndex == line.index }
                val videosForLine = visibleVideos.filter { videoLineIndex[it.file] == line.index }
                val count = imagesForLine.size + pendingsForLine.size + videosForLine.size
                item(key = "hdr-${line.index}", span = { GridItemSpan(maxLineSpan) }) {
                    SectionHeader(line = line, count = count, onFillLine = onFillLine)
                }
                items(pendingsForLine, key = { "pg-${it.id}" }, span = { GridItemSpan(1) }) {
                    PendingGenerationCell(it, onDismissPendingGeneration)
                }
                items(imagesForLine, key = { "img-$it" }, span = { GridItemSpan(1) }) { img ->
                    ImageCell(img, isSelectingForVideo, selectedImageIds, likeStore, onToggleImageLike, onSelectImage, onLongPressImage)
                }
                items(videosForLine, key = { "vid-${it.id}" }, span = { GridItemSpan(1) }) { v ->
                    VideoCell(v, isSelectingForVideo, likeStore, onToggleVideoLike, onViewVideo)
                }
            }

            val orphanVideos = visibleVideos.filter { videoLineIndex[it.file] == null }
            items(orphanVideos, key = { "vid-${it.id}" }, span = { GridItemSpan(1) }) { v ->
                VideoCell(v, isSelectingForVideo, likeStore, onToggleVideoLike, onViewVideo)
            }
        } else {
            if (filter != GridFilter.Videos) {
                items(visiblePendingImages, key = { "pi-${it.id}" }) { PendingImageCell(it, onDismissPendingImage) }
                items(visiblePendingGenerations, key = { "pg-${it.id}" }) { PendingGenerationCell(it, onDismissPendingGeneration) }
                items(filteredImages, key = { "img-$it" }) { img ->
                    ImageCell(img, isSelectingForVideo, selectedImageIds, likeStore, onToggleImageLike, onSelectImage, onLongPressImage)
                }
            }
            items(visiblePendingVideos, key = { "pv-${it.id}" }) { PendingVideoCell(it, onDismissPendingVideo) }
            items(visibleVideos, key = { "vid-${it.id}" }) { v ->
                VideoCell(v, isSelectingForVideo, likeStore, onToggleVideoLike, onViewVideo)
            }
        }
    }
}

@Composable
private fun SectionHeader(line: SongLine, count: Int, onFillLine: (SongLine) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Theme.background)
            .padding(horizontal = 16.dp)
            .padding(top = 28.dp, bottom = 10.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                line.text,
                color = Theme.onSurface,
                fontFamily = LocalBrandFont.current,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                if (count == 0) "No pictures yet" else "$count ${if (count == 1) "picture" else "pictures"}",
                color = Theme.muted,
                fontFamily = LocalBrandFont.current,
                fontSize = 14.sp,
            )
        }
        // Discoverable stand-in for the Swift long-press contextMenu "Make pictures for this line".
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(Theme.accentMagenta.copy(alpha = 0.18f))
                .clickable { onFillLine(line) },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.AutoAwesome, contentDescription = "Make pictures for this line", tint = Theme.accentMagenta, modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
private fun EmptyState(filter: GridFilter) {
    val (icon, title, body) = when (filter) {
        GridFilter.All -> Triple(Icons.Default.Image, "No pictures yet", "Tap + to make your first ones.")
        GridFilter.Liked -> Triple(Icons.Default.FavoriteBorder, "Nothing hearted yet", "Hold a picture to heart it. Hearted pictures can become videos.")
        GridFilter.Videos -> Triple(Icons.Default.Movie, "No videos yet", "Heart a few pictures, then make a video.")
    }
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Theme.muted, modifier = Modifier.size(48.dp))
        Spacer(Modifier.height(16.dp))
        Text(title, color = Theme.onSurface, fontFamily = LocalBrandFont.current, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(8.dp))
        Text(body, color = Theme.muted, fontFamily = LocalBrandFont.current, fontSize = 14.sp, textAlign = TextAlign.Center)
    }
}

// MARK: - Cells

@Composable
private fun ImageCell(
    image: String,
    isSelectingForVideo: Boolean,
    selectedImageIds: List<String>,
    likeStore: LikeStore,
    onToggleLike: (String) -> Unit,
    onSelect: (String) -> Unit,
    onLongPress: (String) -> Unit,
) {
    val liked = likeStore.isLiked(image)
    val selected = selectedImageIds.contains(image)
    val eligible = !isSelectingForVideo || liked
    var bmp by remember(image) { mutableStateOf<ImageBitmap?>(null) }
    var failed by remember(image) { mutableStateOf(false) }
    LaunchedEffect(image) {
        val b = runCatching { decodeImageBitmap(bytesOf(image)) }.getOrNull()
        if (b == null) failed = true else bmp = b
    }
    Box(
        Modifier
            .aspectRatio(1f)
            .clipToBounds()
            .background(Theme.surface)
            .alpha(if (eligible) 1f else 0.3f)
            .combinedClickable(
                onClick = { if (isSelectingForVideo && eligible) onSelect(image) },
                onLongClick = { if (!isSelectingForVideo) onLongPress(image) },
            ),
    ) {
        when {
            bmp != null -> Image(bitmap = bmp!!, contentDescription = "Picture", contentScale = ContentScale.Crop, modifier = Modifier.matchParentSize())
            failed -> Box(Modifier.matchParentSize().background(Color.Black.copy(alpha = 0.4f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Default.BrokenImage, contentDescription = null, tint = Theme.muted, modifier = Modifier.size(28.dp))
            }
            else -> Shimmer(Modifier.matchParentSize())
        }
        if (isSelectingForVideo && selected) {
            Box(Modifier.matchParentSize().background(Theme.accentMagenta.copy(alpha = 0.18f)))
        }
        if (isSelectingForVideo) {
            if (eligible) {
                val order = selectedImageIds.indexOf(image).let { if (it >= 0) it else null }
                SelectionBadge(order, Modifier.align(Alignment.TopEnd))
            }
        } else {
            HeartButton(liked, Modifier.align(Alignment.TopEnd)) { onToggleLike(image) }
        }
    }
}

@Composable
private fun VideoCell(
    video: GeneratedVideo,
    isSelectingForVideo: Boolean,
    likeStore: LikeStore,
    onToggleLike: (String) -> Unit,
    onView: (GeneratedVideo) -> Unit,
) {
    val liked = likeStore.isLiked(video.id.toString())
    var poster by remember(video.posterFile) { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(video.posterFile) {
        if (video.posterFile.isNotEmpty()) {
            poster = runCatching { decodeImageBitmap(bytesOf(video.posterFile)) }.getOrNull()
        }
    }
    Box(
        Modifier
            .aspectRatio(1f)
            .clipToBounds()
            .background(Theme.surface)
            .alpha(if (isSelectingForVideo) 0.3f else 1f)
            .clickable(enabled = !isSelectingForVideo) { onView(video) },
        contentAlignment = Alignment.Center,
    ) {
        poster?.let { Image(bitmap = it, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.matchParentSize()) }
        Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(36.dp))
        if (!isSelectingForVideo) {
            HeartButton(liked, Modifier.align(Alignment.TopEnd)) { onToggleLike(video.id.toString()) }
        }
    }
}

@Composable
private fun PendingImageCell(pending: PendingImage, onDismiss: (PendingImage) -> Unit) {
    PendingTile(
        working = pending.state == GenState.Working,
        workingLabel = "Uploading…",
        onDismiss = { if (pending.state == GenState.Failed) onDismiss(pending) },
    )
}

@Composable
private fun PendingGenerationCell(pending: PendingGeneration, onDismiss: (PendingGeneration) -> Unit) {
    PendingTile(
        working = pending.state == GenState.Working,
        workingLabel = "Making…",
        onDismiss = { if (pending.state == GenState.Failed) onDismiss(pending) },
    )
}

@Composable
private fun PendingVideoCell(pending: PendingVideo, onDismiss: (PendingVideo) -> Unit) {
    var poster by remember(pending.posterFile) { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(pending.posterFile) {
        if (pending.posterFile.isNotEmpty()) poster = runCatching { decodeImageBitmap(bytesOf(pending.posterFile)) }.getOrNull()
    }
    Box(
        Modifier
            .aspectRatio(1f)
            .clipToBounds()
            .background(Theme.surface)
            .clickable(enabled = pending.state == GenState.Failed) { onDismiss(pending) },
        contentAlignment = Alignment.Center,
    ) {
        poster?.let {
            Image(
                bitmap = it,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.matchParentSize().alpha(if (pending.state == GenState.Failed) 0.5f else 0.4f),
            )
        }
        if (pending.state == GenState.Working) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(28.dp))
                Text("Making…", color = Color.White, fontFamily = LocalBrandFont.current, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
        } else {
            FailedContent()
        }
    }
}

@Composable
private fun PendingTile(working: Boolean, workingLabel: String, onDismiss: () -> Unit) {
    Box(
        Modifier
            .aspectRatio(1f)
            .clipToBounds()
            .background(Theme.surface)
            .clickable(enabled = !working) { onDismiss() },
        contentAlignment = Alignment.Center,
    ) {
        if (working) {
            Shimmer(Modifier.matchParentSize())
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(26.dp))
                Text(workingLabel, color = Color.White, fontFamily = LocalBrandFont.current, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
        } else {
            FailedContent()
        }
    }
}

@Composable
private fun FailedContent() {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(horizontal = 8.dp)) {
        Icon(Icons.Default.Warning, contentDescription = null, tint = Color.White, modifier = Modifier.size(24.dp))
        Text("Failed — tap to dismiss", color = Color.White, fontFamily = LocalBrandFont.current, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
    }
}

// MARK: - Heart button + selection badge (shared cell affordances)

@Composable
private fun HeartButton(isLiked: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier.padding(8.dp).size(28.dp).clip(CircleShape)
            .then(if (isLiked) Modifier.background(Theme.accent) else Modifier.background(Color.White.copy(alpha = 0.18f)))
            .border(0.5.dp, Color.White.copy(alpha = if (isLiked) 0.35f else 0.4f), CircleShape)
            .clickable { onClick() },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            if (isLiked) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(15.dp),
        )
    }
}

@Composable
private fun SelectionBadge(order: Int?, modifier: Modifier = Modifier) {
    Box(modifier = modifier.padding(8.dp), contentAlignment = Alignment.Center) {
        if (order != null) {
            Box(
                Modifier.size(26.dp).clip(CircleShape).background(Theme.accent).border(1.5.dp, Color.White, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text("${order + 1}", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
        } else {
            Box(
                Modifier.size(26.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.25f)).border(1.5.dp, Color.White.copy(alpha = 0.9f), CircleShape),
            )
        }
    }
}

// MARK: - Make-video shelf

@Composable
private fun MakeVideoShelf(enabled: Boolean, onMakeVideo: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(Color(0xF01A1A26))
            .padding(horizontal = 16.dp, vertical = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .clip(CircleShape)
                .background(Theme.accent)
                .border(0.5.dp, Color.White.copy(alpha = 0.15f), CircleShape)
                .alpha(if (enabled) 1f else 0.5f)
                .clickable(enabled = enabled) { onMakeVideo() },
            contentAlignment = Alignment.Center,
        ) {
            Text("Make video", color = Color.White, fontFamily = LocalBrandFont.current, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

// MARK: - Move-to-line picker (web stand-in for the drag→section reassignment)

@Composable
private fun MoveToLineSheet(lines: List<SongLine>, onPick: (SongLine) -> Unit, onDismiss: () -> Unit) {
    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.6f)).clickable { onDismiss() },
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .widthIn(max = 420.dp)
                .fillMaxWidth()
                .padding(24.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(Theme.surface)
                .border(0.5.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(20.dp))
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("Move to line", color = Theme.onSurface, fontFamily = LocalBrandFont.current, fontSize = 16.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            lines.forEach { line ->
                Text(
                    line.text,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color.White.copy(alpha = 0.06f))
                        .clickable { onPick(line) }
                        .padding(horizontal = 14.dp, vertical = 12.dp),
                    color = Theme.onSurface,
                    fontFamily = LocalBrandFont.current,
                    fontSize = 14.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

// MARK: - Full-screen video preview

@Composable
private fun VideoPreview(video: GeneratedVideo, onDismiss: () -> Unit) {
    val state = remember { NativeVideoState() }
    var blobUrl by remember(video.file) { mutableStateOf<String?>(null) }
    LaunchedEffect(video.file) { blobUrl = runCatching { readBlob(video.file) }.getOrNull() }
    // Free the object URL when the preview closes so blobs don't accumulate.
    DisposableEffect(video.file) { onDispose { blobUrl?.let { revokeBlobUrl(it) } } }
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        val url = blobUrl
        if (url != null) {
            NativeVideo(url = url, state = state, modifier = Modifier.fillMaxSize(), showControls = true, autoPlay = true, poster = null)
            LaunchedEffect(url) { state.mute(false) }
        } else {
            CircularProgressIndicator(color = Color.White, modifier = Modifier.align(Alignment.Center))
        }
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(16.dp)
                .size(40.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.18f))
                .clickable { onDismiss() },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.Close, contentDescription = "Close", tint = Color.White, modifier = Modifier.size(22.dp))
        }
    }
}

// MARK: - Generating overlay + completion (phase parity; grid is the live path)

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
        modifier = Modifier.fillMaxSize().background(Theme.background).padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator(color = Theme.accentMagenta, modifier = Modifier.size(64.dp))
        Spacer(Modifier.height(24.dp))
        Text(title, color = Theme.onSurface, fontFamily = LocalBrandFont.current, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(subtitle, color = Theme.muted, fontFamily = LocalBrandFont.current, fontSize = 14.sp, textAlign = TextAlign.Center)
    }
}

@Composable
private fun CompletionView(onDone: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().background(Theme.background).padding(horizontal = 32.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Theme.accentMagenta, modifier = Modifier.size(96.dp))
        Spacer(Modifier.height(32.dp))
        Text("You did it.", color = Theme.onSurface, fontFamily = LocalBrandFont.current, fontSize = 30.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(12.dp))
        Text(
            "That's a video. Make more whenever you want.",
            color = Theme.muted, fontFamily = LocalBrandFont.current, fontSize = 16.sp, textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(32.dp))
        Box(
            modifier = Modifier.fillMaxWidth().height(52.dp).clip(CircleShape).background(Theme.accent).clickable { onDone() },
            contentAlignment = Alignment.Center,
        ) {
            Text("Done", color = Color.White, fontFamily = LocalBrandFont.current, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

// MARK: - Shimmer

@Composable
private fun Shimmer(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val phase by transition.animateFloat(
        initialValue = -1f,
        targetValue = 1.5f,
        animationSpec = infiniteRepeatable(tween(1600, easing = LinearEasing)),
        label = "phase",
    )
    Box(
        modifier.background(Theme.surface).clipToBounds().background(
            Brush.horizontalGradient(
                0f to Color.Transparent,
                (0.5f + phase * 0.25f).coerceIn(0.001f, 0.999f) to Theme.accentMagenta.copy(alpha = 0.35f),
                1f to Color.Transparent,
            ),
        ),
    )
}

@Composable
@Suppress("unused")
private fun Modifier.bounceClick(onClick: () -> Unit): Modifier {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, label = "bounce")
    return this.scale(scale).clickable(interactionSource = interaction, indication = null, onClick = onClick)
}
