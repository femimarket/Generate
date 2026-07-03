//
//  GenerateViewModel.kt
//  AndroidGenerate3
//
//  All Generate screen state and async work. On iOS this lives in SwiftUI
//  @State + Task; on Android it belongs in a ViewModel so in-flight
//  generations and grid state survive configuration changes.
//
//  ProjectService's suspend functions are blocking JNI passthroughs on
//  Android, so every call here hops to Dispatchers.IO first.
//

package studio.femi.androidgenerate3

import android.content.ContentResolver
import android.net.Uri
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import market.femi.api.ChatMessage
import market.femi.api.ProjectService
import market.femi.api.Role
import market.femi.api.flux2Pro
import market.femi.api.ltx2_3a2v
import market.femi.api.nanoBanana2
import market.femi.api.qwen3_6_35b_a3b
import market.femi.api.zImageTurbo
import java.io.File
import java.util.Base64
import java.util.UUID

private const val TAG = "Generate"

// MARK: - File helpers

/**
 * Persist bytes returned by an Api method to the project folder under a fresh
 * local filename. `ext` is sniffed from the bytes when not supplied (video
 * callers pass "mp4" since the sniffer only covers images). Returns the new
 * filename for grid wiring.
 */
private suspend fun saveResponseData(
    data: ByteArray,
    ext: String? = null,
    prompt: String? = null,
    model: String? = null,
    subject: List<String>? = null,
): String {
    val finalExt = ext ?: sniffImageExt(data)
    val name = "gen-${UUID.randomUUID()}.$finalExt"
    withContext(Dispatchers.IO) {
        ProjectService.saveFile(data, name, prompt, model, subject)
    }
    return name
}

/** ImageIO-equivalent format sniff from magic bytes. */
private fun sniffImageExt(data: ByteArray): String {
    fun ascii(offset: Int, length: Int): String =
        if (data.size >= offset + length) String(data, offset, length, Charsets.US_ASCII) else ""
    return when {
        data.size >= 2 && data[0] == 0x89.toByte() && data[1] == 0x50.toByte() -> "png"
        data.size >= 2 && data[0] == 0xFF.toByte() && data[1] == 0xD8.toByte() -> "jpg"
        ascii(0, 4) == "RIFF" && ascii(8, 4) == "WEBP" -> "webp"
        ascii(0, 3) == "GIF" -> "gif"
        ascii(4, 4) == "ftyp" -> "heic"
        else -> error("saveResponseData: response bytes aren't a recognized image format")
    }
}

class GenerateViewModel : ViewModel() {

    // All screen state — mirror of the @State block in ContentView.swift.
    var phase by mutableStateOf<Phase>(Phase.Grid)
    var filter by mutableStateOf(GridFilter.All)
    var isSelectingForVideo by mutableStateOf(false)
    val selectedImageIds = mutableStateListOf<String>()
    var viewingVideo by mutableStateOf<GeneratedVideo?>(null)
    val images = mutableStateListOf<String>()
    val imageLineIndex = mutableStateMapOf<String, Int>()
    val videoLineIndex = mutableStateMapOf<String, Int>()
    val videos = mutableStateListOf<GeneratedVideo>()
    val pendingVideos = mutableStateListOf<PendingVideo>()
    val pendingImages = mutableStateListOf<PendingImage>()
    val pendingGenerations = mutableStateListOf<PendingGeneration>()
    var audiolines by mutableStateOf<List<SongLine>?>(null)
    val likeStore = LikeStore()

    /** Filename of the project's song, shown in the toolbar (getAudio is suspend on Android). */
    var songFile by mutableStateOf<String?>(null)
        private set

    /** Absolute path of Rust's Documents root, resolved once at startup. */
    private var documentsDir by mutableStateOf<File?>(null)

    private val reloadMutex = Mutex()

    val canMakeVideo: Boolean
        get() = images.any { likeStore.isLiked(it) }

    val isOnGrid: Boolean
        get() = phase == Phase.Grid

    init {
        viewModelScope.launch {
            documentsDir = withContext(Dispatchers.IO) {
                File(ProjectService.getUrl("probe")).parentFile
            }
        }
    }

