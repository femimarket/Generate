//
//  LyricExtractor.kt
//  AndroidGenerate3
//
//  Port of Generate2/LyricExtractor.swift. The word→line folding lives in the
//  Api's Rust core (extractSylt), which returns the timed lines as a JSON
//  array of {index, text, startMs, durationMs}.
//

package market.femi.generate

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import market.femi.api.extractSylt
import java.io.File
import java.util.UUID

internal object LyricExtractor {
    suspend fun read(audioPath: String): List<SongLine> {
        val bytes = try {
            File(audioPath).readBytes()
        } catch (e: Exception) {
            return emptyList()
        }
        val json = extractSylt(bytes)
        return try {
            Json.parseToJsonElement(json).jsonArray.map { element ->
                val line = element.jsonObject
                SongLine(
                    id = UUID.randomUUID(),
                    index = line.getValue("index").jsonPrimitive.int,
                    text = line.getValue("text").jsonPrimitive.content,
                    startMs = line.getValue("startMs").jsonPrimitive.int,
                    durationMs = line.getValue("durationMs").jsonPrimitive.int,
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }
}
