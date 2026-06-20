//
//  ContentView.swift
//  Generate
//
//  Single-file flagship Generate screen.
//  Grid → derive → like → compose video → done.
//

import SwiftUI
import AVKit
import AVFoundation
import PhotosUI
import Observation
import FoundationModels
import Api
import UIKit
import ProjectService
import ImageIO
import UniformTypeIdentifiers


// MARK: - Pending action (derive-mode init payload)

/// Internal carrier for derive-mode arguments. Never crosses the public API —
/// the parent app passes `filename` and `tweak` as flat init parameters, we
/// pack them here for the view layer.
struct PendingAction {
    let filename: String
    let tweak: String
}

// MARK: - App root

/// Root view of the Generate2 library. Two modes:
/// - **Normal**: shows the grid + chrome. When the user taps an image, fires
///   `onImageTapped(path)` with the full on-disk path — the parent owns the
///   NavigationStack and decides what to push (their team's "Change it"
///   view). Parent gets server filename via `URL(fileURLWithPath:).lastPathComponent`.
/// - **Derive**: parent pushed Generate2 with a `filename` + `tweak`. On
///   appear, runs the derive pipeline (chat enrich → 3-model batch) and the
///   grid fills with the results.
///
/// Generate2 does not own a NavigationStack and emits no internal routes.
public struct ContentView: View {
    /// Parent app's topup handler. Awaited by the credit gate when balance
    /// runs dry — parent shows its purchase UI, resolves true on success.
    let onTopupNeeded: () async -> Bool
    /// Fired when the user taps an image in the grid. Parent receives the
    /// full on-disk path of the tapped image and pushes its own derive screen
    /// onto its NavigationStack.
    let onImageTapped: (_ path: String) -> Void
    /// Fired when the user taps the song-title slot in the toolbar. Parent
    /// presents its own song picker; returns `(audio bytes, suggested
    /// filename)` on success or `nil` on cancel. Generate2 writes the bytes
    /// to disk and uses the filename as the toolbar display title.
    let onUploadSong: () async -> Void
    /// Set only in derive mode. View runs this action on appear.
    let pendingAction: PendingAction?

    /// Normal mode. Use as the initial Generate2 entry on the parent's stack.
    /// Pass `idToken` to override the auto-IDFV bearer (e.g. simulator runs,
    /// dev tokens). When nil, falls back to `UIDevice.current.identifierForVendor`.
    public init(
        onTopupNeeded: @escaping () async -> Bool,
        onImageTapped: @escaping (String) -> Void,
        onUploadSong: @escaping () async -> Void,
        idToken: String? = nil
    ) {
        self.onTopupNeeded = onTopupNeeded
        self.onImageTapped = onImageTapped
        self.onUploadSong = onUploadSong
        self.pendingAction = nil
         Self.installBearer(idToken)
    }

    /// Derive mode. Parent pushes this onto its stack after the team's
    /// "Change it" view collected a tweak for `filename`. Generate2 fires
    /// the derive pipeline on appear; the grid fills with the new images.
    public init(
        onTopupNeeded: @escaping () async -> Bool,
        onImageTapped: @escaping (String) -> Void,
        onUploadSong: @escaping () async -> Void,
        filename: String,
        tweak: String,
        idToken: String? = nil
    ) {
        self.onTopupNeeded = onTopupNeeded
        self.onImageTapped = onImageTapped
        self.onUploadSong = onUploadSong
        self.pendingAction = PendingAction(filename: filename, tweak: tweak)
         Self.installBearer(idToken)
    }

    /// Bearer token. When `override` is nil, uses IDFV
    /// (`UIDevice.current.identifierForVendor`) — stable per app+vendor+device.
    /// Override when running on simulator or with a pinned dev token.
     private static func installBearer(_ override: String?) {
         let tokenid: String
         if let override {
             tokenid = override
         } else {
             guard let idfv = UIDevice.current.identifierForVendor?.uuidString else {
                 preconditionFailure("identifierForVendor returned nil")
             }
             tokenid = idfv
         }
         UserDefaults.standard.set(tokenid, forKey: "idToken")
         ApiAPIConfiguration.shared.customHeaders["Authorization"] = "Bearer \(tokenid)"
     }

    public var body: some View {
        Generate(
            onTopupNeeded: onTopupNeeded,
            onImageTapped: onImageTapped,
            onUploadSong: onUploadSong,
            pendingAction: pendingAction
        )
    }
}

// MARK: - FemiTheme

enum FemiTheme {
    static let background = Color(red: 0.039, green: 0.039, blue: 0.071)
    static let surface    = Color(red: 0.090, green: 0.090, blue: 0.137)
    static let onSurface  = Color(red: 0.949, green: 0.949, blue: 0.969)
    static let muted      = Color.white.opacity(0.6)
    static let accentMagenta = Color(red: 1.0, green: 0.169, blue: 0.839)
    static let accentBlue    = Color(red: 0.227, green: 0.627, blue: 1.0)

    static let accent = LinearGradient(
        colors: [accentMagenta, accentBlue],
        startPoint: .leading, endPoint: .trailing
    )
}

struct FemiAccentButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
     func makeBody(configuration: Configuration) -> some View {
         configuration.label
             .font(.headline.weight(.semibold))
             .foregroundStyle(.white)
             .padding(.vertical, 16)
             .frame(maxWidth: fullWidth ? .infinity : nil)
             .padding(.horizontal, fullWidth ? 0 : 28)
             .background(FemiTheme.accent, in: .capsule)
             .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
             .shadow(color: FemiTheme.accentMagenta.opacity(0.35), radius: 18, y: 8)
             .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
             .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
     }
}

// MARK: - Local models (client-side state)

// FemiGeneratedImage removed. The on-disk file IS the source of truth:
//   prompt + model live in xmp (ProjectService.getPrompt / .getModel),
//   like state lives in xmp:Rating (ProjectService.getLike),
//   lineIndex is presumed to live in xmp too (ProjectService.getLineIndex
//   when the accessor exists; until then, a sidecar dict on the view model).
// Grid item type is now `String` (server filename).

/// A single timed lyric line. Server-side forced alignment is the production
/// path; the client stub in `pasteLyrics` assigns equal 6s windows as a
/// placeholder until that pipeline exists.
struct FemiSongLine: Identifiable, Hashable, Sendable {
    let id: UUID
    let index: Int
    let text: String
    let startMs: Int
    let durationMs: Int
}

struct FemiGeneratedVideo: Identifiable, Hashable, Sendable {
    let id: UUID
    let file: String
    let posterFile: String
    let sourceImageIds: [String]
}

/// A video that's being generated in the background. The grid renders this as a
/// shimmer cell so the user can keep doing other things while it cooks.
struct FemiPendingVideo: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable { case working, failed }
    let id: UUID
    let sourceImageIds: [String]
    let posterFile: String
    var state: State = .working
}

/// An image being uploaded from the user's photo library. Mirrors FemiPendingVideo —
/// the grid shows a shimmer cell while the upload happens in the background.
struct FemiPendingImage: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable { case working, failed }
    let id: UUID
    var state: State = .working
}

/// An in-flight image generation (derive or fill-line). Rendered as a shimmer
/// cell in the grid so the rest of the UI stays interactive. `lineIndex` is
/// pre-computed at task start so the cell lands in the correct section.
struct FemiPendingGeneration: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable { case working, failed }
    let id: UUID
    let lineIndex: Int?
    var state: State = .working
}


// MARK: - Like store (client-only, UserDefaults)

