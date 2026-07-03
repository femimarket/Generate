//
//  AudioClipper.kt
//  AndroidGenerate3
//
//  Android equivalent of the AVAssetExportSession m4a trim in ContentView.swift's
//  MakeVideoShelf: decode [startMs, startMs+durationMs] of any audio file
//  MediaExtractor understands, re-encode as AAC-LC in an .m4a (MP4) container,
//  and return the container bytes.
//

package studio.femi.androidgenerate3

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.ByteArrayOutputStream
import java.io.File

internal object AudioClipper {

    private const val TIMEOUT_US = 10_000L
    private const val AAC_BIT_RATE = 128_000

    fun clip(srcPath: String, startMs: Long, durationMs: Long): ByteArray {
        val startUs = startMs * 1000
        val endUs = startUs + durationMs * 1000

        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(srcPath)
            val trackIndex = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: error("AudioClipper: no audio track in $srcPath")
            extractor.selectTrack(trackIndex)
            val format = extractor.getTrackFormat(trackIndex)
            val (pcm, sampleRate, channels) = decodeRange(extractor, format, startUs, endUs)
            check(pcm.isNotEmpty()) { "AudioClipper: nothing decoded in [$startMs, +${durationMs}ms]" }
            return encodeToM4a(pcm, sampleRate, channels)
        } finally {
            extractor.release()
        }
    }

    /** Decode the source's audio track to 16-bit PCM, trimmed to [startUs, endUs). */
    private fun decodeRange(
        extractor: MediaExtractor,
        format: MediaFormat,
        startUs: Long,
        endUs: Long,
    ): Triple<ByteArray, Int, Int> {
        val mime = format.getString(MediaFormat.KEY_MIME)!!
        var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)

        extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

        val decoder = MediaCodec.createDecoderByType(mime)
        decoder.configure(format, null, null, 0)
        decoder.start()
        val pcm = ByteArrayOutputStream()
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        try {
            while (!outputDone) {
                if (!inputDone) {
                    val inIndex = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val buffer = decoder.getInputBuffer(inIndex)!!
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0 || extractor.sampleTime > endUs) {
                            decoder.queueInputBuffer(
                                inIndex, 0, 0, 0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                when (val outIndex = decoder.dequeueOutputBuffer(info, TIMEOUT_US)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val out = decoder.outputFormat
                        sampleRate = out.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = out.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                    in 0..Int.MAX_VALUE -> {
                        // Seek landed on the previous sync frame; drop decoded audio
                        // outside the requested window (frame-granularity trim).
                        if (info.size > 0 &&
                            info.presentationTimeUs >= startUs &&
                            info.presentationTimeUs < endUs
                        ) {
                            val buffer = decoder.getOutputBuffer(outIndex)!!
                            val chunk = ByteArray(info.size)
                            buffer.position(info.offset)
                            buffer.get(chunk)
                            pcm.write(chunk)
                        }
                        decoder.releaseOutputBuffer(outIndex, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                    }
                }
            }
        } finally {
            decoder.stop()
            decoder.release()
        }
        return Triple(pcm.toByteArray(), sampleRate, channels)
    }

    /** Encode 16-bit PCM to AAC-LC inside an MP4 (.m4a) container and return its bytes. */
    private fun encodeToM4a(pcm: ByteArray, sampleRate: Int, channels: Int): ByteArray {
        // On Android java.io.tmpdir is the app's cache dir; MediaMuxer needs a real file.
        val tmp = File.createTempFile("clip-", ".m4a")
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        var muxer: MediaMuxer? = null
        try {
            val format = MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channels,
            ).apply {
                setInteger(
                    MediaFormat.KEY_AAC_PROFILE,
                    MediaCodecInfo.CodecProfileLevel.AACObjectLC,
                )
                setInteger(MediaFormat.KEY_BIT_RATE, AAC_BIT_RATE)
            }
            encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()
            muxer = MediaMuxer(tmp.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            val bytesPerSecond = sampleRate.toLong() * channels * 2
            var fed = 0L
            var track = -1
            var muxerStarted = false
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            while (!outputDone) {
                if (!inputDone) {
                    val inIndex = encoder.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val buffer = encoder.getInputBuffer(inIndex)!!
                        val ptsUs = fed * 1_000_000 / bytesPerSecond
                        if (fed >= pcm.size) {
                            encoder.queueInputBuffer(
                                inIndex, 0, 0, ptsUs,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            // MediaCodec's raw-audio contract wants whole PCM
                            // frames (channels * 2 bytes) per input buffer.
                            val frameBytes = channels * 2
                            var chunk = minOf(buffer.remaining().toLong(), pcm.size - fed).toInt()
                            if (chunk > frameBytes) chunk -= chunk % frameBytes
                            buffer.put(pcm, fed.toInt(), chunk)
                            encoder.queueInputBuffer(inIndex, 0, chunk, ptsUs, 0)
                            fed += chunk
                        }
                    }
                }
                when (val outIndex = encoder.dequeueOutputBuffer(info, TIMEOUT_US)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                    in 0..Int.MAX_VALUE -> {
                        val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                        if (info.size > 0 && !isConfig && muxerStarted) {
                            val buffer = encoder.getOutputBuffer(outIndex)!!
                            muxer.writeSampleData(track, buffer, info)
                        }
                        encoder.releaseOutputBuffer(outIndex, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                    }
                }
            }
            encoder.stop()
            if (muxerStarted) muxer.stop()
            return tmp.readBytes()
        } finally {
            encoder.release()
            muxer?.release()
            tmp.delete()
        }
    }
}
