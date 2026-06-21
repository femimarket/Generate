//
//  LyricExtractor.swift
//  Generate2
//

import Foundation
import AudioMarker

enum LyricExtractor {
    /// SYLT timestamps are per-WORD, not per-line. Build running lines by
    /// splitting each word's text on `\n` — every newline closes the current
    /// line. Words inside a line are joined with a single space.
    nonisolated static func read(audioURL: URL) -> [FemiSongLine] {
        let engine = AudioMarkerEngine()
        guard let info = try? engine.read(from: audioURL),
              let words = info.metadata.synchronizedLyrics.first?.lines,
              !words.isEmpty
        else { return [] }

        struct Pending { var startMs: Int; var words: [String] }
        var lines: [(start: Int, text: String)] = []
        var pending: Pending?

        for word in words {
            let wordStartMs = ms(word.time)
            let parts = word.text.components(separatedBy: "\n")
            for (i, part) in parts.enumerated() {
                let token = part.trimmingCharacters(in: .whitespaces)
                if !token.isEmpty {
                    if pending == nil {
                        pending = Pending(startMs: wordStartMs, words: [])
                    }
                    pending?.words.append(token)
                }
                if i < parts.count - 1 {
                    if let p = pending, !p.words.isEmpty {
                        lines.append((p.startMs, p.words.joined(separator: " ")))
                    }
                    pending = nil
                }
            }
        }
        if let p = pending, !p.words.isEmpty {
            lines.append((p.startMs, p.words.joined(separator: " ")))
        }

        var out: [FemiSongLine] = []
        for i in lines.indices {
            let start = lines[i].start
            let end = i + 1 < lines.count ? lines[i + 1].start : start
            out.append(FemiSongLine(
                id: UUID(),
                index: i,
                text: lines[i].text,
                startMs: start,
                durationMs: max(0, end - start)
            ))
        }
        return out
    }

    nonisolated private static func ms(_ t: AudioTimestamp) -> Int {
        Int(t.timeInterval * 1000)
    }
}