@MainActor @Observable
final class FemiLikeStore {
    /// In-memory likes — image keys are filenames; video keys are UUID
    /// strings (sessions only — videos don't persist yet).
    var liked: Set<String> = []
     func isLiked(_ key: String) -> Bool { liked.contains(key) }
     func toggle(_ key: String) {
         if liked.contains(key) { liked.remove(key) }
         else { liked.insert(key) }
     }
     func setLiked(_ key: String, _ value: Bool) {
         if value { liked.insert(key) }
         else { liked.remove(key) }
     }
}

// MARK: - View model

@MainActor @Observable
final class FemiGenerateViewModel {

    enum GenerationKind: Hashable { case initial, derived, video }

    enum Phase: Hashable {
        case generating(GenerationKind)
        case grid
        case complete
    }

    enum GridFilter: Hashable, CaseIterable {
        case all, liked, videos
        var label: String {
            switch self { case .all: "All"; case .liked: "Liked"; case .videos: "Videos" }
        }
    }

    var phase: Phase = .grid
    var filter: GridFilter = .all

    // In-grid Photos-style select-for-video mode.
    var isSelectingForVideo: Bool = false
    /// Selection by filename. Used by the in-grid "select for video" mode.
    var selectedImageIds: [String] = []

    // Video detail playback (with sound).
    var viewingVideo: FemiGeneratedVideo? = nil

    var images: [String] = []
    /// Sidecar dict for line-index. Filename → audiolines.index. Will move
    /// into xmp once ProjectService exposes a getLineIndex / setLineIndex.
    var imageLineIndex: [String: Int] = [:]
    var videos: [FemiGeneratedVideo] = []
    var pendingVideos: [FemiPendingVideo] = []
    var pendingImages: [FemiPendingImage] = []
    var pendingGenerations: [FemiPendingGeneration] = []

    var errorMessage: String?

    /// Parent-supplied async topup handler. Set by `Generate` on appear from
    /// the `onTopupNeeded` arg threaded down from `ContentView`. The gate
    /// awaits this when credits run dry — parent shows its own sheet, resolves
    /// the closure when its purchase flow completes (success or cancel).
    var onTopupNeeded: (() async -> Bool)?

    /// Pasted lyrics text. Nil until the user pastes via the scene-player
    /// affordance. Once set, the grid switches from flat to sectioned-by-line.
    var lyrics: String?
    /// Timed lyric lines. Populated by `pasteLyrics`. Nil before paste.
    var audiolines: [FemiSongLine]?

    let likeStore = FemiLikeStore()

    init() {
         // if devSeedEnabled { devSeed() }
    }



    // Derived

    var filteredImages: [String] {
        switch filter {
        case .all, .videos: images
        case .liked: images.filter { likeStore.isLiked($0) }
        }
    }
    var likedImages: [String] { images.filter { likeStore.isLiked($0) } }
//
    // generationCost / videoCost removed — cost is server-side, surfaced as 402.

    // MARK: - Lyrics + line cursor

    /// Apply audio-extracted SYLT lines (via `LyricExtractor.read`). Empty
    /// input is treated as "no lyrics" — leaves `audiolines` untouched so the
    /// grid stays flat.
     func applyAudiolines(_ lines: [FemiSongLine]) {
         guard !lines.isEmpty else { return }
         withAnimation(.spring(duration: 0.5)) {
             self.audiolines = lines
             backfillLineIndices()
         }
     }

    /// On first lyric paste, walk through existing untagged images and assign
    /// them line indices in order. After this every image in `images` has a
    /// `lineIndex` (modulo the line count if more images than lines).
     private func backfillLineIndices() {
         guard let audiolines, !audiolines.isEmpty else { return }
         var nextLine = 0
         for i in images.indices where imageLineIndex[images[i]] == nil {
             imageLineIndex[images[i]] = audiolines[nextLine % audiolines.count].index
             nextLine += 1
         }
     }

    /// Cursor through the song: returns up to `count` line indices that
    /// currently have no images. Wraps around when all lines are covered.
     func nextUnfilledLines(count: Int) -> [Int] {
         guard let audiolines, !audiolines.isEmpty else { return [] }
         let used = Set(images.compactMap { imageLineIndex[$0] })
         var result: [Int] = []
         for line in audiolines where !used.contains(line.index) {
             result.append(line.index)
             if result.count >= count { return result }
         }
         // All lines filled at least once — fall through, wrapping by index.
         var i = 0
         while result.count < count {
             result.append(audiolines[i % audiolines.count].index)
             i += 1
         }
         return result
     }

    /// Stamp a fresh line index on each image in a freshly-returned batch.
    /// Pre-lyrics this is a no-op — images stay untagged until backfill.
     func tagBatch(_ batch: [String]) -> [String] {
         guard audiolines != nil else { return batch }
         let lineIndices = nextUnfilledLines(count: batch.count)
         for (offset, image) in batch.enumerated() where offset < lineIndices.count {
             imageLineIndex[image] = lineIndices[offset]
         }
         return batch
     }

    /// Power-user override (context menu on a section header): generate 3
    /// images all tagged with the given line index. Pending cells appear in
    /// the section immediately, real images replace them when generation
    /// completes. Bypasses the cursor — user is directly addressing a moment.
     func fillLine(_ lineIndex: Int) async {
         guard let line = audiolines?.first(where: { $0.index == lineIndex }) else { return }
         let prompt = line.text
         let pendings = (0..<3).map { _ in
             FemiPendingGeneration(id: UUID(), lineIndex: lineIndex)
         }
         var queue = pendings.map(\.id)
         withAnimation(.spring(duration: 0.3)) {
             pendingGenerations.append(contentsOf: pendings)
         }
         var topupFired = false
         await withTaskGroup(of: (value: API?, status: Int).self) { group in
             for api in Self.textToImageAPIs(prompt: prompt) {
                 group.addTask { [weak self] in
                     guard let self else { return (nil, 0) }
                     return await self.apiCall("fillLine", {
                         try await ApiHandlerAPI.apiHandler(API: api)
                     })
                 }
             }
             for await result in group {
                 if let row = result.value {
                     let file = Self.saveBase64(Self.resultFile(of: row), prompt: prompt, model: Self.resultModel(of: row), subject: ["line:\(lineIndex)"])
                     guard !queue.isEmpty else { continue }
                     let pid = queue.removeFirst()
                     withAnimation(.spring(duration: 0.35)) {
                         pendingGenerations.removeAll { $0.id == pid }
                         images.append(file)
                         imageLineIndex[file] = lineIndex
                     }
                 } else if result.status == 402, !topupFired {
                     topupFired = true
                     _ = await onTopupNeeded?()
                 }
             }
         }
         for pid in queue {
             if let i = pendingGenerations.firstIndex(where: { $0.id == pid }) {
                 pendingGenerations[i].state = .failed
             }
         }
     }

    // Lifecycle

     func bootstrap() async {
         loadProjectGenerationsFromDisk()
         if let song = ProjectService.getAudio()?.lastPathComponent { extractAudiolines(filename: song) }
     }

    /// Restore prior generations from the local project folder.
     func loadProjectGenerationsFromDisk() {
         let existing = Set(images)
         for url in ProjectService.getAllGenerations() {
             let filename = url.lastPathComponent
             guard !existing.contains(filename) else { continue }
             guard Self.isGridImageFile(filename) else { continue }
             images.append(filename)
         }
         syncImageLikesFromDisk()
     }

    /// Mirror on-disk `xmp:Rating` into `likeStore` (new UUIDs each launch).
     private func syncImageLikesFromDisk() {
         for image in images where ProjectService.getLike(image) {
             likeStore.setLiked(image, true)
         }
     }

     private static func isGridImageFile(_ filename: String) -> Bool {
         switch URL(fileURLWithPath: filename).pathExtension.lowercased() {
         case "png", "jpg", "jpeg", "webp", "gif", "heic", "heif": return true
         default: return false
         }
     }