    /** Absolute file for a project filename, for Coil / ExoPlayer. */
    fun fileFor(name: String): File? =
        documentsDir?.let { if (name.isEmpty()) null else File(it, name) }

    private suspend fun bytesOf(file: String): ByteArray = withContext(Dispatchers.IO) {
        File(ProjectService.getUrl(file)).readBytes()
    }

    // MARK: - Project scan (the `.task` block)

    /**
     * Re-scan the project folder, like SwiftUI re-running `.task` on every
     * appearance. Idempotent — already-known files are skipped.
     */
    fun reload() {
        viewModelScope.launch {
            reloadMutex.withLock { loadProject() }
        }
    }

    private suspend fun loadProject() {
        val existingImages = images.toSet()
        val existingVideos = videos.map { it.file }.toSet()
        val newImages = mutableListOf<Pair<String, Int?>>()
        val newVideos = mutableListOf<Pair<String, Int?>>()
        var liked: List<String> = emptyList()
        var song: String? = null
        withContext(Dispatchers.IO) {
            suspend fun subjectIndex(filename: String): Int? =
                ProjectService.getSubject(filename)?.firstNotNullOfOrNull { it.toIntOrNull() }

            for (url in ProjectService.getAllGenerations()) {
                val filename = url.substringAfterLast('/')
                when (filename.substringAfterLast('.', "").lowercase()) {
                    "png", "jpg", "jpeg", "webp", "gif", "heic", "heif" ->
                        if (filename !in existingImages) {
                            newImages.add(filename to subjectIndex(filename))
                        }
                    "mp4" ->
                        if (filename !in existingVideos) {
                            newVideos.add(filename to subjectIndex(filename))
                        }
                }
            }
            val allImages = existingImages + newImages.map { it.first }
            liked = allImages.filter { ProjectService.getLike(it) }
            song = ProjectService.getAudio()?.substringAfterLast('/')
        }
        for ((filename, index) in newImages) {
            images.add(filename)
            index?.let { imageLineIndex[filename] = it }
        }
        for ((filename, index) in newVideos) {
            videos.add(
                GeneratedVideo(
                    id = UUID.randomUUID(), file = filename,
                    posterFile = "", sourceImageIds = emptyList(),
                )
            )
            index?.let { videoLineIndex[filename] = it }
        }
        for (image in liked) likeStore.setLiked(image, true)
        songFile = song
        song?.let { extractAudiolines(it) }
    }

    /**
     * Toolbar song tap: run the host's upload flow, then re-read the song.
     * Lives in viewModelScope so a configuration change mid-flow can't drop
     * the refresh (the Swift equivalent is an unstructured Task).
     */
    fun uploadSongThenRefresh(onUploadSong: suspend () -> Unit) {
        viewModelScope.launch {
            onUploadSong()
            audiolines = null
            songFile = withContext(Dispatchers.IO) {
                ProjectService.getAudio()?.substringAfterLast('/')
            }
            songFile?.let { extractAudiolines(it) }
        }
    }

    /**
     * Off-main SYLT read via the Api's Rust core. Fire-and-forget — kicks off a
     * coroutine and returns immediately; state updates whenever the read completes.
     */
    private fun extractAudiolines(filename: String) {
        viewModelScope.launch {
            val lines = withContext(Dispatchers.IO) {
                LyricExtractor.read(ProjectService.getUrl(filename))
            }
            if (lines.isEmpty()) return@launch
            audiolines = lines
            var nextLine = 0
            for (image in images) {
                if (imageLineIndex[image] == null) {
                    imageLineIndex[image] = lines[nextLine % lines.size].index
                    nextLine += 1
                }
            }
        }
    }

    // MARK: - Generation fan-out

    /**
     * 3-model fan-out: Flux2Pro / NanoBanana2 / ZImageTurbo for the default
     * "make me 3 pictures" tap.
     */
    fun runDefaultGenerate(user: String, password: String) {
        viewModelScope.launch {
            phase = Phase.Grid
            fanOutGenerate(
                user = user,
                password = password,
                prompt = "cinematic music video still, vivid color grade, dramatic lighting, " +
                    "expressive performer mid-motion, shallow depth of field, 35mm film grain, " +
                    "emotional and atmospheric",
                lineIndex = null,
            )
        }
    }

