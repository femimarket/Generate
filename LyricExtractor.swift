//
//  LyricExtractor.swift
//  Generate2
//

import Foundation
import AudioMarker

enum LyricExtractor {
    nonisolated static func read(audioURL: URL) -> [FemiSongLine] {
        let engine = AudioMarkerEngine()
        guard let info = try? engine.read(from: audioURL),
              let raw = info.metadata.synchronizedLyrics.first?.lines,
              !raw.isEmpty
        else { return [] }
        var out: [FemiSongLine] = []
        var visibleIndex = 0
        for i in raw.indices {
            let line = raw[i]
            let startMs = ms(line.time)
            let endMs = i + 1 < raw.count ? ms(raw[i + 1].time) : startMs
            if line.text.isEmpty { continue }
            out.append(FemiSongLine(
                id: UUID(),
                index: visibleIndex,
                text: line.text,
                startMs: startMs,
                durationMs: max(0, endMs - startMs)
            ))
            visibleIndex += 1
        }
        return out
    }

    nonisolated private static func ms(_ t: AudioTimestamp) -> Int {
        Int(t.timeInterval * 1000)
    }
}