    /// Parent's song picker returned audio bytes + a suggested filename.
    /// Save to the current project's folder on disk and reset local state
    /// so the grid reflects the new song. Kicks off off-main SYLT extraction
    /// — if the file carries timestamped lyrics, the grid switches to the
    /// sectioned-by-line layout once `audiolines` lands.
     /// Parent has just finished its song-picker flow and written audio to
     /// `ProjectService.saveAudio(...)`. Reset our grid state and re-run
     /// SYLT extraction from the new audio file on disk.
     func refreshFromAudio() {
         self.lyrics = nil
         self.audiolines = nil
         if let file = ProjectService.getAudio()?.lastPathComponent {
             extractAudiolines(filename: file)
         }
     }

    /// Off-main SYLT read via AudioMarker. No-op when the audio has no
    /// embedded lyrics — `applyAudiolines([])` early-returns.
     private func extractAudiolines(filename: String) {
         let url = ProjectService.getUrl(for: filename)
         Task.detached { [weak self] in
             let lines = LyricExtractor.read(audioURL: url)
             await self?.applyAudiolines(lines)
         }
     }

    // MARK: - User-triggered generations

    /// Toolbar "+" → "Generate". Fan out 3 image models in parallel with the
    /// project's summary as the prompt. Each result is appended to `images`
    /// as soon as it lands. **Topup fires at most once per batch** even if
    /// every model returns 402 — without this guard a parallel fan-out would
    /// stack three sheets.
    func generate() async {
        let pendings = (0..<3).map { _ in
            FemiPendingGeneration(id: UUID(), lineIndex: nil)
        }
        var queue = pendings.map(\.id)
        withAnimation(.spring(duration: 0.4)) {
            pendingGenerations.append(contentsOf: pendings)
            phase = .grid
        }
        let prompt = "cinematic music video still, vivid color grade, dramatic lighting, expressive performer mid-motion, shallow depth of field, 35mm film grain, emotional and atmospheric"
        var topupFired = false
        await withTaskGroup(of: (value: API?, status: Int).self) { group in
            for api in Self.textToImageAPIs(prompt: prompt) {
                group.addTask { [weak self] in
                    guard let self else { return (nil, 0) }
                    return await self.apiCall("generate", {
                        try await ApiHandlerAPI.apiHandler(API: api)
                    })
                }
            }
            for await result in group {
                if let row = result.value {
                    let file = Self.saveBase64(Self.resultFile(of: row), model: Self.resultModel(of: row))
                    guard !queue.isEmpty else { continue }
                    let pid = queue.removeFirst()
                    withAnimation(.spring(duration: 0.35)) {
                        pendingGenerations.removeAll { $0.id == pid }
                        images.append(file)
                    }
                } else if result.status == 402, !topupFired {
                    topupFired = true
                    _ = await onTopupNeeded?()
                }
            }
        }
        for pid in queue {
            if let i = pendingGenerations.firstIndex(where: { $0.id == pid }) {
                pendingGenerations[i].state = .failed
            }
        }
    }

     /// Build the 3-model fan-out of text-to-image APIs for a given prompt.
     /// Each `API` wraps a distinct model action; the server returns the same
     /// shape with `file` populated by the result base64 / filename.
     private static func textToImageAPIs(prompt: String) -> [API] {
         let actions: [ApiAction] = [
             .typeFlux2Pro(Flux2Pro(falRequestId: "", file: "", prompt: prompt, type: .flux2Pro)),
             .typeNanoBanana2(NanoBanana2(falRequestId: "", file: "", prompt: prompt, type: .nanoBanana2)),
             .typeZImageTurbo(ZImageTurbo(falRequestId: "", file: "", prompt: prompt, type: .zimageturbo)),
         ]
         return actions.map { Self.wrap($0) }
     }

     /// Build the single Ltx23A2V image-to-video API.
     private static func videoAPI(prompt: String, image: String, audio: String) -> API {
         Self.wrap(.typeLtx23A2V(Ltx23A2V(
             audio: audio, comfyRequestId: "", file: "", image: image,
             prompt: prompt, type: .ltx23a2v
         )))
     }

     private static func wrap(_ action: ApiAction) -> API {
         API(action: action, credit: 0, id: UUID(), status: .pending, userId: "")
     }

     /// Extract the result `file` from the server's response action.
     private static func resultFile(of api: API) -> String {
         switch api.action {
         case .typeFlux2Pro(let f): return f.file
         case .typeNanoBanana2(let f): return f.file
         case .typeZImageTurbo(let f): return f.file
         case .typeLtx23A2V(let f): return f.file
         default: return ""
         }
     }

     /// Name of the model that produced the response — written to xmp:Model.
     private static func resultModel(of api: API) -> String {
         switch api.action {
         case .typeFlux2Pro: return "Flux2Pro"
         case .typeNanoBanana2: return "NanoBanana2"
         case .typeZImageTurbo: return "ZImageTurbo"
         case .typeLtx23A2V: return "Ltx23A2V"
         default: return ""
         }
     }

    // Derive

    /// User tapped an image in the grid. Generate2 no longer owns the derive
    /// destination — fire the parent's callback with the full on-disk path so
    /// the parent can push its team's "Change it" view onto its own stack.
     func openDerive(_ image: String) {
         onImageTapped?(ProjectService.getUrl(for: image).path)
     }

    /// Parent-supplied image-tap callback. Set by `Generate` on appear.
    var onImageTapped: ((String) -> Void)?

     func dismissFemiPendingGeneration(_ id: UUID) {
         withAnimation { pendingGenerations.removeAll { $0.id == id } }
     }

    /// Fan out a three-model derive with `tweak` as the prompt. The new
    /// text-to-image models (Flux2Pro / NanoBanana2 / ZImageTurbo) don't
    /// accept an image input — only Ltx23A2V does — so derive is currently
    /// text-only. We still carry the source's line index forward so video
    /// trimming works on the derivatives.
     func runDerive(text: String, filename: String) async {
         let sourceLine = imageLineIndex[filename]
         let pendings = (0..<3).map { _ in
             FemiPendingGeneration(id: UUID(), lineIndex: sourceLine)
         }
         var queue = pendings.map(\.id)
         withAnimation(.spring(duration: 0.35)) {
             pendingGenerations.append(contentsOf: pendings)
         }
         var topupFired = false
         await withTaskGroup(of: (value: API?, status: Int).self) { group in
             for api in Self.textToImageAPIs(prompt: text) {
                 group.addTask { [weak self] in
                     guard let self else { return (nil, 0) }
                     return await self.apiCall("derive", {
                         try await ApiHandlerAPI.apiHandler(API: api)
                     })
                 }
             }
             for await result in group {
                 if let row = result.value {
                     let subject = sourceLine.map { ["line:\($0)"] }
                     let file = Self.saveBase64(Self.resultFile(of: row), prompt: text, model: Self.resultModel(of: row), subject: subject)
                     guard !queue.isEmpty else { continue }
                     let pid = queue.removeFirst()
                     withAnimation(.spring(duration: 0.35)) {
                         pendingGenerations.removeAll { $0.id == pid }
                         images.append(file)
                         if let sourceLine { imageLineIndex[file] = sourceLine }
                     }
                 } else if result.status == 402, !topupFired {
                     topupFired = true
                     _ = await onTopupNeeded?()
                 }
             }
         }
         for pid in queue {
             if let i = pendingGenerations.firstIndex(where: { $0.id == pid }) {
                 pendingGenerations[i].state = .failed
             }
         }
     }

    // Like