    /**
     * Per-line generate from the header's context menu — same 3-model fan-out as
     * the default Generate button but pendings are scoped to the lyric line.
     */
    fun fillLine(user: String, password: String, line: SongLine) {
        viewModelScope.launch {
            fanOutGenerate(user = user, password = password, prompt = line.text, lineIndex = line.index)
        }
    }

    private suspend fun fanOutGenerate(user: String, password: String, prompt: String, lineIndex: Int?) {
        val pendings = List(3) { PendingGeneration(id = UUID.randomUUID(), lineIndex = lineIndex) }
        val queue = ArrayDeque(pendings.map { it.id })
        pendingGenerations.addAll(pendings)

        val models = listOf<Pair<String, suspend () -> ByteArray>>(
            "Flux2Pro" to { flux2Pro(user, password, prompt) },
            "NanoBanana2" to { nanoBanana2(user, password, prompt) },
            "ZImageTurbo" to { zImageTurbo(user, password, prompt) },
        )
        coroutineScope {
            // Channel keeps the Swift withTaskGroup semantics: results are handled
            // in completion order, each success retiring the oldest pending cell.
            val results = Channel<Pair<ByteArray, String>?>(models.size)
            models.forEach { (model, call) ->
                launch {
                    results.send(
                        try {
                            call() to model
                        } catch (e: CancellationException) {
                            throw e
                        } catch (e: Exception) {
                            Log.d(TAG, "← $model FAIL: ${e.message}")
                            null
                        }
                    )
                }
            }
            repeat(models.size) {
                val (data, model) = results.receive() ?: return@repeat
                val file = try {
                    if (lineIndex == null) {
                        saveResponseData(data, model = model)
                    } else {
                        saveResponseData(data, prompt = prompt, model = model, subject = listOf("line:$lineIndex"))
                    }
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    Log.d(TAG, "← $model FAIL: ${e.message}")
                    return@repeat
                }
                if (queue.isEmpty()) return@repeat
                val pid = queue.removeFirst()
                pendingGenerations.removeAll { it.id == pid }
                images.add(file)
                if (lineIndex != null) imageLineIndex[file] = lineIndex
            }
        }
        for (pid in queue) {
            val i = pendingGenerations.indexOfFirst { it.id == pid }
            if (i >= 0) pendingGenerations[i] = pendingGenerations[i].copy(state = PendingState.Failed)
        }
    }

    // MARK: - Photo upload

    /**
     * Reads the photo-picker result and saves it into the project. The whole
     * flow lives in viewModelScope so a configuration change mid-read can't
     * drop the picked photo.
     */
    fun addPickedPhoto(resolver: ContentResolver, uri: Uri) {
        viewModelScope.launch {
            val data = withContext(Dispatchers.IO) {
                runCatching {
                    resolver.openInputStream(uri)?.use { it.readBytes() }
                }.getOrNull()
            } ?: return@launch
            val name = "upload-${UUID.randomUUID()}.jpg"
            withContext(Dispatchers.IO) {
                ProjectService.saveFile(data, name, null, null, null)
            }
            images.add(name)
        }
    }

    // MARK: - Likes / selection

    fun toggleImageLike(image: String) {
        likeStore.toggle(image)
        val liked = likeStore.isLiked(image)
        viewModelScope.launch(Dispatchers.IO) { ProjectService.like(image, liked) }
    }

    /** Selection-mode tap on an image cell. Returns true when the image was added. */
    fun tapImageInSelection(image: String): Boolean {
        if (!isSelectingForVideo) return false
        if (!likeStore.isLiked(image)) return false
        val i = selectedImageIds.indexOf(image)
        return if (i >= 0) {
            selectedImageIds.removeAt(i)
            false
        } else if (selectedImageIds.size < 3) {
            selectedImageIds.add(image)
            true
        } else {
            false
        }
    }

    // MARK: - Drag & drop

