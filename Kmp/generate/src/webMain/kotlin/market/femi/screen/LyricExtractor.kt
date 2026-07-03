package market.femi.screen

// Port of Generate2/LyricExtractor.swift. The word→line SYLT assembly already
// lives in the api's Rust `extractSylt` (itself a port of the Swift file), so
// here we just read the audio bytes from OPFS and decode the JSON it returns.

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import market.femi.api.extractSylt
import market.femi.api.readFileBytes
import market.femi.api.toByteArray

/// A single timed lyric line. Matches the JSON emitted by `extractSylt`
/// (`[{index, text, startMs, durationMs}]`, camelCase).
@Serializable
data class SongLine(
    val index: Int,
    val text: String,
    val startMs: Int,
    val durationMs: Int,
)

object LyricExtractor {
    private val json = Json { ignoreUnknownKeys = true }

    /// Read the SYLT lines embedded in an OPFS audio file. Empty when the file
    /// has no synchronised lyrics (or isn't an MP3).
    suspend fun read(filename: String): List<SongLine> = runCatching {
        val bytes = readFileBytes(filename).toByteArray()
        json.decodeFromString<List<SongLine>>(extractSylt(bytes))
    }.getOrDefault(emptyList())
}