     func toggleLikeImage(_ image: String) {
         likeStore.toggle(image)
         ProjectService.like(image, likeStore.isLiked(image))
     }

     func toggleLikeVideo(_ video: FemiGeneratedVideo) {
         likeStore.toggle(video.id.uuidString)
     }

    // In-grid select mode for video creation.

    var canMakeVideo: Bool { !likedImages.isEmpty }

     func enterMakeVideo() {
         guard canMakeVideo else { return }
         selectedImageIds = []
         withAnimation(.spring(duration: 0.3)) { isSelectingForVideo = true }
     }

     func cancelMakeVideo() {
         withAnimation(.spring(duration: 0.3)) {
             isSelectingForVideo = false
             selectedImageIds = []
         }
     }

     func toggleSelection(_ file: String) {
         // Only liked images are selectable. Cap at 3.
         guard likeStore.isLiked(file) else { return }
         if let i = selectedImageIds.firstIndex(of: file) {
             selectedImageIds.remove(at: i)
         } else if selectedImageIds.count < 3 {
             selectedImageIds.append(file)
             UIImpactFeedbackGenerator(style: .light).impactOccurred()
         }
     }

    /// Fire-and-forget. Adds a FemiPendingVideo immediately, kicks off the long generation
    /// in a background Task, mutates `videos` when it completes. The grid stays
    /// interactive the entire time — user can derive, like, browse, even queue more
    /// videos while the first is cooking.
     func confirmMakeVideo() async {
         let ids = selectedImageIds
         let firstId = ids.first!
         let primary = images.first(where: { $0 == firstId })!
//
         // Exit select mode immediately. No phase change — stay on grid.
         isSelectingForVideo = false
         selectedImageIds = []
//
         let pending = FemiPendingVideo(
             id: UUID(),
             sourceImageIds: ids,
             posterFile: primary
         )
         withAnimation(.spring(duration: 0.3)) {
             pendingVideos.append(pending)
         }
//
         let audioFile = ProjectService.getAudio()!.lastPathComponent
         let prompt = ProjectService.getPrompt(primary) ?? ""
         let imageB64 = Self.base64(of: primary)
         let lineRange: (start: Int, duration: Int)? = {
             guard let lineIndex = imageLineIndex[primary],
                   let line = audiolines?.first(where: { $0.index == lineIndex })
             else { return nil }
             return (line.startMs, line.durationMs)
         }()
         Task { [weak self] in
             guard let self else { return }
             let audioB64: String
             if let lineRange {
                 audioB64 = try! await Self.trimmedAudioBase64(
                     file: audioFile, startMs: lineRange.start, durationMs: lineRange.duration
                 )
             } else {
                 audioB64 = Self.base64(of: audioFile)
             }
             let result = await self.apiCall("video", {
                 try await ApiHandlerAPI.apiHandler(API: Self.videoAPI(
                     prompt: prompt, image: imageB64, audio: audioB64
                 ))
             })
             if let row = result.value {
                 let file = Self.saveBase64(Self.resultFile(of: row), ext: "mp4")
                 withAnimation(.spring(duration: 0.4)) {
                     self.pendingVideos.removeAll { $0.id == pending.id }
                     self.videos.append(FemiGeneratedVideo(
                         id: UUID(),
                         file: file,
                         posterFile: primary,
                         sourceImageIds: ids
                     ))
                 }
             } else {
                 if let idx = self.pendingVideos.firstIndex(where: { $0.id == pending.id }) {
                     self.pendingVideos[idx].state = .failed
                 }
                 if result.status == 402 {
                     _ = await self.onTopupNeeded?()
                 }
             }
         }
     }

    /// Discard a failed pending video.
     func dismissFemiPendingVideo(_ id: UUID) {
         withAnimation { pendingVideos.removeAll { $0.id == id } }
     }

    // MARK: - Upload your own image

    /// Save user-supplied bytes directly to the project folder and add them to
    /// the grid. No server roundtrip — the upload route is gone from the API,
    /// so user-uploaded images live locally only.
     func handlePhotoPick(_ data: Data) {
         let name = "upload-\(UUID().uuidString).jpg"
         ProjectService.saveFile(data, named: name, prompt: nil, model: nil, subject: nil)
         withAnimation(.spring(duration: 0.4)) {
             self.images.append(name)
         }
     }

     func dismissFemiPendingImage(_ id: UUID) {
         withAnimation { pendingImages.removeAll { $0.id == id } }
     }

    // Credit / topup gate

    /// Minimum wallet balance required before generate/video; at or below → topup.

    /// Pre-flight credit check. Called on every user action (generate /
    /// derive / video / upload). Fetches balance synchronously if we don't
    /// have it yet, then either fires topup (and returns false) or returns
    /// true to let the action proceed. The actual generate call only runs
    /// when this returns true — no fire-then-topup.

    /// THE wrapper. Every server call goes through this. Returns
    /// `(value, status)`. Logs status + body preview on failure. Has zero UI
    /// side effects — caller inspects `status` and decides (e.g. user-action
    /// paths fire `onTopupNeeded` on 402; bg paths ignore).
    /// `status`: HTTP code, `0` on transport/decode failure, `200` on success.
    @MainActor
     func apiCall<T: Sendable>(_ label: String, _ work: @Sendable () async throws -> T) async -> (value: T?, status: Int) {
         do {
             let v = try await work()
             return (v, 200)
         } catch let err as ErrorResponse {
             if case let .error(code, data, _, underlying) = err {
                 let preview = data.flatMap { String(data: $0, encoding: .utf8) }.map { String($0.prefix(400)) } ?? "<no body>"
                 print("← \(label) FAIL status=\(code) body=\(preview) underlying=\(underlying)")
                 return (nil, code)
             }
             return (nil, 0)
         } catch {
             print("← \(label) FAIL error=\(error)")
             return (nil, 0)
         }
     }

     // refreshPricing removed

    /// Decode the base64 returned by the API and persist to the project folder
    /// under a fresh local filename. `ext` is sniffed from the bytes via ImageIO
    /// when not supplied (video callers pass `"mp4"` since ImageIO doesn't
    /// cover video). Returns the new filename for grid wiring.
    fileprivate static func saveBase64(_ b64: String, ext: String? = nil, prompt: String? = nil, model: String? = nil, subject: [String]? = nil) -> String {
        let data = Data(base64Encoded: b64)!
        let finalExt = ext ?? detectImageExt(data)
        let name = "gen-\(UUID().uuidString).\(finalExt)"
        ProjectService.saveFile(data, named: name, prompt: prompt, model: model, subject: subject)
        return name
    }

    private static func detectImageExt(_ data: Data) -> String {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(src) as? String,
              let ext = UTType(uti)?.preferredFilenameExtension
        else { return "bin" }
        return ext
    }

    /// Read a project file from disk and return its raw base64 — the API
    /// contract for `image` / `audio` fields.
    fileprivate static func base64(of file: String) -> String {
        let url = ProjectService.getUrl(for: file)
        return (try! Data(contentsOf: url)).base64EncodedString()
    }

    /// Trim `file` to [startMs, startMs+durationMs] via AVAssetExportSession,
    /// return the trimmed bytes as base64. Used by the video pipeline when the
    /// source image is tied to a lyric line.
    fileprivate static func trimmedAudioBase64(file: String, startMs: Int, durationMs: Int) async throws -> String {
        let inURL = ProjectService.getUrl(for: file)
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).m4a")
        let asset = AVURLAsset(url: inURL)
        let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)!
        exporter.outputURL = outURL
        exporter.outputFileType = .m4a
        exporter.timeRange = CMTimeRange(
            start: CMTime(value: Int64(startMs), timescale: 1000),
            duration: CMTime(value: Int64(durationMs), timescale: 1000)
        )
        try await exporter.export(to: outURL, as: .m4a)
        defer { try? FileManager.default.removeItem(at: outURL) }
        return try Data(contentsOf: outURL).base64EncodedString()
    }

}