    /** Drop handler: re-home an image under a lyric line and persist the subject. */
    fun assignImageToLine(filename: String, line: SongLine) {
        imageLineIndex[filename] = line.index
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val data = File(ProjectService.getUrl(filename)).readBytes()
                ProjectService.saveFile(
                    data,
                    filename,
                    ProjectService.getPrompt(filename),
                    ProjectService.getModel(filename),
                    listOf("${line.index}", line.text),
                )
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.d(TAG, "assignImageToLine FAIL: ${e.message}")
            }
        }
    }

    // MARK: - Make video

    /** The MakeVideoShelf commit: chat-compose a prompt, then audio+image → video. */
    fun makeVideo(user: String, password: String) {
        viewModelScope.launch {
            val ids = selectedImageIds.toList()
            val primary = ids.first()
            isSelectingForVideo = false
            selectedImageIds.clear()
            val pending = PendingVideo(id = UUID.randomUUID(), sourceImageIds = ids, posterFile = primary)
            pendingVideos.add(pending)
            try {
                val (audioFile, imagePrompts) = withContext(Dispatchers.IO) {
                    val audio = ProjectService.getAudio()!!.substringAfterLast('/')
                    val prompts = ids.mapNotNull { ProjectService.getPrompt(it) }
                    audio to prompts
                }
                val imageData = bytesOf(primary)
                val line = imageLineIndex[primary]?.let { li ->
                    audiolines?.firstOrNull { it.index == li }
                }
                val audioData = if (line != null) {
                    // 10s window starting at the primary image's lyric line —
                    // AVAssetExportSession-equivalent m4a trim.
                    val audioPath = withContext(Dispatchers.IO) { ProjectService.getUrl(audioFile) }
                    withContext(Dispatchers.Default) {
                        AudioClipper.clip(audioPath, startMs = line.startMs.toLong(), durationMs = 10_000)
                    }
                } else {
                    bytesOf(audioFile)
                }
                val instruction = "Convert these ${imagePrompts.size} image prompts into a " +
                    "timestamped music-video prompt with exactly ${imagePrompts.size} multishot " +
                    "timestamps. Under 100 words. Return only the prompt itself — no title, " +
                    "no preamble, no commentary, no trailing notes, no markdown.\n\n" +
                    imagePrompts.joinToString("\n---\n")
                val chatReply = qwen3_6_35b_a3b(
                    user, password,
                    listOf(ChatMessage(role = Role.User, content = instruction)),
                )
                val prompt = chatReply.lastOrNull()?.content
                if (prompt.isNullOrEmpty()) {
                    Log.d(TAG, "← chat FAIL: empty reply")
                    markVideoFailed(pending.id)
                    return@launch
                }
                val (imageB64, audioB64) = withContext(Dispatchers.Default) {
                    val encoder = Base64.getEncoder()
                    encoder.encodeToString(imageData) to encoder.encodeToString(audioData)
                }
                val videoData = ltx2_3a2v(
                    user, password,
                    imageB64 = imageB64,
                    audioB64 = audioB64,
                    prompt = prompt,
                )
                val lineIndex = imageLineIndex[primary]
                val lineSubject = lineIndex?.let { li ->
                    audiolines?.firstOrNull { it.index == li }?.text?.let { listOf("$li", it) }
                }
                val file = saveResponseData(
                    videoData, ext = "mp4",
                    prompt = prompt, model = "Ltx23A2V", subject = lineSubject,
                )
                pendingVideos.removeAll { it.id == pending.id }
                videos.add(
                    GeneratedVideo(
                        id = UUID.randomUUID(), file = file,
                        posterFile = primary, sourceImageIds = ids,
                    )
                )
                if (lineIndex != null) videoLineIndex[file] = lineIndex
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.d(TAG, "← video FAIL: ${e.message}")
                markVideoFailed(pending.id)
            }
        }
    }

    private fun markVideoFailed(id: UUID) {
        val i = pendingVideos.indexOfFirst { it.id == id }
        if (i >= 0) pendingVideos[i] = pendingVideos[i].copy(state = PendingState.Failed)
    }
}