// MARK: - Authorized image (femi.market, header-injected)

struct FemiAuthorizedImage: View {
    let filename: String
    var contentMode: ContentMode = .fill
//
    @State private var image: UIImage?
    @State private var failed = false
//
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
//
    var body: some View {
        ZStack {
            if isPreview {
                // Deterministic colorful placeholder so Xcode previews look like
                // real content without hitting the network.
                previewSurface
            } else if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else if failed {
                Color.black.opacity(0.4).overlay(
                    Image(systemName: "photo").foregroundStyle(FemiTheme.muted)
                )
            } else {
                Shimmer()
            }
        }
        .task(id: filename) {
            guard !isPreview else { return }
            await load()
        }
    }
//
    @ViewBuilder
    private var previewSurface: some View {
        if let img = bundledPreviewImage {
            Image(uiImage: img).resizable().aspectRatio(contentMode: contentMode)
        } else {
            let hue = Double(abs(filename.hashValue % 360)) / 360.0
            LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.7, brightness: 0.6),
                    Color(hue: hue + 0.1, saturation: 0.9, brightness: 0.4)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
//
    private var bundledPreviewImage: UIImage? {
        let ns = filename as NSString
        let name = ns.deletingPathExtension
        let ext = ns.pathExtension.isEmpty ? "png" : ns.pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }
//
    private func load() async {
        let localURL = ProjectService.getUrl(for: (filename as NSString).lastPathComponent)
        if let data = try? Data(contentsOf: localURL), let img = UIImage(data: data) {
            await MainActor.run { self.image = img }
        } else {
            await MainActor.run { self.failed = true }
        }
    }
}

// MARK: - Shimmer placeholder

private struct Shimmer: View {
    @State private var phase: CGFloat = -1
    var body: some View {
        GeometryReader { geo in
            ZStack {
                FemiTheme.surface
                LinearGradient(
                    colors: [.clear, FemiTheme.accentMagenta.opacity(0.35),
                             FemiTheme.accentBlue.opacity(0.35), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.7)
                .offset(x: phase * geo.size.width)
                .blur(radius: 18)
            }
        }
        .clipped()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}

// MARK: - Authorized auto-muted looping video cell

private struct AuthorizedVideoView: UIViewRepresentable {
    let url: URL
     func makeUIView(context: Context) -> PlayerUIView { PlayerUIView(url: url) }
     func updateUIView(_ uiView: PlayerUIView, context: Context) {}
}

private final class PlayerUIView: UIView {
    private let player: AVPlayer
    private let layerView = AVPlayerLayer()
    init(url: URL) {
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \((UIDevice.current.identifierForVendor?.uuidString ?? ""))"]
        ])
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        super.init(frame: .zero)
        backgroundColor = .black
        player.isMuted = true
        player.actionAtItemEnd = .none
        layerView.player = player
        layerView.videoGravity = .resizeAspectFill
        layer.addSublayer(layerView)
        player.play()
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak player] _ in player?.seek(to: .zero); player?.play() }
    }
    required init?(coder: NSCoder) { fatalError() }
     override func layoutSubviews() { super.layoutSubviews(); layerView.frame = bounds }
}

// MARK: - Video detail playback (full screen, sound on)

/// Tap a video cell → this opens full-screen with native controls and audio.
/// Switches AVAudioSession to .playback so the user's silent switch doesn't mute
/// the video (intentional: they tapped to watch, that's consent). Reverts to
/// .ambient on dismiss so the rest of the app stays polite.
private struct VideoDetailView: View {
    let video: FemiGeneratedVideo
    @Bindable var viewModel: FemiGenerateViewModel
    let onDismiss: () -> Void
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                FemiAuthorizedImage(filename: video.posterFile)
                    .ignoresSafeArea()
                ProgressView().controlSize(.large).tint(.white)
            }
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: .circle)
                    }
                    .padding(16)
                }
                Spacer()
            }
        }
        .task { setupPlayback() }
        .onDisappear { teardownPlayback() }
    }

     private func setupPlayback() {
         let path = video.file.hasPrefix("/") ? String(video.file.dropFirst()) : video.file
         guard !path.isEmpty, let url = URL(string: "https://femi.market/\(path)") else { return }
         try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
         try? AVAudioSession.sharedInstance().setActive(true)
         let asset = AVURLAsset(url: url, options: [
             "AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \((UIDevice.current.identifierForVendor?.uuidString ?? ""))"]
         ])
         let item = AVPlayerItem(asset: asset)
         let p = AVPlayer(playerItem: item)
         p.isMuted = false
         self.player = p
         p.play()
     }

     private func teardownPlayback() {
         player?.pause()
         player = nil
         try? AVAudioSession.sharedInstance().setCategory(
             .ambient, mode: .default, options: [.mixWithOthers]
         )
     }
}

// MARK: - Credit chip

private struct CreditChip: View {
    let credits: Int64
    let isLoading: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill").font(.caption.weight(.bold))
                .foregroundStyle(FemiTheme.accent)
            if isLoading {
                ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
            } else {
                Text("\(credits)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FemiTheme.onSurface)
                    .contentTransition(.numericText(value: Double(credits)))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}

// MARK: - ContentView

struct Generate: View {
    /// Parent app's topup handler — installed on the view model on appear so
    /// `gateOnCredit` can await it when credits run dry.
    let onTopupNeeded: () async -> Bool
    /// Fired when the user taps an image in the grid. Threaded through to the
    /// view model on appear.
    let onImageTapped: (String) -> Void
    /// Fired when the user taps the song-title slot. Returns (bytes,
    /// suggested filename) on pick, nil on cancel.
    let onUploadSong: () async -> Void
    /// Set only in derive mode. Runs on the first task tick after appear.
    let pendingAction: PendingAction?
    @State private var viewModel = FemiGenerateViewModel()
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false
    var body: some View {
        ZStack {
            FemiTheme.background.ignoresSafeArea()
            content
        }
        .toolbar { toolbar }
        .fullScreenCover(item: $viewModel.viewingVideo) { video in
            VideoDetailView(video: video, viewModel: viewModel) {
                viewModel.viewingVideo = nil
            }
        }
        .environment(viewModel)
        .preferredColorScheme(.dark)
        .task {
            viewModel.onTopupNeeded = onTopupNeeded
            viewModel.onImageTapped = onImageTapped
            await viewModel.bootstrap()
            // Derive mode: parent pushed us with a pending action — run it
            // once the bootstrap has settled so pricing / project are ready.
            if let pendingAction {
                await viewModel.runDerive(
                    text: pendingAction.tweak,
                    filename: pendingAction.filename
                )
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker,
                      selection: $photoPickerItem,
                      matching: .images)
        // Photo picker bridge: user picks → load Data → hand off to view model.
        .onChange(of: photoPickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    viewModel.handlePhotoPick(data)
                }
                photoPickerItem = nil
            }
        }
        .toolbar(viewModel.isSelectingForVideo ? .hidden : .visible, for: .tabBar)
        .animation(.spring(duration: 0.3), value: viewModel.isSelectingForVideo)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.isSelectingForVideo {
                FemiMakeVideoShelf(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .generating(let kind):
            GeneratingOverlay(kind: kind)
        case .grid:
            gridLayer
        case .complete:
            CompletionView(onDone: { viewModel.phase = .grid })
        }
    }

    private var gridLayer: some View {
        GridView(viewModel: viewModel)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if viewModel.isSelectingForVideo {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: viewModel.cancelMakeVideo)
                    .foregroundStyle(FemiTheme.onSurface)
            }
            ToolbarItem(placement: .principal) {
                Text("\(viewModel.selectedImageIds.count) of 3 picked")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FemiTheme.muted)
                    .contentTransition(.numericText(value: Double(viewModel.selectedImageIds.count)))
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                if shouldShowUploadButton {
                    Menu {
                        Button {
                            Task { await viewModel.generate() }
                        } label: {
                            Label("Generate", systemImage: "sparkles")
                        }
                        Button {
                            showingPhotoPicker = true
                        } label: {
                            Label("Upload from Photos", systemImage: "photo")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(FemiTheme.onSurface)
                    }
                }
            }
            // Title tap → parent's song picker (common, discoverable).
            // Title long-press → parent's project picker (rare, hidden moat).
            ToolbarItem(placement: .principal) {
                Button {
                    Task {
                        await onUploadSong()
                        viewModel.refreshFromAudio()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let song = ProjectService.getAudio()?.lastPathComponent {
                            Text(song)
                                .font(.headline)
                                .foregroundStyle(FemiTheme.onSurface)
                                .lineLimit(1)
                        } else {
                            Text("No song")
                                .font(.headline)
                                .foregroundStyle(FemiTheme.muted)
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FemiTheme.muted)
                    }
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if shouldShowMakeVideoButton {
                    Button(action: viewModel.enterMakeVideo) {
                        HStack(spacing: 4) {
                            Image(systemName: "film.fill")
                            Text("Make Video")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(viewModel.canMakeVideo ? FemiTheme.onSurface : FemiTheme.muted)
                    .disabled(!viewModel.canMakeVideo)
                    .accessibilityLabel("Make video")
                    .accessibilityHint(viewModel.canMakeVideo
                        ? "Pick up to three of your saved pictures"
                        : "Save at least one picture first")
                }
            }
        }
    }

    /// Show the + (upload) button only when the user is on the grid.
    private var shouldShowUploadButton: Bool {
        if case .grid = viewModel.phase { return true }
        return false
    }

    /// Toolbar chrome (switcher, credit chip, Make Video) only appears on
    /// the grid. Splash / startCta / generating overlay / completion stay
    /// chrome-free.
    private var shouldShowGridChrome: Bool {
        if case .grid = viewModel.phase { return true }
        return false
    }

    /// Only show Make Video in the toolbar when the user is on the grid (not derive, etc.).
    private var shouldShowMakeVideoButton: Bool {
        if case .grid = viewModel.phase { return true }
        return false
    }

}


// MARK: - Generating overlay

private struct GeneratingOverlay: View {
    let kind: FemiGenerateViewModel.GenerationKind
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().stroke(FemiTheme.accentMagenta.opacity(0.4), lineWidth: 3)
                    .frame(width: 140, height: 140).blur(radius: 2)
                ProgressView().controlSize(.large).tint(FemiTheme.accentMagenta)
            }
            Text(title).font(.title3.bold()).foregroundStyle(FemiTheme.onSurface)
            Text(subtitle).font(.subheadline).foregroundStyle(FemiTheme.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
        }
        .background(FemiTheme.background.ignoresSafeArea())
    }
    private var title: String {
        switch kind {
        case .initial: "Making your pictures"
        case .derived: "Making new ones"
        case .video: "Making your video"
        }
    }
    private var subtitle: String {
        switch kind {
        case .initial: "Music's on. Just a moment."
        case .derived: "Just a moment."
        case .video: "Almost there."
        }
    }
}

// MARK: - Grid helpers (match DemoGenerate styling)

@ViewBuilder
 private func femiSelectionBadge(order: Int?) -> some View {
     ZStack {
         if let order {
             Text("\(order + 1)")
                 .font(.caption.bold())
                 .foregroundStyle(.white)
                 .frame(width: 26, height: 26)
                 .background(FemiTheme.accent, in: .circle)
                 .overlay(Circle().stroke(.white, lineWidth: 1.5))
         } else {
             Circle()
                 .stroke(.white.opacity(0.9), lineWidth: 1.5)
                 .background(Circle().fill(.black.opacity(0.25)))
                 .frame(width: 26, height: 26)
         }
     }
     .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
     .padding(8)
 }

@ViewBuilder
 private func femiHeartButton(isLiked: Bool, action: @escaping @MainActor () -> Void) -> some View {
     Button {
         withAnimation(.spring(duration: 0.35)) { action() }
         UIImpactFeedbackGenerator(style: .medium).impactOccurred()
     } label: {
         if isLiked {
             Image(systemName: "heart.fill")
                 .font(.caption.weight(.bold))
                 .foregroundStyle(.white)
                 .padding(7)
                 .background(FemiTheme.accent, in: .circle)
                 .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 0.5))
                 .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
         } else {
             Image(systemName: "heart")
                 .font(.caption.weight(.bold))
                 .foregroundStyle(.white)
                 .padding(7)
                 .background(.ultraThinMaterial, in: .circle)
                 .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 0.5))
                 .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
         }
     }
     .buttonStyle(.plain)
     .padding(8)
     .contentTransition(.symbolEffect(.replace))
     .accessibilityLabel(isLiked ? "Saved, double tap to unsave" : "Save")
 }

// MARK: - Grid

/// Single image cell. Heart toggles via `likeStore`; disk mirror in `toggleLikeImage`.
private struct FemiImageCell: View {
    let image: String
    @Bindable var viewModel: FemiGenerateViewModel

    var body: some View {
        let liked = viewModel.likeStore.isLiked(image)
        let selecting = viewModel.isSelectingForVideo
        let selected = viewModel.selectedImageIds.contains(image)
        let eligible = !selecting || liked

        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { FemiAuthorizedImage(filename: image) }
            .clipped()
            .overlay {
                if selecting && selected {
                    FemiTheme.accentMagenta.opacity(0.18)
                }
            }
            .overlay(alignment: .topTrailing) {
                if selecting {
                    if eligible {
                        femiSelectionBadge(
                            order: viewModel.selectedImageIds.firstIndex(of: image)
                        )
                    }
                } else {
                    femiHeartButton(isLiked: liked) {
                        viewModel.toggleLikeImage(image)
                    }
                }
            }
            .opacity(eligible ? 1 : 0.3)
            .contentShape(.rect)
            .onTapGesture {
                if selecting {
                    guard eligible else { return }
                    withAnimation(.spring(duration: 0.25)) {
                        viewModel.toggleSelection(image)
                    }
                } else {
                    viewModel.openDerive(image)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                selecting
                    ? (selected ? "Picture, selected" : "Picture, double tap to select")
                    : "Picture, double tap to remake"
            )
            .accessibilityValue(liked ? "Saved" : "")
    }
}

/// Commit shelf while picking pictures for a video (Photos pattern).
private struct FemiMakeVideoShelf: View {
    @Bindable var viewModel: FemiGenerateViewModel

    var body: some View {
        Button("Make video") {
            Task { await viewModel.confirmMakeVideo() }
        }
        .buttonStyle(FemiAccentButtonStyle())
        .disabled(viewModel.selectedImageIds.isEmpty)
        .opacity(viewModel.selectedImageIds.isEmpty ? 0.5 : 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }
}

private struct GridView: View {
    @Bindable var viewModel: FemiGenerateViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    private var visibleVideos: [FemiGeneratedVideo] {
        switch viewModel.filter {
        case .all, .videos: return viewModel.videos
        case .liked: return viewModel.videos.filter { viewModel.likeStore.isLiked($0.id.uuidString) }
        }
    }

    /// Pending videos show on All and Videos filters (curation isn't possible yet).
    private var visibleFemiPendingVideos: [FemiPendingVideo] {
        switch viewModel.filter {
        case .all, .videos: return viewModel.pendingVideos
        case .liked: return []
        }
    }

    /// Pending uploads only visible on the All filter — they can't be liked yet.
    private var visibleFemiPendingImages: [FemiPendingImage] {
        viewModel.filter == .all ? viewModel.pendingImages : []
    }

    /// Pending generations only visible on the All filter for the same reason.
    private var visibleFemiPendingGenerations: [FemiPendingGeneration] {
        viewModel.filter == .all ? viewModel.pendingGenerations : []
    }

    private var hasNoContent: Bool {
        let imagesEmpty = viewModel.filter == .videos
            || (viewModel.filteredImages.isEmpty
                && visibleFemiPendingImages.isEmpty
                && visibleFemiPendingGenerations.isEmpty)
        let videosEmpty = visibleVideos.isEmpty && visibleFemiPendingVideos.isEmpty
        return imagesEmpty && videosEmpty
    }

    /// Sectioned layout kicks in only on the All filter and only after the
    /// user has pasted lyrics. Liked / Videos stay flat — those are curation
    /// surfaces and don't benefit from line grouping.
    private var shouldSection: Bool {
        viewModel.filter == .all && viewModel.audiolines != nil
    }

    private var bottomChromeMargin: CGFloat {
        viewModel.isSelectingForVideo ? 80 : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if hasNoContent {
                emptyState
            } else if shouldSection, let audiolines = viewModel.audiolines {
                sectionedScroll(audiolines: audiolines)
            } else {
                flatScroll
            }
        }
    }

    // MARK: - Flat scroll (pre-lyrics or non-All filters)

    private var flatScroll: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                if viewModel.filter != .videos {
                    ForEach(visibleFemiPendingImages) { pendingImageCell($0) }
                    ForEach(visibleFemiPendingGenerations) { pendingGenerationCell($0) }
                    ForEach(viewModel.filteredImages, id: \.self) { FemiImageCell(image: $0, viewModel: viewModel) }
                }
                ForEach(visibleFemiPendingVideos) { pendingCell($0) }
                ForEach(visibleVideos) { videoCell($0) }
            }
            .padding(.horizontal, 2)
            .padding(.top, 6)
        }
        .contentMargins(.bottom, bottomChromeMargin, for: .scrollContent)
    }

    // MARK: - Sectioned scroll (post-lyrics, All filter)

    /// Photos-style sectioned grid. Each lyric line is a `Section` with a
    /// pinned header that sticks to the top of the viewport as you scroll —
    /// matches the Photos.app pattern. Empty lines render as the header
    /// alone (no body), keeping the song's structure visible without noise.
    @ViewBuilder
     private func sectionedScroll(audiolines: [FemiSongLine]) -> some View {
         ScrollView {
             LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                 if !visibleFemiPendingImages.isEmpty || !visibleFemiPendingVideos.isEmpty {
                     LazyVGrid(columns: columns, spacing: 2) {
                         ForEach(visibleFemiPendingImages) { pendingImageCell($0) }
                         ForEach(visibleFemiPendingVideos) { pendingCell($0) }
                     }
                     .padding(.horizontal, 2)
                     .padding(.top, 6)
                 }
//
                 ForEach(audiolines) { line in
                     let imagesForLine = viewModel.filteredImages.filter { viewModel.imageLineIndex[$0] == line.index }
                     let pendingsForLine = visibleFemiPendingGenerations.filter { $0.lineIndex == line.index }
                     Section {
                         if !pendingsForLine.isEmpty || !imagesForLine.isEmpty {
                             LazyVGrid(columns: columns, spacing: 2) {
                                 ForEach(pendingsForLine) { pendingGenerationCell($0) }
                                 ForEach(imagesForLine, id: \.self) { FemiImageCell(image: $0, viewModel: viewModel) }
                             }
                             .padding(.horizontal, 2)
                             .padding(.top, 4)
                         }
                     } header: {
                         sectionHeader(
                             line: line,
                             imageCount: imagesForLine.count + pendingsForLine.count
                         )
                     }
                 }
//
                 if !visibleVideos.isEmpty {
                     LazyVGrid(columns: columns, spacing: 2) {
                         ForEach(visibleVideos) { videoCell($0) }
                     }
                     .padding(.horizontal, 2)
                     .padding(.top, 12)
                 }
             }
         }
         .contentMargins(.bottom, bottomChromeMargin, for: .scrollContent)
     }

    /// Photos-style section header: bold display title + small caption
    /// underneath, opaque background so the pinned state reads cleanly.
    /// Native power-user discovery via `.contextMenu` (long-press surfaces
    /// the action with iOS's own animation + haptic).
    @ViewBuilder
     private func sectionHeader(line: FemiSongLine, imageCount: Int) -> some View {
         VStack(alignment: .leading, spacing: 2) {
             Text(line.text)
                 .font(.title2.weight(.bold))
                 .foregroundStyle(FemiTheme.onSurface)
                 .lineLimit(2)
                 .multilineTextAlignment(.leading)
             Text(imageCount == 0 ? "No pictures yet"
                                 : "\(imageCount) \(imageCount == 1 ? "picture" : "pictures")")
                 .font(.subheadline)
                 .foregroundStyle(FemiTheme.muted)
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.horizontal, 16)
         .padding(.top, 28)
         .padding(.bottom, 10)
         .background(FemiTheme.background)
         .contextMenu {
             Button {
                 Task { await viewModel.fillLine(line.index) }
             } label: {
                 Label("Make pictures for this line", systemImage: "sparkles")
             }
         }
         .accessibilityLabel(line.text)
     }

    // MARK: - Empty state (C6)

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: emptyIcon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(FemiTheme.muted)
            Text(emptyTitle)
                .font(.headline)
                .foregroundStyle(FemiTheme.onSurface)
            Text(emptyBody)
                .font(.subheadline)
                .foregroundStyle(FemiTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIcon: String {
        switch viewModel.filter {
        case .all: "photo.on.rectangle"
        case .liked: "heart"
        case .videos: "film"
        }
    }
    private var emptyTitle: String {
        switch viewModel.filter {
        case .all: "No pictures yet"
        case .liked: "Nothing hearted yet"
        case .videos: "No videos yet"
        }
    }
    private var emptyBody: String {
        switch viewModel.filter {
        case .all: "Tap Start to make your first ones."
        case .liked: "Hold a picture to heart it. Hearted pictures can become videos."
        case .videos: "Heart a few pictures, then make a video."
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(FemiGenerateViewModel.GridFilter.allCases, id: \.self) { f in
                Button {
                    withAnimation(.spring) { viewModel.filter = f }
                } label: {
                    Text(f.label)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background {
                    if viewModel.filter == f {
                        Capsule().fill(FemiTheme.accentMagenta.opacity(0.25))
                            .overlay(Capsule().stroke(FemiTheme.accentMagenta.opacity(0.6), lineWidth: 1))
                    } else {
                        Capsule().fill(.white.opacity(0.08))
                    }
                }
                .foregroundStyle(viewModel.filter == f ? FemiTheme.onSurface : FemiTheme.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    // Sized square via a placeholder Color.clear with explicit 1:1 fit.
    // This pattern guarantees every column width matches; the old approach
    // (`.aspectRatio(1, contentMode: .fill)` on the image itself) let the image
    // propose its own intrinsic size first, which can fight the column width
    // and produce subtle differences across cells.


    /// Photos-style numbered selection badge. Empty circle when eligible-but-not-picked,
    /// magenta filled circle with the pick order when selected.
    @ViewBuilder
     private func selectionBadge(order: Int?) -> some View {
         ZStack {
             if let order {
                 Text("\(order + 1)")
                     .font(.caption.bold())
                     .foregroundStyle(.white)
                     .frame(width: 26, height: 26)
                     .background(FemiTheme.accent, in: .circle)
                     .overlay(Circle().stroke(.white, lineWidth: 1.5))
             } else {
                 Circle()
                     .stroke(.white.opacity(0.9), lineWidth: 1.5)
                     .background(Circle().fill(.black.opacity(0.25)))
                     .frame(width: 26, height: 26)
             }
         }
         .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
         .padding(8)
     }

    /// Shimmer cell while an uploaded photo is sent to the image service.
    @ViewBuilder
     private func pendingImageCell(_ pending: FemiPendingImage) -> some View {
         Color.clear
             .aspectRatio(1, contentMode: .fit)
             .overlay {
                 ZStack {
                     FemiTheme.surface
                     if pending.state == .working {
                         Shimmer()
                         VStack(spacing: 8) {
                             ProgressView()
                                 .progressViewStyle(.circular)
                                 .tint(.white)
                             Text("Uploading…")
                                 .font(.caption.weight(.semibold))
                                 .foregroundStyle(.white)
                                 .shadow(color: .black.opacity(0.5), radius: 4)
                         }
                     } else {
                         VStack(spacing: 8) {
                             Image(systemName: "exclamationmark.triangle.fill")
                                 .font(.title3)
                                 .foregroundStyle(.white)
                             Text("Upload failed — tap to dismiss")
                                 .font(.caption.weight(.semibold))
                                 .foregroundStyle(.white)
                                 .multilineTextAlignment(.center)
                                 .padding(.horizontal, 8)
                         }
                     }
                 }
             }
             .clipped()
             .contentShape(.rect)
             .onTapGesture {
                 if pending.state == .failed {
                     viewModel.dismissFemiPendingImage(pending.id)
                 }
             }
     }

    /// Shimmer cell for in-flight image generation (derive or fill-line).
    /// Same visual language as `pendingImageCell` — the user reads "something
    /// is being made for this slot" without us having to label which kind.
    @ViewBuilder
     private func pendingGenerationCell(_ pending: FemiPendingGeneration) -> some View {
         Color.clear
             .aspectRatio(1, contentMode: .fit)
             .overlay {
                 ZStack {
                     FemiTheme.surface
                     if pending.state == .working {
                         Shimmer()
                         VStack(spacing: 8) {
                             ProgressView()
                                 .progressViewStyle(.circular)
                                 .tint(.white)
                             Text("Making…")
                                 .font(.caption.weight(.semibold))
                                 .foregroundStyle(.white)
                                 .shadow(color: .black.opacity(0.5), radius: 4)
                         }
                     } else {
                         VStack(spacing: 8) {
                             Image(systemName: "exclamationmark.triangle.fill")
                                 .font(.title3)
                                 .foregroundStyle(.white)
                             Text("Failed — tap to dismiss")
                                 .font(.caption.weight(.semibold))
                                 .foregroundStyle(.white)
                                 .multilineTextAlignment(.center)
                                 .padding(.horizontal, 8)
                         }
                     }
                 }
             }
             .clipped()
             .contentShape(.rect)
             .onTapGesture {
                 if pending.state == .failed {
                     viewModel.dismissFemiPendingGeneration(pending.id)
                 }
             }
     }

    /// Shimmer cell with the source picture as a soft poster while video gen runs.
    /// When generation fails, taps dismiss the cell.
    @ViewBuilder
     private func pendingCell(_ pending: FemiPendingVideo) -> some View {
         Color.clear
             .aspectRatio(1, contentMode: .fit)
             .overlay {
                 ZStack {
                     FemiAuthorizedImage(filename: pending.posterFile)
                         .opacity(pending.state == .failed ? 0.5 : 0.4)
                     if pending.state == .working {
                         VStack(spacing: 10) {
                             ProgressView()
                                 .progressViewStyle(.circular)
                                 .tint(.white)
                                 .controlSize(.regular)
                             Text("Making…")
                                 .font(.caption.weight(.semibold))
                                 .foregroundStyle(.white)
                                 .shadow(color: .black.opacity(0.5), radius: 4)
                         }
                     } else {
                         VStack(spacing: 8) {
                             Image(systemName: "exclamationmark.triangle.fill")
                                 .font(.title3)
                                 .foregroundStyle(.white)
                             Text("Failed — tap to dismiss")
                                 .font(.caption.weight(.semibold))
                                 .foregroundStyle(.white)
                                 .multilineTextAlignment(.center)
                                 .padding(.horizontal, 8)
                         }
                     }
                 }
             }
             .clipped()
             .contentShape(.rect)
             .onTapGesture {
                 if pending.state == .failed {
                     viewModel.dismissFemiPendingVideo(pending.id)
                 }
             }
     }

    @ViewBuilder
     private func videoCell(_ video: FemiGeneratedVideo) -> some View {
         // Videos aren't selectable for new videos (per spec: video-from-video deferred).
         // In select mode, dim them.
         let selecting = viewModel.isSelectingForVideo
         Color.clear
             .aspectRatio(1, contentMode: .fit)
             .overlay {
                 ZStack {
                     let p = video.file.hasPrefix("/") ? String(video.file.dropFirst()) : video.file
                     if !p.isEmpty, let url = URL(string: "https://femi.market/\(p)") {
                         AuthorizedVideoView(url: url)
                     } else {
                         FemiAuthorizedImage(filename: video.posterFile)
                     }
                     Image(systemName: "play.circle.fill").font(.system(size: 28))
                         .foregroundStyle(.white.opacity(0.85)).shadow(radius: 4)
                 }
             }
             .clipped()
             .overlay(alignment: .topTrailing) {
                 if !selecting {
                     femiHeartButton(isLiked: viewModel.likeStore.isLiked(video.id.uuidString)) {
                         viewModel.toggleLikeVideo(video)
                     }
                 }
             }
             .opacity(selecting ? 0.3 : 1)
             .contentShape(.rect)
             .onTapGesture {
                 guard !selecting else { return }
                 viewModel.viewingVideo = video
             }
             .accessibilityLabel("Video, double tap to watch")
             .accessibilityValue(viewModel.likeStore.isLiked(video.id.uuidString) ? "Saved" : "")
     }
}

// MARK: - Completion

private struct CompletionView: View {
    let onDone: () -> Void
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle().fill(FemiTheme.accentMagenta.opacity(pulse ? 0.5 : 0.2))
                    .frame(width: pulse ? 260 : 200, height: pulse ? 260 : 200)
                    .blur(radius: 30)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(FemiTheme.accent)
            }
            VStack(spacing: 12) {
                Text("You did it.").font(.largeTitle.bold())
                    .foregroundStyle(FemiTheme.onSurface)
                Text("That's a video. Make more whenever you want.")
                    .font(.body).foregroundStyle(FemiTheme.muted)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(FemiAccentButtonStyle())
                .padding(.horizontal, 24).padding(.bottom, 48)
        }
        .background(FemiTheme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}


// MARK: - JWT

 private func jwtSub() -> String? {
     guard let token = UserDefaults.standard.string(forKey: "idToken") else { return nil }
     let parts = token.split(separator: ".")
     guard parts.count >= 2 else { return nil }
     var payload = String(parts[1])
         .replacingOccurrences(of: "-", with: "+")
         .replacingOccurrences(of: "_", with: "/")
     let pad = (4 - payload.count % 4) % 4
     payload.append(String(repeating: "=", count: pad))
     guard
         let data = Data(base64Encoded: payload),
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let sub = json["sub"] as? String
     else { return nil }
     return sub
 }

