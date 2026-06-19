////
////  ContentView.swift
////  Generate
////
////  Single-file flagship Generate screen.
////  Grid → derive → like → compose video → done.
////
//
//import SwiftUI
//import AVKit
//import AVFoundation
//import PhotosUI
//import Observation
//import FoundationModels
//import Api
//import UIKit
//import ProjectService
//
//
//// MARK: - Pending action (derive-mode init payload)
//
///// Internal carrier for derive-mode arguments. Never crosses the public API —
///// the parent app passes `filename` and `tweak` as flat init parameters, we
///// pack them here for the view layer.
//struct PendingAction {
//    let filename: String
//    let tweak: String
//}
//
//// MARK: - App root
//
///// Root view of the Generate2 library. Two modes:
///// - **Normal**: shows the grid + chrome. When the user taps an image, fires
/////   `onImageTapped(path)` with the full on-disk path — the parent owns the
/////   NavigationStack and decides what to push (their team's "Change it"
/////   view). Parent gets server filename via `URL(fileURLWithPath:).lastPathComponent`.
///// - **Derive**: parent pushed Generate2 with a `filename` + `tweak`. On
/////   appear, runs the derive pipeline (chat enrich → 3-model batch) and the
/////   grid fills with the results.
/////
///// Generate2 does not own a NavigationStack and emits no internal routes.
//public struct ContentView: View {
//    /// Parent app's topup handler. Awaited by the credit gate when balance
//    /// runs dry — parent shows its purchase UI, resolves true on success.
//    let onTopupNeeded: () async -> Bool
//    /// Fired when the user taps an image in the grid. Parent receives the
//    /// full on-disk path of the tapped image and pushes its own derive screen
//    /// onto its NavigationStack.
//    let onImageTapped: (_ path: String) -> Void
//    /// Fired when the user taps the song-title slot in the toolbar. Parent
//    /// presents its own song picker; returns `(audio bytes, suggested
//    /// filename)` on success or `nil` on cancel. Generate2 writes the bytes
//    /// to disk and uses the filename as the toolbar display title.
//    let onUploadSong: () async -> (Data, String)?
//    /// Fired when the user long-presses the song-title slot. Parent presents
//    /// its own project-picker surface (rare action, hidden moat).
//    let onPickProject: () -> Void
//    /// Set only in derive mode. View runs this action on appear.
//    let pendingAction: PendingAction?
//
//    /// Normal mode. Use as the initial Generate2 entry on the parent's stack.
//    public init(
//        onTopupNeeded: @escaping () async -> Bool,
//        onImageTapped: @escaping (String) -> Void,
//        onUploadSong: @escaping () async -> (Data, String)?,
//        onPickProject: @escaping () -> Void
//    ) {
//        self.onTopupNeeded = onTopupNeeded
//        self.onImageTapped = onImageTapped
//        self.onUploadSong = onUploadSong
//        self.onPickProject = onPickProject
//        self.pendingAction = nil
////         Self.installBearer()
//    }
//
//    /// Derive mode. Parent pushes this onto its stack after the team's
//    /// "Change it" view collected a tweak for `filename`. Generate2 fires
//    /// the derive pipeline on appear; the grid fills with the new images.
//    public init(
//        onTopupNeeded: @escaping () async -> Bool,
//        onImageTapped: @escaping (String) -> Void,
//        onUploadSong: @escaping () async -> (Data, String)?,
//        onPickProject: @escaping () -> Void,
//        filename: String,
//        tweak: String
//    ) {
//        self.onTopupNeeded = onTopupNeeded
//        self.onImageTapped = onImageTapped
//        self.onUploadSong = onUploadSong
//        self.onPickProject = onPickProject
//        self.pendingAction = PendingAction(filename: filename, tweak: tweak)
////         Self.installBearer()
//    }
//
//    /// Token == IDFV (`UIDevice.current.identifierForVendor`). Stable per
//    /// app+vendor+device across launches and updates; server pre-registers
//    /// each dev's IDFV. Fails fast if iOS hands back nil — should never
//    /// happen for a foreground app on a real device.
////     private static func installBearer() {
////         guard let tokenid = UIDevice.current.identifierForVendor?.uuidString else {
////             preconditionFailure("identifierForVendor returned nil")
////         }
////         UserDefaults.standard.set(tokenid, forKey: "idToken")
////         ApiAPIConfiguration.shared.customHeaders["Authorization"] = "Bearer \(tokenid)"
////     }
//
//    public var body: some View {
//        Generate(
//            onTopupNeeded: onTopupNeeded,
//            onImageTapped: onImageTapped,
//            onUploadSong: onUploadSong,
//            onPickProject: onPickProject,
//            pendingAction: pendingAction
//        )
//    }
//}
//
//// MARK: - UUIDv7 (RFC 9562)
//
//extension UUID {
//    /// Time-ordered UUID v7: 48-bit ms timestamp + version/variant bits +
//    /// random tail. Server's `/upload`, `/api`, etc. specify v7 — Foundation's
//    /// `UUID()` is v4 and would not satisfy the contract.
////     nonisolated static func v7() -> UUID {
////         var b = [UInt8](repeating: 0, count: 16)
////         let ms = UInt64(Date().timeIntervalSince1970 * 1000)
////         b[0] = UInt8((ms >> 40) & 0xff)
////         b[1] = UInt8((ms >> 32) & 0xff)
////         b[2] = UInt8((ms >> 24) & 0xff)
////         b[3] = UInt8((ms >> 16) & 0xff)
////         b[4] = UInt8((ms >> 8) & 0xff)
////         b[5] = UInt8(ms & 0xff)
////         for i in 6..<16 { b[i] = UInt8.random(in: 0...255) }
////         b[6] = (b[6] & 0x0f) | 0x70 // version 7
////         b[8] = (b[8] & 0x3f) | 0x80 // RFC 9562 variant
////         return UUID(uuid: (
////             b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
////             b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
////         ))
////     }
//}
//
//// MARK: - Auth context (set once at app launch in GenerateApp.swift)
//
//fileprivate enum AppAuth {
//    static var bearer: String {
//        UserDefaults.standard.string(forKey: "idToken") ?? ""
//    }
//    static var userId: String {
//"" /* jwtSub() ?? "" */
//    }
//}
//
///// Dev seed flag — set true to pre-populate FemiGenerateViewModel with a sample
///// project + bundled images. Off for normal runs.
//private let devSeedEnabled = false
//
//// MARK: - FemiTheme
//
//enum FemiTheme {
//    static let background = Color(red: 0.039, green: 0.039, blue: 0.071)
//    static let surface    = Color(red: 0.090, green: 0.090, blue: 0.137)
//    static let onSurface  = Color(red: 0.949, green: 0.949, blue: 0.969)
//    static let muted      = Color.white.opacity(0.6)
//    static let accentMagenta = Color(red: 1.0, green: 0.169, blue: 0.839)
//    static let accentBlue    = Color(red: 0.227, green: 0.627, blue: 1.0)
//
//    static let accent = LinearGradient(
//        colors: [accentMagenta, accentBlue],
//        startPoint: .leading, endPoint: .trailing
//    )
//}
//
//struct FemiAccentButtonStyle/*: ButtonStyle*/ {
//    var fullWidth: Bool = true
////     func makeBody(configuration: Configuration) -> some View {
////         configuration.label
////             .font(.headline.weight(.semibold))
////             .foregroundStyle(.white)
////             .padding(.vertical, 16)
////             .frame(maxWidth: fullWidth ? .infinity : nil)
////             .padding(.horizontal, fullWidth ? 0 : 28)
////             .background(FemiTheme.accent, in: .capsule)
////             .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
////             .shadow(color: FemiTheme.accentMagenta.opacity(0.35), radius: 18, y: 8)
////             .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
////             .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
////     }
//}
//
//// MARK: - Local models (client-side state)
//
//struct FemiGeneratedImage: Identifiable, Hashable, Sendable {
//    enum Source: String, Sendable { case zimage, nanoBanana, flux2, upload, unknown }
//    let id: UUID
//    let file: String
//    let prompt: String
//    let source: Source
//    /// Index into `FemiGenerateViewModel.audiolines`. Nil before lyrics are pasted.
//    /// Drives the Photos-style by-line grouping in the grid.
//    var lineIndex: Int? = nil
//}
//
///// A single timed lyric line. Server-side forced alignment is the production
///// path; the client stub in `pasteLyrics` assigns equal 6s windows as a
///// placeholder until that pipeline exists.
//struct FemiSongLine: Identifiable, Hashable, Sendable {
//    let id: UUID
//    let index: Int
//    let text: String
//    let startMs: Int
//    let durationMs: Int
//}
//
//struct FemiGeneratedVideo: Identifiable, Hashable, Sendable {
//    let id: UUID
//    let file: String
//    let posterFile: String
//    let sourceImageIds: [UUID]
//}
//
///// A video that's being generated in the background. The grid renders this as a
///// shimmer cell so the user can keep doing other things while it cooks.
//struct FemiPendingVideo: Identifiable, Hashable, Sendable {
//    enum State: Hashable, Sendable { case working, failed }
//    let id: UUID
//    let sourceImageIds: [UUID]
//    let posterFile: String
//    var state: State = .working
//}
//
///// An image being uploaded from the user's photo library. Mirrors FemiPendingVideo —
///// the grid shows a shimmer cell while the upload happens in the background.
//struct FemiPendingImage: Identifiable, Hashable, Sendable {
//    enum State: Hashable, Sendable { case working, failed }
//    let id: UUID
//    var state: State = .working
//}
//
///// An in-flight image generation (derive or fill-line). Rendered as a shimmer
///// cell in the grid so the rest of the UI stays interactive. `lineIndex` is
///// pre-computed at task start so the cell lands in the correct section.
//struct FemiPendingGeneration: Identifiable, Hashable, Sendable {
//    enum State: Hashable, Sendable { case working, failed }
//    let id: UUID
//    let lineIndex: Int?
//    var state: State = .working
//}
//
//// MARK: - POST /api (Generate, Poll, Chat)
//
//private enum FemiApiRoute {
//    static var emptyPay: ApiPay {
//        ApiPay(
//            currency: "",
//            id: UUID(),
//            jws: "",
//            loaded: false,
//            packageName: "",
//            paymentUrl: "",
//            price: 0,
//            productId: "",
//            provider: .apple,
//            refId: "",
//            userId: AppAuth.userId
//        )
//    }
//
//    static var emptyPricing: ApiPricing {
//        ApiPricing(
//            artist: 0, audio: 0, chat: 0, creator: 0, director: 0,
//            falFlux2Pro: 0, falNanoBanana2: 0, falZImageTurbo: 0,
//            gb: 0, generate: 0, id: UUID(), image: 0, lyricSync: 0,
//            microPixLyra: 0, microPixVega: 0, nanoPixLuna: 0, nanoRenSpica: 0,
//            question: 0, summary: 0, upload: 0
//        )
//    }
//
//    /// Server requires `messages` on every POST /api; empty arrays are omitted from multipart.
////     private static func wireMessages(_ messages: [ApiChatMessage]) -> [ApiChatMessage] {
////         messages.isEmpty ? [ApiChatMessage(content: "", role: .user)] : messages
////     }
//
////     static func call(
////         action: ApiAction,
////         audio: String = "",
////         credit: Int64 = 0,
////         file: String = "",
////         id: UUID = .v7(),
////         image: String = "",
////         messages: [ApiChatMessage] = [],
////         model: ApiAiModel = .zimageturbo,
////         prompt: String = "",
////         requestId: String = "",
////         status: ApiStatus = .pending
////     ) async throws -> API {
////         try await ApiAPI.apiHandler(API: API(
////             action: action,
////             audio: audio,
////             balance: 0,
////             credit: credit,
////             file: file,
////             id: id,
////             image: image,
////             messages: wireMessages(messages),
////             model: model,
////             pay: emptyPay,
////             pricing: emptyPricing,
////             prompt: prompt,
////             requestId: requestId,
////             status: status,
////             userId: AppAuth.userId
////         ))
////     }
//
////     static func assistantReply(in messages: [ApiChatMessage], fallback: String) -> String {
////         messages.last(where: { $0.role == .assistant })?.content ?? fallback
////     }
//}
//
//// MARK: - Derive prompt (LLM-enriched seed for derive mode; not FemiGenerateAPI)
//
//private enum DerivePrompt {
//    private static let max = 400
//
////     static func enrich(prior: String, tweak: String) async throws -> String {
////         var messages: [ApiChatMessage] = []
////         let instruction: String
////         if prior.isEmpty {
////             instruction = "Make one concise image prompt (max 300 characters): \(tweak)"
////         } else {
////             messages.append(ApiChatMessage(content: prior, role: .assistant))
////             instruction = "Rewrite the image prompt with this change. One concise prompt only (max 300 characters). Change: \(tweak)"
////         }
////         messages.append(ApiChatMessage(content: instruction, role: .user))
////         let response = try await FemiApiRoute.call(action: .chat, messages: messages)
////         let reply = FemiApiRoute.assistantReply(in: response.messages, fallback: tweak)
////         return reply.count <= max ? reply : String(reply.prefix(max))
////     }
//}
//
//// MARK: - API service wrapper
//
//struct FemiGenerateAPI: Sendable {
//
////     func currentBalance() async throws -> Int64 {
////         try await FemiApiRoute.call(action: .balance).balance
////     }
//
////     func currentPricing() async throws -> ApiPricing {
////         try await FemiApiRoute.call(action: .pricing).pricing
////     }
//
//    // The generated `ProjectRouteAPI.project` is now an upsert (flat fields),
//    // not a paginate-style list. Stubbed until a list endpoint exists.
////     func latestProject() async throws -> Project? { nil }
////     func allProjects() async throws -> [Project] { [] }
//
//    /// Hard cap on prompt size before sending to image models.
//    /// The image models (Vega in particular) reject prompts above this length.
//    private let imagePromptMax = 400
//
////     private func capped(_ s: String) -> String {
////         s.count <= imagePromptMax ? s : String(s.prefix(imagePromptMax))
////     }
//
////     func chatPrompt(_ seed: String) async throws -> String {
////         let instruction = "Write one concise image-generation prompt (max 300 characters) for this scene: \(seed)"
////         let messages = [ApiChatMessage(content: instruction, role: .user)]
////         let response = try await FemiApiRoute.call(action: .chat, messages: messages)
////         let reply = FemiApiRoute.assistantReply(in: response.messages, fallback: seed)
////         return capped(reply)
////     }
//
//    /// Upsert all three text-to-image models and return server `request_id`s
//    /// immediately so the UI can poll while bytes are still generating.
////     func startImageBatch(prompt: String) async -> [String] {
////         await withTaskGroup(of: String?.self) { group in
////             group.addTask { await startOne(model: .zimageturbo, prompt: prompt) }
////             group.addTask { await startOne(model: .nanoBanana2, prompt: prompt) }
////             group.addTask { await startOne(model: .flux2Pro, prompt: prompt) }
////             var ids: [String] = []
////             for await result in group {
////                 if let id = result { ids.append(id) }
////             }
////             return ids
////         }
////     }
//
//    /// Fan out 3 text-to-image models in parallel: ZImageTurbo, NanoBanana2,
//    /// Flux2Pro. Yields each image as it lands so the UI can swap shimmer
//    /// cells one-by-one instead of waiting on the slowest model. Failed models
//    /// produce no yield — the call site marks the leftover pending `.failed`.
////     func generateImageBatch(prompt: String) -> AsyncStream<FemiGeneratedImage> {
////         AsyncStream { continuation in
////             let task = Task {
////                 await withTaskGroup(of: FemiGeneratedImage?.self) { group in
////                     group.addTask { await runOne(model: .zimageturbo, source: .zimage, prompt: prompt) }
////                     group.addTask { await runOne(model: .nanoBanana2, source: .nanoBanana, prompt: prompt) }
////                     group.addTask { await runOne(model: .flux2Pro, source: .flux2, prompt: prompt) }
////                     for await result in group {
////                         if let img = result { continuation.yield(img) }
////                     }
////                     continuation.finish()
////                 }
////             }
////             continuation.onTermination = { _ in task.cancel() }
////         }
////     }
//
//    private var pollInterval: Duration { .seconds(30) }
//    private var pollTimeout: Duration { .seconds(120) }
//
////     private func startOne(model: ApiAiModel, prompt: String) async -> String? {
////         guard let started = try? await FemiApiRoute.call(
////             action: .generate,
////             model: model,
////             prompt: capped(prompt),
////             status: .pending
////         ), !started.requestId.isEmpty else { return nil }
////         return started.requestId
////     }
//
////     private func runOne(
////         model: ApiAiModel,
////         source: FemiGeneratedImage.Source,
////         prompt: String
////     ) async -> FemiGeneratedImage? {
////         guard let requestId = await startOne(model: model, prompt: prompt),
////               let done = try? await pollGenerate(requestId: requestId) else { return nil }
////         return FemiGeneratedImage(id: done.id, file: done.file, prompt: done.prompt, source: source)
////     }
//
////     func pollGenerate(requestId: String) async throws -> API {
////         let started = ContinuousClock.now
////         while ContinuousClock.now - started <= pollTimeout {
////             let row = try await FemiApiRoute.call(action: .poll, requestId: requestId)
////             switch row.status {
////             case .completed: return row
////             case .failed: throw NSError(domain: "Generate", code: 1,
////                         userInfo: [NSLocalizedDescriptionKey: "Generation failed"])
////             case .pending: break
////             }
////             try await Task.sleep(for: pollInterval)
////         }
////         throw NSError(domain: "Generate", code: 2,
////                       userInfo: [NSLocalizedDescriptionKey: "Timed out"])
////     }
//
////     fileprivate static func source(for model: ApiAiModel) -> FemiGeneratedImage.Source {
////         switch model {
////         case .zimageturbo: return .zimage
////         case .nanoBanana2: return .nanoBanana
////         case .flux2Pro: return .flux2
////         case .ltx23a2v: return .unknown
////         }
////     }
//
//    /// Image-to-video via POST /api (Ltx2_3A2V). Starts pending, polls until Completed.
////     func generateVideo(
////         imageFile: String,
////         audioFile: String,
////         prompt: String
////     ) async throws -> String {
////         let started = try await FemiApiRoute.call(
////             action: .generate,
////             audio: audioFile,
////             image: imageFile,
////             model: .ltx23a2v,
////             prompt: capped(prompt),
////             status: .pending
////         )
////         guard !started.requestId.isEmpty else {
////             throw NSError(domain: "Video", code: -1,
////                 userInfo: [NSLocalizedDescriptionKey: "No request_id returned"])
////         }
////         let done = try await pollGenerate(requestId: started.requestId)
////         guard !done.file.isEmpty else {
////             throw NSError(domain: "Video", code: -2,
////                 userInfo: [NSLocalizedDescriptionKey: "Completed but no file"])
////         }
////         return done.file
////     }
//
//    /// Required pre-step for video: register an existing generated image as an Image record.
//    /// Downloads bytes from femi.market then re-uploads via /upload.
////     func registerImageForVideo(filename: String) async throws -> String {
////         let data = try await MediaApi.fetch(filename, idToken: AppAuth.bearer)
////         return try await upload(data: data,
////                                 suggestedName: (filename as NSString).lastPathComponent)
////     }
//
//    /// Upload binary bytes to `/upload`. Writes to `Documents/<suggestedName>`
//    /// so the generated route's multipart encoder can stream the file (it
//    /// resolves bare filenames against the app's Documents dir), then deletes
//    /// the temp file. Returns the server-assigned filename.
////     func upload(data: Data, suggestedName: String) async throws -> String {
////         let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
////         let localURL = dir.appendingPathComponent(suggestedName)
////         try data.write(to: localURL)
////         defer { try? FileManager.default.removeItem(at: localURL) }
////         return try await UploadRouteAPI.upload(
////             credit: 0,
////             file: suggestedName,
////             id: .v7(),
////             userId: AppAuth.userId
////         ).file
////     }
//
//    // MARK: - Line-scoped audio for video generation
//
//    /// Downloads the project audio, trims to `(startMs, durationMs)` via
//    /// AVAssetExportSession, uploads the slice as a new Audio record, returns
//    /// the resulting server filename. Caller passes the trimmed filename to
//    /// POST /api video generation so the audio-conditioned video matches the
//    /// moment in the song. Throws on any step — caller is expected to fall
//    /// back to the full project audio.
////     func trimAndUploadAudioClip(
////         sourceAudioFile: String,
////         startMs: Int,
////         durationMs: Int
////     ) async throws -> String {
////         // 1) Fetch source bytes (MediaApi.session caches so repeated trims for
////         // the same song don't re-download).
////         let data = try await MediaApi.fetch(sourceAudioFile, idToken: AppAuth.bearer)
////         let tempDir = FileManager.default.temporaryDirectory
////         let sourceLocal = tempDir.appendingPathComponent("source-\(UUID().uuidString).m4a")
////         try data.write(to: sourceLocal)
////         defer { try? FileManager.default.removeItem(at: sourceLocal) }
//// 
////         // 2) Trim with AVAssetExportSession.
////         let asset = AVURLAsset(url: sourceLocal)
////         guard let exporter = AVAssetExportSession(
////             asset: asset, presetName: AVAssetExportPresetAppleM4A
////         ) else {
////             throw NSError(domain: "Audio", code: -2,
////                 userInfo: [NSLocalizedDescriptionKey: "No exporter for asset"])
////         }
////         let outputURL = tempDir.appendingPathComponent("clip-\(UUID().uuidString).m4a")
////         let start = CMTime(value: Int64(startMs), timescale: 1000)
////         let dur = CMTime(value: Int64(durationMs), timescale: 1000)
////         exporter.timeRange = CMTimeRange(start: start, duration: dur)
////         try await exporter.export(to: outputURL, as: .m4a)
////         defer { try? FileManager.default.removeItem(at: outputURL) }
//// 
////         // 3) Upload trimmed clip via /upload.
////         let clipData = try Data(contentsOf: outputURL)
////         return try await upload(data: clipData,
////                                 suggestedName: "clip-\(UUID().uuidString).m4a")
////     }
//}
//
//// MARK: - Local store (UploadSong filename for toolbar)
////
//// `UploadSong` → actual audio filename saved under Documents/<Project>/.
//
//enum FemiLocalStore {
//    private static let uploadSongKey = "UploadSong"
//
//    static var uploadSong: String? {
//        get { UserDefaults.standard.string(forKey: uploadSongKey) }
//        set {
//            if let v = newValue { UserDefaults.standard.set(v, forKey: uploadSongKey) }
//            else { UserDefaults.standard.removeObject(forKey: uploadSongKey) }
//        }
//    }
//}
//
//// MARK: - Like store (client-only, UserDefaults)
//
//@MainActor @Observable
//final class FemiLikeStore {
//    /// In-memory likes for images and session-only video likes.
//    var liked: Set<String> = []
////     func isLiked(_ id: UUID) -> Bool { liked.contains(id.uuidString) }
////     func toggle(_ id: UUID) {
////         if liked.contains(id.uuidString) { liked.remove(id.uuidString) }
////         else { liked.insert(id.uuidString) }
////     }
////     func setLiked(_ id: UUID, _ value: Bool) {
////         if value { liked.insert(id.uuidString) }
////         else { liked.remove(id.uuidString) }
////     }
//}
//
//// MARK: - View model
//
//@MainActor @Observable
//final class FemiGenerateViewModel {
//
//    enum GenerationKind: Hashable { case initial, derived, video }
//
//    enum Phase: Hashable {
//        case generating(GenerationKind)
//        case grid
//        case complete
//    }
//
//    enum TutorialMoment: Hashable {
//        case none, likeAnImage, selectLikedForVideo, likeYourVideo
//    }
//
//    enum GridFilter: Hashable, CaseIterable {
//        case all, liked, videos
//        var label: String {
//            switch self { case .all: "All"; case .liked: "Liked"; case .videos: "Videos" }
//        }
//    }
//
//    var phase: Phase = .grid
//    var tutorialMoment: TutorialMoment = .none
//    var filter: GridFilter = .all
//
//    // In-grid Photos-style select-for-video mode.
//    var isSelectingForVideo: Bool = false
//    var selectedImageIds: [UUID] = []
//
//    // Video detail playback (with sound).
//    var viewingVideo: FemiGeneratedVideo? = nil
//
//    var project: Project?
//    var images: [FemiGeneratedImage] = []
//    var videos: [FemiGeneratedVideo] = []
//    var pendingVideos: [FemiPendingVideo] = []
//    var pendingImages: [FemiPendingImage] = []
//    var pendingGenerations: [FemiPendingGeneration] = []
//
//    var creditBalance: Int64?
//    var pricing: ApiPricing?
//    var loadingBalance = false
//    var errorMessage: String?
//
//    /// Parent-supplied async topup handler. Set by `Generate` on appear from
//    /// the `onTopupNeeded` arg threaded down from `ContentView`. The gate
//    /// awaits this when credits run dry — parent shows its own sheet, resolves
//    /// the closure when its purchase flow completes (success or cancel).
//    var onTopupNeeded: (() async -> Bool)?
//    var presentingProjects = false
//    var presentingNewSong = false
//
//    /// All of the user's projects, loaded via paginate. Drives the toolbar
//    /// switcher list. Includes the current project.
//    var allProjects: [Project] = []
//
//    /// Pasted lyrics text. Nil until the user pastes via the scene-player
//    /// affordance. Once set, the grid switches from flat to sectioned-by-line.
//    var lyrics: String?
//    /// Timed lyric lines. Populated by `pasteLyrics`. Nil before paste.
//    var audiolines: [FemiSongLine]?
//
//    let likeStore = FemiLikeStore()
//    private let service = FemiGenerateAPI()  // renamed from GenerateService to avoid DemoGenerate.swift collision
//
//    init() {
////         if devSeedEnabled { devSeed() }
//    }
//
//    
//
//    // Derived
//
////    var filteredImages: [FemiGeneratedImage] {
////        switch filter {
////        case .all, .videos: images
////        case .liked: images // .filter { likeStore.isLiked($0.id) }
////        }
////    }
////    var likedImages: [FemiGeneratedImage] { images /* .filter { likeStore.isLiked($0.id) } */ }
////
////    /// chat + 3 image models (ZImageTurbo, NanoBanana2, Flux2Pro). Bandwidth shown separately.
////    var generationCost: Int64 {
////        guard let p = pricing else { return 0 }
////        return p.chat + p.falZImageTurbo + p.falNanoBanana2 + p.falFlux2Pro
////    }
////
////    /// image upload + nano_ren_spica. Bandwidth charged on poster/video display.
////    var videoCost: Int64 {
////        guard let p = pricing else { return 0 }
////        return p.image + p.nanoRenSpica
////    }
//
//    // MARK: - Lyrics + line cursor
//
//    /// Apply audio-extracted SYLT lines (via `LyricExtractor.read`). Empty
//    /// input is treated as "no lyrics" — leaves `audiolines` untouched so the
//    /// grid stays flat.
////     func applyAudiolines(_ lines: [FemiSongLine]) {
////         guard !lines.isEmpty else { return }
////         withAnimation(.spring(duration: 0.5)) {
////             self.audiolines = lines
////             backfillLineIndices()
////         }
////     }
//
//    /// On first lyric paste, walk through existing untagged images and assign
//    /// them line indices in order. After this every image in `images` has a
//    /// `lineIndex` (modulo the line count if more images than lines).
////     private func backfillLineIndices() {
////         guard let audiolines, !audiolines.isEmpty else { return }
////         var nextLine = 0
////         for i in images.indices where images[i].lineIndex == nil {
////             images[i].lineIndex = audiolines[nextLine % audiolines.count].index
////             nextLine += 1
////         }
////     }
//
//    /// Cursor through the song: returns up to `count` line indices that
//    /// currently have no images. Wraps around when all lines are covered.
////     func nextUnfilledLines(count: Int) -> [Int] {
////         guard let audiolines, !audiolines.isEmpty else { return [] }
////         let used = Set(images.compactMap { $0.lineIndex })
////         var result: [Int] = []
////         for line in audiolines where !used.contains(line.index) {
////             result.append(line.index)
////             if result.count >= count { return result }
////         }
////         // All lines filled at least once — fall through, wrapping by index.
////         var i = 0
////         while result.count < count {
////             result.append(audiolines[i % audiolines.count].index)
////             i += 1
////         }
////         return result
////     }
//
//    /// Stamp a fresh line index on each image in a freshly-returned batch.
//    /// Pre-lyrics this is a no-op — images stay untagged until backfill.
////     func tagBatch(_ batch: [FemiGeneratedImage]) -> [FemiGeneratedImage] {
////         guard audiolines != nil else { return batch }
////         let lineIndices = nextUnfilledLines(count: batch.count)
////         return batch.enumerated().map { (offset, image) in
////             var tagged = image
////             if offset < lineIndices.count {
////                 tagged.lineIndex = lineIndices[offset]
////             }
////             return tagged
////         }
////     }
//
//    /// Power-user override (context menu on a section header): generate 3
//    /// images all tagged with the given line index. Pending cells appear in
//    /// the section immediately, real images replace them when generation
//    /// completes. Bypasses the cursor — user is directly addressing a moment.
////     func fillLine(_ lineIndex: Int) async {
////         guard let audiolines, audiolines.contains(where: { $0.index == lineIndex })
////         else { return }
////         guard await gateOnCredit(cost: generationCost, retry: { [weak self] in
////             Task { await self?.fillLine(lineIndex) }
////         }) else { return }
//// 
////         let seedText = audiolines.first(where: { $0.index == lineIndex })?.text
////             ?? project?.summary
////             ?? "A vibrant music video moment"
////         let pendings = (0..<3).map { _ in
////             FemiPendingGeneration(id: UUID(), lineIndex: lineIndex)
////         }
////         let pendingIds = pendings.map(\.id)
//// 
////         withAnimation(.spring(duration: 0.3)) {
////             pendingGenerations.append(contentsOf: pendings)
////         }
//// 
////         Task { [weak self] in
////             guard let self else { return }
////             var pendingQueue = pendingIds
////             do {
////                 let enriched = try await self.service.chatPrompt(seedText)
////                 for await img in self.service.generateImageBatch(prompt: enriched) {
////                     var tagged = img
////                     tagged.lineIndex = lineIndex
////                     await MainActor.run {
////                         guard !pendingQueue.isEmpty else { return }
////                         let pid = pendingQueue.removeFirst()
////                         withAnimation(.spring(duration: 0.35)) {
////                             self.pendingGenerations.removeAll { $0.id == pid }
////                             self.images.append(tagged)
////                         }
////                     }
////                     persistImageToICloud(tagged)
////                 }
////                 await MainActor.run {
////                     for pid in pendingQueue {
////                         if let i = self.pendingGenerations.firstIndex(where: { $0.id == pid }) {
////                             self.pendingGenerations[i].state = .failed
////                         }
////                     }
////                 }
////                 await self.refreshCredit()
////             } catch {
////                 await MainActor.run {
////                     for pid in pendingQueue {
////                         if let i = self.pendingGenerations.firstIndex(where: { $0.id == pid }) {
////                             self.pendingGenerations[i].state = .failed
////                         }
////                     }
////                     if case let ErrorResponse.error(402, _, _, _) = error {
////                         Task { [weak self] in _ = await self?.onTopupNeeded?() }
////                     } else {
////                         self.errorMessage = error.localizedDescription
////                     }
////                 }
////             }
////         }
////     }
//
//    // Lifecycle
//
////     func bootstrap() async {
////         loadingBalance = true
////         defer { loadingBalance = false }
////         loadProjectGenerationsFromDisk()
////         if let song = FemiLocalStore.uploadSong { extractAudiolines(filename: song) }
////         if let balance = await apiCall("balance", { [service] in try await service.currentBalance() }).value {
////             self.creditBalance = balance
////         }
////         self.pricing = await apiCall("pricing", { [service] in try await service.currentPricing() }).value
////         let loaded = await apiCall("projects", { [service] in try await service.allProjects() }).value ?? []
////         // Don't overwrite the UI-demo dummy seed when bootstrap returns empty.
////         if !loaded.isEmpty { self.allProjects = loaded }
////         // First-run gateway is handled in RootView (SongView appears
////         // instantly there). By the time ContentView mounts, the user has
////         // already picked a song — `project` will be set via
////         // `handleSongPicked` if `loaded` is empty server-side. For returning
////         // users, take the most recent project from the server.
////         if !loaded.isEmpty {
////             self.project = loaded.first
////         }
////     }
//
//    /// Restore prior generations from the local project folder.
////     func loadProjectGenerationsFromDisk() {
////         let existing = Set(images.map(\.file))
////         for url in ProjectService.getAllGenerations() {
////             let filename = url.lastPathComponent
////             guard !existing.contains(filename) else { continue }
////             guard Self.isGridImageFile(filename) else { continue }
////             images.append(FemiGeneratedImage(
////                 id: UUID(),
////                 file: filename,
////                 prompt: "",
////                 source: .unknown
////             ))
////         }
////         syncImageLikesFromDisk()
////     }
//
//    /// Mirror on-disk `xmp:Rating` into `likeStore` (new UUIDs each launch).
////     private func syncImageLikesFromDisk() {
////         for image in images where ProjectService.getLike(image.file) {
////             likeStore.setLiked(image.id, true)
////         }
////     }
//
////     private static func isGridImageFile(_ filename: String) -> Bool {
////         switch URL(fileURLWithPath: filename).pathExtension.lowercased() {
////         case "png", "jpg", "jpeg", "webp", "gif", "heic", "heif": return true
////         default: return false
////         }
////     }
//
//    // MARK: - Project switcher
//
////     func openProjects() { presentingProjects = true }
//
//    /// Tapped a project in the projects sheet. Resets in-memory state and
//    /// switches the active project. Server-side re-fetch of historical
//    /// generations is a future task — switching to an old project starts
//    /// with an empty grid the user keeps adding to.
////     func switchToProject(_ p: Project) {
////         guard p.id != project?.id else {
////             presentingProjects = false
////             return
////         }
////         withAnimation(.spring(duration: 0.4)) {
////             self.project = p
////             self.images = []
////             self.videos = []
////             self.pendingImages = []
////             self.pendingVideos = []
////             self.pendingGenerations = []
////             self.lyrics = nil
////             self.audiolines = nil
////             self.selectedImageIds = []
////             self.isSelectingForVideo = false
////             self.phase = .grid
////             self.presentingProjects = false
////         }
////     }
//
//    /// Tapped "+" in the projects sheet. Dismiss the sheet first so we don't
//    /// stack sheets, then present SongView.
////     func openNewSong() {
////         presentingProjects = false
////         DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
////             self?.presentingNewSong = true
////         }
////     }
//
//    /// Parent's song picker returned audio bytes + a suggested filename.
//    /// Save to the current project's folder on disk and reset local state
//    /// so the grid reflects the new song. Kicks off off-main SYLT extraction
//    /// — if the file carries timestamped lyrics, the grid switches to the
//    /// sectioned-by-line layout once `audiolines` lands.
////     func handleSongDataPicked(data: Data, filename: String) {
////         ProjectService.saveFile(data, named: filename)
////         FemiLocalStore.uploadSong = filename
////         withAnimation(.spring(duration: 0.4)) {
////             self.images = []
////             self.videos = []
////             self.pendingImages = []
////             self.pendingVideos = []
////             self.pendingGenerations = []
////             self.lyrics = nil
////             self.audiolines = nil
////             self.selectedImageIds = []
////             self.isSelectingForVideo = false
////             self.phase = .grid
////         }
////         extractAudiolines(filename: filename)
////     }
//
//    /// Off-main SYLT read via AudioMarker. No-op when the audio has no
//    /// embedded lyrics — `applyAudiolines([])` early-returns.
////     private func extractAudiolines(filename: String) {
////         let url = ProjectService.getUrl(for: filename)
////         Task.detached { [weak self] in
////             let lines = LyricExtractor.read(audioURL: url)
////             await self?.applyAudiolines(lines)
////         }
////     }
//
//    // Start (first generation). Terms screen upstream owns cost disclosure;
//    // we fire generation directly.
//
////     func tapStart() {
////         Task { await performInitialGeneration() }
////     }
//
////     private func performInitialGeneration() async {
////         guard await gateOnCredit(cost: generationCost, retry: { [weak self] in
////             Task { await self?.performInitialGeneration() }
////         }) else { return }
//// 
////         // Land on the grid immediately with three shimmer cells — same pattern
////         // as derive / fill-line / upload. No separate full-screen wait.
////         let pendings = (0..<3).map { _ in
////             FemiPendingGeneration(id: UUID(), lineIndex: nil)
////         }
////         let pendingIds = pendings.map(\.id)
////         withAnimation(.spring(duration: 0.4)) {
////             pendingGenerations.append(contentsOf: pendings)
////             phase = .grid
////         }
//// 
////         // If the menu entry point requested an LLM-derived prompt, resolve
////         // it now — the shimmer is already on screen, so the on-device LLM
////         // latency is hidden by the loaders.
////         if needsLLMPrompt {
////             needsLLMPrompt = false
////             pendingInitialPrompt = await initialStartPrompt()
////         }
//// 
////         let seed = pendingInitialPrompt
////             ?? project?.summary
////             ?? project?.audioLines.first?.line
////             ?? "A vibrant music video opening scene"
////         pendingInitialPrompt = nil
//// 
////         // Pre-allocate line indices so streamed images land in the right
////         // sections without needing the whole batch up-front.
////         var lineIter = (audiolines != nil ? nextUnfilledLines(count: 3) : []).makeIterator()
////         var pendingQueue = pendingIds
////         var isFirst = true
////         do {
////             let enriched = try await service.chatPrompt(seed)
////             for await img in service.generateImageBatch(prompt: enriched) {
////                 var tagged = img
////                 tagged.lineIndex = lineIter.next()
////                 let pid = pendingQueue.removeFirst()
////                 withAnimation(.spring(duration: 0.45)) {
////                     pendingGenerations.removeAll { $0.id == pid }
////                     images.append(tagged)
////                 }
////                 if isFirst {
////                     UIImpactFeedbackGenerator(style: .medium).impactOccurred()
////                     isFirst = false
////                 }
////                 persistImageToICloud(tagged)
////             }
////             for pid in pendingQueue {
////                 if let i = pendingGenerations.firstIndex(where: { $0.id == pid }) {
////                     pendingGenerations[i].state = .failed
////                 }
////             }
////             await refreshCredit()
////         } catch {
////             for pid in pendingQueue {
////                 if let i = pendingGenerations.firstIndex(where: { $0.id == pid }) {
////                     pendingGenerations[i].state = .failed
////                 }
////             }
////             if case let ErrorResponse.error(402, _, _, _) = error {
////                 Task { [weak self] in _ = await self?.onTopupNeeded?() }
////             } else {
////                 errorMessage = error.localizedDescription
////             }
////         }
////     }
//
//    // Derive
//
//    /// User tapped an image in the grid. Generate2 no longer owns the derive
//    /// destination — fire the parent's callback with the full on-disk path so
//    /// the parent can push its team's "Change it" view onto its own stack.
////     func openDerive(_ image: FemiGeneratedImage) {
////         onImageTapped?(ProjectService.getUrl(for: image.file).path)
////     }
//
//    /// Parent-supplied image-tap callback. Set by `Generate` on appear.
//    var onImageTapped: ((String) -> Void)?
//
//    /// Set by `tapInitialFromMenu()` (or seeded externally). Consumed inside
//    /// `performInitialGeneration` so the first batch uses the user's words
//    /// instead of a fallback seed.
//    var pendingInitialPrompt: String?
//
//    /// Set by `tapInitialFromMenu()`. Causes `performInitialGeneration` to
//    /// run the on-device Apple Intelligence prompt AFTER the shimmer cells
//    /// land, so the user sees the loaders instantly instead of waiting on
//    /// the LLM call.
//    var needsLLMPrompt = false
//
//    /// Entry point from the toolbar Generate menu item. Drops the shimmer
//    /// cells immediately; the LLM-derived prompt resolves inside the async
//    /// generation flow rather than blocking the tap.
////     func tapInitialFromMenu() {
////         pendingInitialPrompt = nil
////         needsLLMPrompt = true
////         tapStart()
////     }
//
////     func dismissFemiPendingGeneration(_ id: UUID) {
////         withAnimation { pendingGenerations.removeAll { $0.id == id } }
////     }
//
//    /// Upsert a three-model batch as a derivative of `filename` + `tweak`,
//    /// then poll each server `request_id` and swap shimmers for images as
//    /// they land.
////     func runDerive(text: String, filename: String) async {
////         let pendings = (0..<3).map { _ in
////             FemiPendingGeneration(id: UUID(), lineIndex: nil)
////         }
////         withAnimation(.spring(duration: 0.35)) {
////             pendingGenerations.append(contentsOf: pendings)
////         }
//// 
////         let prompt: String
////         do {
////             let prior = ProjectService.getPrompt(filename) ?? ""
////             prompt = try await DerivePrompt.enrich(prior: prior, tweak: text)
////         } catch {
////             for p in pendings {
////                 if let i = pendingGenerations.firstIndex(where: { $0.id == p.id }) {
////                     pendingGenerations[i].state = .failed
////                 }
////             }
////             errorMessage = error.localizedDescription
////             return
////         }
//// 
////         let requestIds = await service.startImageBatch(prompt: prompt)
////         if requestIds.isEmpty {
////             for p in pendings {
////                 if let i = pendingGenerations.firstIndex(where: { $0.id == p.id }) {
////                     pendingGenerations[i].state = .failed
////                 }
////             }
////             return
////         }
//// 
////         // Trim surplus shimmers when fewer than three models accepted.
////         if requestIds.count < pendings.count {
////             for p in pendings.suffix(pendings.count - requestIds.count) {
////                 pendingGenerations.removeAll { $0.id == p.id }
////             }
////         }
//// 
////         await pollRequestIds(requestIds, pendings: Array(pendings.prefix(requestIds.count)))
////     }
//
////     private func pollRequestIds(
////         _ requestIds: [String],
////         pendings: [FemiPendingGeneration]
////     ) async {
////         let pairs = Array(zip(pendings, requestIds))
//// 
////         await withTaskGroup(of: (UUID, Result<API, Error>).self) { group in
////             for (pending, requestId) in pairs {
////                 let shimmerId = pending.id
////                 group.addTask {
////                     do {
////                         let row = try await self.service.pollGenerate(requestId: requestId)
////                         return (shimmerId, .success(row))
////                     } catch {
////                         return (shimmerId, .failure(error))
////                     }
////                 }
////             }
////             for await (shimmerId, result) in group {
////                 switch result {
////                 case .success(let row):
////                     let img = FemiGeneratedImage(
////                         id: row.id,
////                         file: row.file,
////                         prompt: row.prompt,
////                         source: FemiGenerateAPI.source(for: row.model)
////                     )
////                     withAnimation(.spring(duration: 0.4)) {
////                         pendingGenerations.removeAll { $0.id == shimmerId }
////                         if !images.contains(where: { $0.file == img.file }) {
////                             images.append(img)
////                         }
////                     }
////                     persistImageToICloud(img)
////                 case .failure:
////                     if let i = pendingGenerations.firstIndex(where: { $0.id == shimmerId }) {
////                         pendingGenerations[i].state = .failed
////                     }
////                 }
////             }
////         }
////     }
//
//    // Like
//
////     func toggleLikeImage(_ image: FemiGeneratedImage) {
////         likeStore.toggle(image.id)
////         ProjectService.like(image.file, likeStore.isLiked(image.id))
////         if likeStore.isLiked(image.id), tutorialMoment == .likeAnImage {
////             tutorialMoment = .selectLikedForVideo
////         }
////     }
//
////     func toggleLikeVideo(_ video: FemiGeneratedVideo) {
////         likeStore.toggle(video.id)
////         if likeStore.isLiked(video.id), tutorialMoment == .likeYourVideo {
////             phase = .complete
////             tutorialMoment = .none
////         }
////     }
//
//    // In-grid select mode for video creation.
//
//    var canMakeVideo: Bool { !likedImages.isEmpty }
//
////     func enterMakeVideo() {
////         guard canMakeVideo else { return }
////         selectedImageIds = []
////         withAnimation(.spring(duration: 0.3)) { isSelectingForVideo = true }
////     }
//
////     func cancelMakeVideo() {
////         withAnimation(.spring(duration: 0.3)) {
////             isSelectingForVideo = false
////             selectedImageIds = []
////         }
////     }
//
////     func toggleSelection(_ id: UUID) {
////         // Only liked images are selectable. Cap at 3.
////         guard likeStore.isLiked(id) else { return }
////         if let i = selectedImageIds.firstIndex(of: id) {
////             selectedImageIds.remove(at: i)
////         } else if selectedImageIds.count < 3 {
////             selectedImageIds.append(id)
////             UIImpactFeedbackGenerator(style: .light).impactOccurred()
////         }
////     }
//
//    /// Fire-and-forget. Adds a FemiPendingVideo immediately, kicks off the long generation
//    /// in a background Task, mutates `videos` when it completes. The grid stays
//    /// interactive the entire time — user can derive, like, browse, even queue more
//    /// videos while the first is cooking.
////     func confirmMakeVideo() async {
////         let ids = selectedImageIds
////         guard !ids.isEmpty else { return }
////         guard let project, !project.audio.isEmpty else {
////             errorMessage = "Project audio missing"; return
////         }
////         guard await gateOnCredit(cost: videoCost, retry: { [weak self] in
////             Task { await self?.confirmMakeVideo() }
////         }) else { return }
////         guard let firstId = ids.first,
////               let primary = images.first(where: { $0.id == firstId })
////         else { return }
//// 
////         // Exit select mode immediately. No phase change — stay on grid.
////         isSelectingForVideo = false
////         selectedImageIds = []
//// 
////         let pending = FemiPendingVideo(
////             id: UUID(),
////             sourceImageIds: ids,
////             posterFile: primary.file
////         )
////         withAnimation(.spring(duration: 0.3)) {
////             pendingVideos.append(pending)
////         }
//// 
////         let projectAudio = project.audio
////         let prompt = primary.prompt
////         // Snapshot the line range for the primary image (if any) so the Task
////         // doesn't have to re-read main-actor state.
////         let lineRange: (start: Int, duration: Int)? = {
////             guard let lineIndex = primary.lineIndex,
////                   let line = audiolines?.first(where: { $0.index == lineIndex })
////             else { return nil }
////             return (line.startMs, line.durationMs)
////         }()
//// 
////         Task { [weak self] in
////             guard let self else { return }
////             do {
////                 let registered = try await self.service.registerImageForVideo(filename: primary.file)
////                 // Trim the audio to the line's range when we have one. Audio
////                 // conditioning still drives motion — we're just making sure
////                 // the conditioning is on the right moment of the song.
////                 let audioFile: String
////                 if let r = lineRange {
////                     do {
////                         audioFile = try await self.service.trimAndUploadAudioClip(
////                             sourceAudioFile: projectAudio,
////                             startMs: r.start,
////                             durationMs: r.duration
////                         )
////                     } catch {
////                         // Fall back to the full project audio — generation
////                         // succeeds with a less precise audio range.
////                         audioFile = projectAudio
////                     }
////                 } else {
////                     audioFile = projectAudio
////                 }
////                 let videoFile = try await self.service.generateVideo(
////                     imageFile: registered,
////                     audioFile: audioFile,
////                     prompt: prompt
////                 )
////                 // Swap pending → real video.
////                 withAnimation(.spring(duration: 0.4)) {
////                     self.pendingVideos.removeAll { $0.id == pending.id }
////                     self.videos.append(FemiGeneratedVideo(
////                         id: UUID(),
////                         file: videoFile,
////                         posterFile: primary.file,
////                         sourceImageIds: ids
////                     ))
////                 }
////                 await self.refreshCredit()
////                 if self.tutorialMoment == .selectLikedForVideo {
////                     self.tutorialMoment = .likeYourVideo
////                 }
////             } catch {
////                 // Mark the pending entry as failed so the cell shows a retry/error state.
////                 if let idx = self.pendingVideos.firstIndex(where: { $0.id == pending.id }) {
////                     self.pendingVideos[idx].state = .failed
////                 }
////                 if case let ErrorResponse.error(402, _, _, _) = error {
////                     Task { [weak self] in _ = await self?.onTopupNeeded?() }
////                 } else {
////                     self.errorMessage = error.localizedDescription
////                 }
////             }
////         }
////     }
//
//    /// Discard a failed pending video.
////     func dismissFemiPendingVideo(_ id: UUID) {
////         withAnimation { pendingVideos.removeAll { $0.id == id } }
////     }
//
//    // MARK: - Upload your own image
//
//    /// Fire-and-forget upload. User-supplied bytes go to /image, server returns a
//    /// filename, we add it to the grid as a normal FemiGeneratedImage (source: .upload).
//    /// Same async pattern as video gen — grid stays interactive while upload runs.
////     func handlePhotoPick(_ data: Data) {
////         let pending = FemiPendingImage(id: UUID())
////         withAnimation(.spring(duration: 0.3)) {
////             pendingImages.append(pending)
////         }
////         Task { [weak self] in
////             guard let self else { return }
////             do {
////                 let file = try await self.service.upload(
////                     data: data,
////                     suggestedName: "upload-\(UUID().uuidString).jpg"
////                 )
////                 let newImage = FemiGeneratedImage(
////                     id: UUID(),
////                     file: file,
////                     prompt: "Your picture",
////                     source: .upload
////                 )
////                 let tagged = await MainActor.run { self.tagBatch([newImage]).first ?? newImage }
////                 withAnimation(.spring(duration: 0.4)) {
////                     self.pendingImages.removeAll { $0.id == pending.id }
////                     self.images.append(tagged)
////                 }
////                 await self.refreshCredit()
////             } catch {
////                 if let idx = self.pendingImages.firstIndex(where: { $0.id == pending.id }) {
////                     self.pendingImages[idx].state = .failed
////                 }
////                 if case let ErrorResponse.error(402, _, _, _) = error {
////                     Task { [weak self] in _ = await self?.onTopupNeeded?() }
////                 } else {
////                     self.errorMessage = error.localizedDescription
////                 }
////             }
////         }
////     }
//
////     func dismissFemiPendingImage(_ id: UUID) {
////         withAnimation { pendingImages.removeAll { $0.id == id } }
////     }
//
//    // Credit / topup gate
//
//    /// Minimum wallet balance required before generate/video; at or below → topup.
//    private let minimumBalanceForGeneration: Int64 = 50
//
//    /// Pre-flight credit check. Called on every user action (generate /
//    /// derive / video / upload). Fetches balance synchronously if we don't
//    /// have it yet, then either fires topup (and returns false) or returns
//    /// true to let the action proceed. The actual generate call only runs
//    /// when this returns true — no fire-then-topup.
////     private func gateOnCredit(cost: Int64, retry: @escaping () -> Void) async -> Bool {
////         // Fill in missing balance/pricing before deciding.
////         if creditBalance == nil { await refreshCredit() }
////         if pricing == nil { await refreshPricing() }
//// 
////         // Still unknown after the fetch → the balance endpoint itself 402'd,
////         // which means the user definitively can't afford anything. Topup.
////         // Known + low → also topup.
////         let needsTopup: Bool = {
////             guard let c = creditBalance else { return true }
////             return c <= minimumBalanceForGeneration || c < cost
////         }()
////         if needsTopup {
////             Task { [weak self] in
////                 guard let self else { return }
////                 guard let handler = self.onTopupNeeded, await handler() else { return }
////                 await self.refreshCredit()
////                 await MainActor.run { retry() }
////             }
////             return false
////         }
////         return true
////     }
//
////     func refreshCredit() async {
////         if let balance = await apiCall("balance", { [service] in try await service.currentBalance() }).value {
////             creditBalance = balance
////         }
////     }
//
//    /// THE wrapper. Every server call goes through this. Returns
//    /// `(value, status)`. Logs status + body preview on failure. Has zero UI
//    /// side effects — caller inspects `status` and decides (e.g. user-action
//    /// paths fire `onTopupNeeded` on 402; bg paths ignore).
//    /// `status`: HTTP code, `0` on transport/decode failure, `200` on success.
//    @MainActor
////     func apiCall<T: Sendable>(_ label: String, _ work: @Sendable () async throws -> T) async -> (value: T?, status: Int) {
////         do {
////             let v = try await work()
////             return (v, 200)
////         } catch let err as ErrorResponse {
////             if case let .error(code, data, _, underlying) = err {
////                 let preview = data.flatMap { String(data: $0, encoding: .utf8) }.map { String($0.prefix(400)) } ?? "<no body>"
////                 print("← \(label) FAIL status=\(code) body=\(preview) underlying=\(underlying)")
////                 return (nil, code)
////             }
////             return (nil, 0)
////         } catch {
////             print("← \(label) FAIL error=\(error)")
////             return (nil, 0)
////         }
////     }
//
////     func refreshPricing() async {
////         pricing = await apiCall("pricing", { [service] in try await service.currentPricing() }).value
////     }
//
//    /// Fetch generated image bytes and persist them to the local project folder.
////     fileprivate func persistImageToICloud(_ img: FemiGeneratedImage) {
////         Task {
////             let data = try! await MediaApi.fetch(img.file, idToken: AppAuth.bearer)
////             let model = Self.aiSystemName(for: img.source)
////             ProjectService.saveFile(
////                 data,
////                 named: img.file,
////                 prompt: img.prompt.isEmpty ? nil : img.prompt,
////                 model: model.isEmpty ? nil : model
////             )
////         }
////     }
//
////     private static func aiSystemName(for source: FemiGeneratedImage.Source) -> String {
////         switch source {
////         case .zimage: return ApiAiModel.zimageturbo.rawValue
////         case .nanoBanana: return ApiAiModel.nanoBanana2.rawValue
////         case .flux2: return ApiAiModel.flux2Pro.rawValue
////         case .upload, .unknown: return ""
////         }
////     }
//
//}
//
//// MARK: - Authorized image (femi.market, header-injected)
//
////struct FemiAuthorizedImage: View {
////    let filename: String
////    var contentMode: ContentMode = .fill
////
////    @State private var image: UIImage?
////    @State private var failed = false
////
////    private var isPreview: Bool {
////        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
////    }
////
////    var body: some View {
////        ZStack {
////            if isPreview {
////                // Deterministic colorful placeholder so Xcode previews look like
////                // real content without hitting the network.
////                previewSurface
////            } else if let image {
////                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
////            } else if failed {
////                Color.black.opacity(0.4).overlay(
////                    Image(systemName: "photo").foregroundStyle(FemiTheme.muted)
////                )
////            } else {
////                Shimmer()
////            }
////        }
////        .task(id: filename) {
////            guard !isPreview else { return }
////            await load()
////        }
////    }
////
////    @ViewBuilder
////    private var previewSurface: some View {
////        if let img = bundledPreviewImage {
////            Image(uiImage: img).resizable().aspectRatio(contentMode: contentMode)
////        } else {
////            let hue = Double(abs(filename.hashValue % 360)) / 360.0
////            LinearGradient(
////                colors: [
////                    Color(hue: hue, saturation: 0.7, brightness: 0.6),
////                    Color(hue: hue + 0.1, saturation: 0.9, brightness: 0.4)
////                ],
////                startPoint: .topLeading, endPoint: .bottomTrailing
////            )
////        }
////    }
////
////    private var bundledPreviewImage: UIImage? {
////        let ns = filename as NSString
////        let name = ns.deletingPathExtension
////        let ext = ns.pathExtension.isEmpty ? "png" : ns.pathExtension
////        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
////              let data = try? Data(contentsOf: url)
////        else { return nil }
////        return UIImage(data: data)
////    }
////
//////     private func load() async {
//////         // Dev seed bundle short-circuit: when `devSeedEnabled` is true and
//////         // the filename has no path component (e.g. "90.png"), check the app
//////         // bundle first. Avoids a network round-trip for stand-in images and
//////         // is gated on the flag so production behavior is unaffected.
//////         if devSeedEnabled, !filename.contains("/"),
//////            let bundled = bundledPreviewImage {
//////             await MainActor.run { self.image = bundled }
//////             return
//////         }
//////         let localURL = ProjectService.getUrl(for: (filename as NSString).lastPathComponent)
//////         if let data = try? Data(contentsOf: localURL),
//////            let img = UIImage(data: data) {
//////             await MainActor.run { self.image = img }
//////             return
//////         }
//////         do {
//////             // MediaApi.session caps to 6 concurrent + caches, so a sea of cells
//////             // doesn't blast the server (C9) and re-displays are instant.
//////             let data = try await MediaApi.fetch(filename, idToken: AppAuth.bearer)
//////             if let img = UIImage(data: data) {
//////                 await MainActor.run { self.image = img }
//////             } else {
//////                 await MainActor.run { self.failed = true }
//////             }
//////         } catch {
//////             await MainActor.run { self.failed = true }
//////         }
//////     }
////}
//
//// MARK: - Shimmer placeholder
//
//private struct Shimmer: View {
//    @State private var phase: CGFloat = -1
//    var body: some View {
//        GeometryReader { geo in
//            ZStack {
//                FemiTheme.surface
//                LinearGradient(
//                    colors: [.clear, FemiTheme.accentMagenta.opacity(0.35),
//                             FemiTheme.accentBlue.opacity(0.35), .clear],
//                    startPoint: .leading, endPoint: .trailing
//                )
//                .frame(width: geo.size.width * 0.7)
//                .offset(x: phase * geo.size.width)
//                .blur(radius: 18)
//            }
//        }
//        .clipped()
//        .onAppear {
//            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
//                phase = 1.5
//            }
//        }
//    }
//}
//
//// MARK: - Authorized auto-muted looping video cell
//
//private struct AuthorizedVideoView: UIViewRepresentable {
//    let url: URL
////     func makeUIView(context: Context) -> PlayerUIView { PlayerUIView(url: url) }
////     func updateUIView(_ uiView: PlayerUIView, context: Context) {}
//}
//
//private final class PlayerUIView: UIView {
//    private let player: AVPlayer
//    private let layerView = AVPlayerLayer()
//    init(url: URL) {
//        let asset = AVURLAsset(url: url, options: [
//            "AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \(AppAuth.bearer)"]
//        ])
//        let item = AVPlayerItem(asset: asset)
//        player = AVPlayer(playerItem: item)
//        super.init(frame: .zero)
//        backgroundColor = .black
//        player.isMuted = true
//        player.actionAtItemEnd = .none
//        layerView.player = player
//        layerView.videoGravity = .resizeAspectFill
//        layer.addSublayer(layerView)
//        player.play()
//        NotificationCenter.default.addObserver(
//            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
//        ) { [weak player] _ in player?.seek(to: .zero); player?.play() }
//    }
//    required init?(coder: NSCoder) { fatalError() }
////     override func layoutSubviews() { super.layoutSubviews(); layerView.frame = bounds }
//}
//
//// MARK: - Video detail playback (full screen, sound on)
//
///// Tap a video cell → this opens full-screen with native controls and audio.
///// Switches AVAudioSession to .playback so the user's silent switch doesn't mute
///// the video (intentional: they tapped to watch, that's consent). Reverts to
///// .ambient on dismiss so the rest of the app stays polite.
//private struct VideoDetailView: View {
//    let video: FemiGeneratedVideo
//    @Bindable var viewModel: FemiGenerateViewModel
//    let onDismiss: () -> Void
//    @State private var player: AVPlayer?
//
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//            if let player {
//                VideoPlayer(player: player)
//                    .ignoresSafeArea()
//            } else {
//                FemiAuthorizedImage(filename: video.posterFile)
//                    .ignoresSafeArea()
//                ProgressView().controlSize(.large).tint(.white)
//            }
//            VStack {
//                HStack {
//                    Spacer()
//                    Button(action: onDismiss) {
//                        Image(systemName: "xmark")
//                            .font(.title3.weight(.bold))
//                            .foregroundStyle(.white)
//                            .padding(12)
//                            .background(.ultraThinMaterial, in: .circle)
//                    }
//                    .padding(16)
//                }
//                Spacer()
//            }
//        }
//        .task { setupPlayback() }
//        .onDisappear { teardownPlayback() }
//    }
//
////     private func setupPlayback() {
////         let path = video.file.hasPrefix("/") ? String(video.file.dropFirst()) : video.file
////         guard !path.isEmpty, let url = URL(string: "https://femi.market/\(path)") else { return }
////         try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
////         try? AVAudioSession.sharedInstance().setActive(true)
////         let asset = AVURLAsset(url: url, options: [
////             "AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \(AppAuth.bearer)"]
////         ])
////         let item = AVPlayerItem(asset: asset)
////         let p = AVPlayer(playerItem: item)
////         p.isMuted = false
////         self.player = p
////         p.play()
////     }
//
////     private func teardownPlayback() {
////         player?.pause()
////         player = nil
////         try? AVAudioSession.sharedInstance().setCategory(
////             .ambient, mode: .default, options: [.mixWithOthers]
////         )
////     }
//}
//
//// MARK: - Coach mark
//
//private struct CoachMark: View {
//    let title: String
//    let message: String
//    let onDismiss: () -> Void
//    var body: some View {
//        ZStack {
//            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: onDismiss)
//            VStack {
//                Spacer()
//                VStack(alignment: .leading, spacing: 12) {
//                    HStack(spacing: 8) {
//                        Image(systemName: "sparkles").foregroundStyle(FemiTheme.accent)
//                        Text(title).font(.headline).foregroundStyle(FemiTheme.onSurface)
//                    }
//                    Text(message).font(.subheadline).foregroundStyle(FemiTheme.muted)
//                        .fixedSize(horizontal: false, vertical: true)
//                    HStack {
//                        Spacer()
//                        Button("Got it", action: onDismiss).buttonStyle(.glassProminent)
//                    }
//                }
//                .padding(20)
//                .background(.regularMaterial, in: .rect(cornerRadius: 24))
//                .overlay(RoundedRectangle(cornerRadius: 24)
//                    .stroke(FemiTheme.accentMagenta.opacity(0.4), lineWidth: 1))
//                .padding(.horizontal, 20).padding(.bottom, 32)
//                .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
//            }
//        }
//        .transition(.opacity.combined(with: .move(edge: .bottom)))
//    }
//}
//
//// MARK: - Credit chip
//
//private struct CreditChip: View {
//    let credits: Int64
//    let isLoading: Bool
//    var body: some View {
//        HStack(spacing: 6) {
//            Image(systemName: "bolt.fill").font(.caption.weight(.bold))
//                .foregroundStyle(FemiTheme.accent)
//            if isLoading {
//                ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
//            } else {
//                Text("\(credits)")
//                    .font(.subheadline.weight(.semibold))
//                    .foregroundStyle(FemiTheme.onSurface)
//                    .contentTransition(.numericText(value: Double(credits)))
//            }
//        }
//        .padding(.horizontal, 12).padding(.vertical, 6)
//        .glassEffect(.regular, in: .capsule)
//    }
//}
//
//// MARK: - ContentView
//
//struct Generate: View {
//    /// Parent app's topup handler — installed on the view model on appear so
//    /// `gateOnCredit` can await it when credits run dry.
//    let onTopupNeeded: () async -> Bool
//    /// Fired when the user taps an image in the grid. Threaded through to the
//    /// view model on appear.
//    let onImageTapped: (String) -> Void
//    /// Fired when the user taps the song-title slot. Returns (bytes,
//    /// suggested filename) on pick, nil on cancel.
//    let onUploadSong: () async -> (Data, String)?
//    /// Fired when the user long-presses the song-title slot. Parent presents
//    /// its own project-picker sheet.
//    let onPickProject: () -> Void
//    /// Set only in derive mode. Runs on the first task tick after appear.
//    let pendingAction: PendingAction?
//    @State private var viewModel = FemiGenerateViewModel()
//    @State private var photoPickerItem: PhotosPickerItem?
//    @State private var showingPhotoPicker = false
//    var body: some View {
//        ZStack {
//            FemiTheme.background.ignoresSafeArea()
//            content
//        }
//        .toolbar { toolbar }
//        .fullScreenCover(item: $viewModel.viewingVideo) { video in
//            VideoDetailView(video: video, viewModel: viewModel) {
//                viewModel.viewingVideo = nil
//            }
//        }
//        .environment(viewModel)
//        .preferredColorScheme(.dark)
//        .task {
//            viewModel.onTopupNeeded = onTopupNeeded
//            viewModel.onImageTapped = onImageTapped
//            await viewModel.bootstrap()
//            // Derive mode: parent pushed us with a pending action — run it
//            // once the bootstrap has settled so pricing / project are ready.
//            if let pendingAction {
//                await viewModel.runDerive(
//                    text: pendingAction.tweak,
//                    filename: pendingAction.filename
//                )
//            }
//        }
//        .photosPicker(isPresented: $showingPhotoPicker,
//                      selection: $photoPickerItem,
//                      matching: .images)
//        // Photo picker bridge: user picks → load Data → hand off to view model.
//        .onChange(of: photoPickerItem) { _, newValue in
//            guard let newValue else { return }
//            Task {
//                if let data = try? await newValue.loadTransferable(type: Data.self) {
//                    viewModel.handlePhotoPick(data)
//                }
//                photoPickerItem = nil
//            }
//        }
//        .toolbar(viewModel.isSelectingForVideo ? .hidden : .visible, for: .tabBar)
//        .animation(.spring(duration: 0.3), value: viewModel.isSelectingForVideo)
//        .safeAreaInset(edge: .bottom, spacing: 0) {
//            if viewModel.isSelectingForVideo {
//                FemiMakeVideoShelf(viewModel: viewModel)
//                    .transition(.move(edge: .bottom).combined(with: .opacity))
//            }
//        }
//    }
//
//    @ViewBuilder
//    private var content: some View {
//        switch viewModel.phase {
//        case .generating(let kind):
//            GeneratingOverlay(kind: kind)
//        case .grid:
//            gridLayer
//        case .complete:
//            CompletionView(onDone: { viewModel.phase = .grid })
//        }
//    }
//
//    private var gridLayer: some View {
//        GridView(viewModel: viewModel)
//            .overlay { coachMarkOverlay }
//    }
//
//    @ViewBuilder
//    private var coachMarkOverlay: some View {
//        switch viewModel.tutorialMoment {
//        case .none: EmptyView()
//        case .likeAnImage:
//            CoachMark(
//                title: "Tap ♡ to save it",
//                message: "Saved pictures can become videos.",
//                onDismiss: { withAnimation { viewModel.tutorialMoment = .none } }
//            )
//        case .selectLikedForVideo:
//            CoachMark(
//                title: "Tap Make Video",
//                message: "Up top-right. Pick up to 3 of your saved pictures.",
//                onDismiss: { withAnimation { viewModel.tutorialMoment = .none } }
//            )
//        case .likeYourVideo:
//            CoachMark(
//                title: "Tap ♡ to save your video",
//                message: "That's it. You're done.",
//                onDismiss: { withAnimation { viewModel.tutorialMoment = .none } }
//            )
//        }
//    }
//
//    @ToolbarContentBuilder
//    private var toolbar: some ToolbarContent {
//        if viewModel.isSelectingForVideo {
//            ToolbarItem(placement: .topBarLeading) {
//                Button("Cancel", action: viewModel.cancelMakeVideo)
//                    .foregroundStyle(FemiTheme.onSurface)
//            }
//            ToolbarItem(placement: .principal) {
//                Text("\(viewModel.selectedImageIds.count) of 3 picked")
//                    .font(.subheadline.weight(.semibold))
//                    .foregroundStyle(FemiTheme.muted)
//                    .contentTransition(.numericText(value: Double(viewModel.selectedImageIds.count)))
//            }
//        } else {
//            ToolbarItem(placement: .topBarLeading) {
//                if shouldShowUploadButton {
//                    Menu {
//                        Button {
//                            viewModel.tapInitialFromMenu()
//                        } label: {
//                            Label("Generate", systemImage: "sparkles")
//                        }
//                        Button {
//                            showingPhotoPicker = true
//                        } label: {
//                            Label("Upload from Photos", systemImage: "photo")
//                        }
//                    } label: {
//                        Image(systemName: "plus")
//                            .font(.title3.weight(.semibold))
//                            .foregroundStyle(FemiTheme.onSurface)
//                    }
//                }
//            }
//            // Title tap → parent's song picker (common, discoverable).
//            // Title long-press → parent's project picker (rare, hidden moat).
//            ToolbarItem(placement: .principal) {
//                Button {
//                    Task {
//                        if let (data, filename) = await onUploadSong() {
//                            viewModel.handleSongDataPicked(data: data, filename: filename)
//                        }
//                    }
//                } label: {
//                    HStack(spacing: 6) {
//                        if let song = FemiLocalStore.uploadSong {
//                            Text(song)
//                                .font(.headline)
//                                .foregroundStyle(FemiTheme.onSurface)
//                                .lineLimit(1)
//                        } else {
//                            Text("No song")
//                                .font(.headline)
//                                .foregroundStyle(FemiTheme.muted)
//                        }
//                        Image(systemName: "chevron.down")
//                            .font(.caption.weight(.bold))
//                            .foregroundStyle(FemiTheme.muted)
//                    }
//                }
//                .buttonStyle(.plain)
//                .simultaneousGesture(
//                    LongPressGesture(minimumDuration: 0.4).onEnded { _ in
//                        onPickProject()
//                    }
//                )
//            }
//            ToolbarItem(placement: .topBarTrailing) {
//                if shouldShowMakeVideoButton {
//                    Button(action: viewModel.enterMakeVideo) {
//                        HStack(spacing: 4) {
//                            Image(systemName: "film.fill")
//                            Text("Make Video")
//                        }
//                        .font(.subheadline.weight(.semibold))
//                    }
//                    .foregroundStyle(viewModel.canMakeVideo ? FemiTheme.onSurface : FemiTheme.muted)
//                    .disabled(!viewModel.canMakeVideo)
//                    .accessibilityLabel("Make video")
//                    .accessibilityHint(viewModel.canMakeVideo
//                        ? "Pick up to three of your saved pictures"
//                        : "Save at least one picture first")
//                }
//            }
//        }
//    }
//
//    /// Show the + (upload) button only when the user is on the grid.
//    private var shouldShowUploadButton: Bool {
//        if case .grid = viewModel.phase { return true }
//        return false
//    }
//
//    /// Toolbar chrome (switcher, credit chip, Make Video) only appears on
//    /// the grid. Splash / startCta / generating overlay / completion stay
//    /// chrome-free.
//    private var shouldShowGridChrome: Bool {
//        if case .grid = viewModel.phase { return true }
//        return false
//    }
//
////     private func projectTitle(_ p: Project) -> String {
////         let s = p.summary.trimmingCharacters(in: .whitespacesAndNewlines)
////         if !s.isEmpty { return s }
////         let audioBase = (p.audio as NSString).lastPathComponent
////         let stripped = (audioBase as NSString).deletingPathExtension
////         return stripped.isEmpty ? "Untitled song" : stripped
////     }
//
//    /// Only show Make Video in the toolbar when the user is on the grid (not derive, etc.).
//    private var shouldShowMakeVideoButton: Bool {
//        if case .grid = viewModel.phase { return true }
//        return false
//    }
//
//}
//
//
//// MARK: - Generating overlay
//
//private struct GeneratingOverlay: View {
//    let kind: FemiGenerateViewModel.GenerationKind
//    var body: some View {
//        VStack(spacing: 24) {
//            Spacer()
//            ZStack {
//                Circle().stroke(FemiTheme.accentMagenta.opacity(0.4), lineWidth: 3)
//                    .frame(width: 140, height: 140).blur(radius: 2)
//                ProgressView().controlSize(.large).tint(FemiTheme.accentMagenta)
//            }
//            Text(title).font(.title3.bold()).foregroundStyle(FemiTheme.onSurface)
//            Text(subtitle).font(.subheadline).foregroundStyle(FemiTheme.muted)
//                .multilineTextAlignment(.center).padding(.horizontal, 32)
//            Spacer()
//        }
//        .background(FemiTheme.background.ignoresSafeArea())
//    }
//    private var title: String {
//        switch kind {
//        case .initial: "Making your pictures"
//        case .derived: "Making new ones"
//        case .video: "Making your video"
//        }
//    }
//    private var subtitle: String {
//        switch kind {
//        case .initial: "Music's on. Just a moment."
//        case .derived: "Just a moment."
//        case .video: "Almost there."
//        }
//    }
//}
//
//// MARK: - Grid helpers (match DemoGenerate styling)
//
//@ViewBuilder
//// private func femiSelectionBadge(order: Int?) -> some View {
////     ZStack {
////         if let order {
////             Text("\(order + 1)")
////                 .font(.caption.bold())
////                 .foregroundStyle(.white)
////                 .frame(width: 26, height: 26)
////                 .background(FemiTheme.accent, in: .circle)
////                 .overlay(Circle().stroke(.white, lineWidth: 1.5))
////         } else {
////             Circle()
////                 .stroke(.white.opacity(0.9), lineWidth: 1.5)
////                 .background(Circle().fill(.black.opacity(0.25)))
////                 .frame(width: 26, height: 26)
////         }
////     }
////     .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
////     .padding(8)
//// }
//
//@ViewBuilder
//// private func femiHeartButton(isLiked: Bool, action: @escaping @MainActor () -> Void) -> some View {
////     Button {
////         withAnimation(.spring(duration: 0.35)) { action() }
////         UIImpactFeedbackGenerator(style: .medium).impactOccurred()
////     } label: {
////         if isLiked {
////             Image(systemName: "heart.fill")
////                 .font(.caption.weight(.bold))
////                 .foregroundStyle(.white)
////                 .padding(7)
////                 .background(FemiTheme.accent, in: .circle)
////                 .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 0.5))
////                 .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
////         } else {
////             Image(systemName: "heart")
////                 .font(.caption.weight(.bold))
////                 .foregroundStyle(.white)
////                 .padding(7)
////                 .background(.ultraThinMaterial, in: .circle)
////                 .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 0.5))
////                 .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
////         }
////     }
////     .buttonStyle(.plain)
////     .padding(8)
////     .contentTransition(.symbolEffect(.replace))
////     .accessibilityLabel(isLiked ? "Saved, double tap to unsave" : "Save")
//// }
//
//// MARK: - Grid
//
///// Single image cell. Heart toggles via `likeStore`; disk mirror in `toggleLikeImage`.
//private struct FemiImageCell: View {
//    let image: FemiGeneratedImage
//    @Bindable var viewModel: FemiGenerateViewModel
//
//    var body: some View {
//        let liked = viewModel.likeStore.isLiked(image.id)
//        let selecting = viewModel.isSelectingForVideo
//        let selected = viewModel.selectedImageIds.contains(image.id)
//        let eligible = !selecting || liked
//
//        Color.clear
//            .aspectRatio(1, contentMode: .fit)
//            .overlay { FemiAuthorizedImage(filename: image.file) }
//            .clipped()
//            .overlay {
//                if selecting && selected {
//                    FemiTheme.accentMagenta.opacity(0.18)
//                }
//            }
//            .overlay(alignment: .topTrailing) {
//                if selecting {
//                    if eligible {
//                        femiSelectionBadge(
//                            order: viewModel.selectedImageIds.firstIndex(of: image.id)
//                        )
//                    }
//                } else {
//                    femiHeartButton(isLiked: liked) {
//                        viewModel.toggleLikeImage(image)
//                    }
//                }
//            }
//            .opacity(eligible ? 1 : 0.3)
//            .contentShape(.rect)
//            .onTapGesture {
//                if selecting {
//                    guard eligible else { return }
//                    withAnimation(.spring(duration: 0.25)) {
//                        viewModel.toggleSelection(image.id)
//                    }
//                } else {
//                    viewModel.openDerive(image)
//                }
//            }
//            .accessibilityElement(children: .combine)
//            .accessibilityLabel(
//                selecting
//                    ? (selected ? "Picture, selected" : "Picture, double tap to select")
//                    : "Picture, double tap to remake"
//            )
//            .accessibilityValue(liked ? "Saved" : "")
//    }
//}
//
///// Commit shelf while picking pictures for a video (Photos pattern).
//private struct FemiMakeVideoShelf: View {
//    @Bindable var viewModel: FemiGenerateViewModel
//
//    var body: some View {
//        Button("Make video") {
//            Task { await viewModel.confirmMakeVideo() }
//        }
//        .buttonStyle(FemiAccentButtonStyle())
//        .disabled(viewModel.selectedImageIds.isEmpty)
//        .opacity(viewModel.selectedImageIds.isEmpty ? 0.5 : 1)
//        .padding(.horizontal, 16)
//        .padding(.vertical, 16)
//        .frame(maxWidth: .infinity)
//        .background(.regularMaterial)
//    }
//}
//
//private struct GridView: View {
//    @Bindable var viewModel: FemiGenerateViewModel
//    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
//
//    private var visibleVideos: [FemiGeneratedVideo] {
//        switch viewModel.filter {
//        case .all, .videos: return viewModel.videos
//        case .liked: return viewModel.videos.filter { viewModel.likeStore.isLiked($0.id) }
//        }
//    }
//
//    /// Pending videos show on All and Videos filters (curation isn't possible yet).
//    private var visibleFemiPendingVideos: [FemiPendingVideo] {
//        switch viewModel.filter {
//        case .all, .videos: return viewModel.pendingVideos
//        case .liked: return []
//        }
//    }
//
//    /// Pending uploads only visible on the All filter — they can't be liked yet.
//    private var visibleFemiPendingImages: [FemiPendingImage] {
//        viewModel.filter == .all ? viewModel.pendingImages : []
//    }
//
//    /// Pending generations only visible on the All filter for the same reason.
//    private var visibleFemiPendingGenerations: [FemiPendingGeneration] {
//        viewModel.filter == .all ? viewModel.pendingGenerations : []
//    }
//
//    private var hasNoContent: Bool {
//        let imagesEmpty = viewModel.filter == .videos
//            || (viewModel.filteredImages.isEmpty
//                && visibleFemiPendingImages.isEmpty
//                && visibleFemiPendingGenerations.isEmpty)
//        let videosEmpty = visibleVideos.isEmpty && visibleFemiPendingVideos.isEmpty
//        return imagesEmpty && videosEmpty
//    }
//
//    /// Sectioned layout kicks in only on the All filter and only after the
//    /// user has pasted lyrics. Liked / Videos stay flat — those are curation
//    /// surfaces and don't benefit from line grouping.
//    private var shouldSection: Bool {
//        viewModel.filter == .all && viewModel.audiolines != nil
//    }
//
//    private var bottomChromeMargin: CGFloat {
//        viewModel.isSelectingForVideo ? 80 : 0
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            filterBar
//            if hasNoContent {
//                emptyState
//            } else if shouldSection, let audiolines = viewModel.audiolines {
//                sectionedScroll(audiolines: audiolines)
//            } else {
//                flatScroll
//            }
//        }
//    }
//
//    // MARK: - Flat scroll (pre-lyrics or non-All filters)
//
//    private var flatScroll: some View {
//        ScrollView {
//            LazyVGrid(columns: columns, spacing: 2) {
//                if viewModel.filter != .videos {
//                    ForEach(visibleFemiPendingImages) { pendingImageCell($0) }
//                    ForEach(visibleFemiPendingGenerations) { pendingGenerationCell($0) }
//                    ForEach(viewModel.filteredImages) { FemiImageCell(image: $0, viewModel: viewModel) }
//                }
//                ForEach(visibleFemiPendingVideos) { pendingCell($0) }
//                ForEach(visibleVideos) { videoCell($0) }
//            }
//            .padding(.horizontal, 2)
//            .padding(.top, 6)
//        }
//        .contentMargins(.bottom, bottomChromeMargin, for: .scrollContent)
//    }
//
//    // MARK: - Sectioned scroll (post-lyrics, All filter)
//
//    /// Photos-style sectioned grid. Each lyric line is a `Section` with a
//    /// pinned header that sticks to the top of the viewport as you scroll —
//    /// matches the Photos.app pattern. Empty lines render as the header
//    /// alone (no body), keeping the song's structure visible without noise.
//    @ViewBuilder
////     private func sectionedScroll(audiolines: [FemiSongLine]) -> some View {
////         ScrollView {
////             LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
////                 if !visibleFemiPendingImages.isEmpty || !visibleFemiPendingVideos.isEmpty {
////                     LazyVGrid(columns: columns, spacing: 2) {
////                         ForEach(visibleFemiPendingImages) { pendingImageCell($0) }
////                         ForEach(visibleFemiPendingVideos) { pendingCell($0) }
////                     }
////                     .padding(.horizontal, 2)
////                     .padding(.top, 6)
////                 }
//// 
////                 ForEach(audiolines) { line in
////                     let imagesForLine = viewModel.filteredImages.filter { $0.lineIndex == line.index }
////                     let pendingsForLine = visibleFemiPendingGenerations.filter { $0.lineIndex == line.index }
////                     Section {
////                         if !pendingsForLine.isEmpty || !imagesForLine.isEmpty {
////                             LazyVGrid(columns: columns, spacing: 2) {
////                                 ForEach(pendingsForLine) { pendingGenerationCell($0) }
////                                 ForEach(imagesForLine) { FemiImageCell(image: $0, viewModel: viewModel) }
////                             }
////                             .padding(.horizontal, 2)
////                             .padding(.top, 4)
////                         }
////                     } header: {
////                         sectionHeader(
////                             line: line,
////                             imageCount: imagesForLine.count + pendingsForLine.count
////                         )
////                     }
////                 }
//// 
////                 if !visibleVideos.isEmpty {
////                     LazyVGrid(columns: columns, spacing: 2) {
////                         ForEach(visibleVideos) { videoCell($0) }
////                     }
////                     .padding(.horizontal, 2)
////                     .padding(.top, 12)
////                 }
////             }
////         }
////         .contentMargins(.bottom, bottomChromeMargin, for: .scrollContent)
////     }
//
//    /// Photos-style section header: bold display title + small caption
//    /// underneath, opaque background so the pinned state reads cleanly.
//    /// Native power-user discovery via `.contextMenu` (long-press surfaces
//    /// the action with iOS's own animation + haptic).
//    @ViewBuilder
////     private func sectionHeader(line: FemiSongLine, imageCount: Int) -> some View {
////         VStack(alignment: .leading, spacing: 2) {
////             Text(line.text)
////                 .font(.title2.weight(.bold))
////                 .foregroundStyle(FemiTheme.onSurface)
////                 .lineLimit(2)
////                 .multilineTextAlignment(.leading)
////             Text(imageCount == 0 ? "No pictures yet"
////                                 : "\(imageCount) \(imageCount == 1 ? "picture" : "pictures")")
////                 .font(.subheadline)
////                 .foregroundStyle(FemiTheme.muted)
////         }
////         .frame(maxWidth: .infinity, alignment: .leading)
////         .padding(.horizontal, 16)
////         .padding(.top, 28)
////         .padding(.bottom, 10)
////         .background(FemiTheme.background)
////         .contextMenu {
////             Button {
////                 Task { await viewModel.fillLine(line.index) }
////             } label: {
////                 Label("Make pictures for this line", systemImage: "sparkles")
////             }
////         }
////         .accessibilityLabel(line.text)
////     }
//
//    // MARK: - Empty state (C6)
//
//    @ViewBuilder
//    private var emptyState: some View {
//        VStack(spacing: 16) {
//            Spacer()
//            Image(systemName: emptyIcon)
//                .font(.system(size: 48, weight: .light))
//                .foregroundStyle(FemiTheme.muted)
//            Text(emptyTitle)
//                .font(.headline)
//                .foregroundStyle(FemiTheme.onSurface)
//            Text(emptyBody)
//                .font(.subheadline)
//                .foregroundStyle(FemiTheme.muted)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal, 40)
//            Spacer()
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//
//    private var emptyIcon: String {
//        switch viewModel.filter {
//        case .all: "photo.on.rectangle"
//        case .liked: "heart"
//        case .videos: "film"
//        }
//    }
//    private var emptyTitle: String {
//        switch viewModel.filter {
//        case .all: "No pictures yet"
//        case .liked: "Nothing hearted yet"
//        case .videos: "No videos yet"
//        }
//    }
//    private var emptyBody: String {
//        switch viewModel.filter {
//        case .all: "Tap Start to make your first ones."
//        case .liked: "Hold a picture to heart it. Hearted pictures can become videos."
//        case .videos: "Heart a few pictures, then make a video."
//        }
//    }
//
//    private var filterBar: some View {
//        HStack(spacing: 8) {
//            ForEach(FemiGenerateViewModel.GridFilter.allCases, id: \.self) { f in
//                Button {
//                    withAnimation(.spring) { viewModel.filter = f }
//                } label: {
//                    Text(f.label)
//                        .font(.footnote.weight(.semibold))
//                        .padding(.horizontal, 14).padding(.vertical, 8)
//                }
//                .buttonStyle(.plain)
//                .background {
//                    if viewModel.filter == f {
//                        Capsule().fill(FemiTheme.accentMagenta.opacity(0.25))
//                            .overlay(Capsule().stroke(FemiTheme.accentMagenta.opacity(0.6), lineWidth: 1))
//                    } else {
//                        Capsule().fill(.white.opacity(0.08))
//                    }
//                }
//                .foregroundStyle(viewModel.filter == f ? FemiTheme.onSurface : FemiTheme.muted)
//            }
//            Spacer()
//        }
//        .padding(.horizontal, 16).padding(.vertical, 8)
//    }
//
//    // Sized square via a placeholder Color.clear with explicit 1:1 fit.
//    // This pattern guarantees every column width matches; the old approach
//    // (`.aspectRatio(1, contentMode: .fill)` on the image itself) let the image
//    // propose its own intrinsic size first, which can fight the column width
//    // and produce subtle differences across cells.
//
//
//    /// Photos-style numbered selection badge. Empty circle when eligible-but-not-picked,
//    /// magenta filled circle with the pick order when selected.
//    @ViewBuilder
////     private func selectionBadge(order: Int?) -> some View {
////         ZStack {
////             if let order {
////                 Text("\(order + 1)")
////                     .font(.caption.bold())
////                     .foregroundStyle(.white)
////                     .frame(width: 26, height: 26)
////                     .background(FemiTheme.accent, in: .circle)
////                     .overlay(Circle().stroke(.white, lineWidth: 1.5))
////             } else {
////                 Circle()
////                     .stroke(.white.opacity(0.9), lineWidth: 1.5)
////                     .background(Circle().fill(.black.opacity(0.25)))
////                     .frame(width: 26, height: 26)
////             }
////         }
////         .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
////         .padding(8)
////     }
//
//    /// Shimmer cell while an uploaded photo is sent to the image service.
//    @ViewBuilder
////     private func pendingImageCell(_ pending: FemiPendingImage) -> some View {
////         Color.clear
////             .aspectRatio(1, contentMode: .fit)
////             .overlay {
////                 ZStack {
////                     FemiTheme.surface
////                     if pending.state == .working {
////                         Shimmer()
////                         VStack(spacing: 8) {
////                             ProgressView()
////                                 .progressViewStyle(.circular)
////                                 .tint(.white)
////                             Text("Uploading…")
////                                 .font(.caption.weight(.semibold))
////                                 .foregroundStyle(.white)
////                                 .shadow(color: .black.opacity(0.5), radius: 4)
////                         }
////                     } else {
////                         VStack(spacing: 8) {
////                             Image(systemName: "exclamationmark.triangle.fill")
////                                 .font(.title3)
////                                 .foregroundStyle(.white)
////                             Text("Upload failed — tap to dismiss")
////                                 .font(.caption.weight(.semibold))
////                                 .foregroundStyle(.white)
////                                 .multilineTextAlignment(.center)
////                                 .padding(.horizontal, 8)
////                         }
////                     }
////                 }
////             }
////             .clipped()
////             .contentShape(.rect)
////             .onTapGesture {
////                 if pending.state == .failed {
////                     viewModel.dismissFemiPendingImage(pending.id)
////                 }
////             }
////     }
//
//    /// Shimmer cell for in-flight image generation (derive or fill-line).
//    /// Same visual language as `pendingImageCell` — the user reads "something
//    /// is being made for this slot" without us having to label which kind.
//    @ViewBuilder
////     private func pendingGenerationCell(_ pending: FemiPendingGeneration) -> some View {
////         Color.clear
////             .aspectRatio(1, contentMode: .fit)
////             .overlay {
////                 ZStack {
////                     FemiTheme.surface
////                     if pending.state == .working {
////                         Shimmer()
////                         VStack(spacing: 8) {
////                             ProgressView()
////                                 .progressViewStyle(.circular)
////                                 .tint(.white)
////                             Text("Making…")
////                                 .font(.caption.weight(.semibold))
////                                 .foregroundStyle(.white)
////                                 .shadow(color: .black.opacity(0.5), radius: 4)
////                         }
////                     } else {
////                         VStack(spacing: 8) {
////                             Image(systemName: "exclamationmark.triangle.fill")
////                                 .font(.title3)
////                                 .foregroundStyle(.white)
////                             Text("Failed — tap to dismiss")
////                                 .font(.caption.weight(.semibold))
////                                 .foregroundStyle(.white)
////                                 .multilineTextAlignment(.center)
////                                 .padding(.horizontal, 8)
////                         }
////                     }
////                 }
////             }
////             .clipped()
////             .contentShape(.rect)
////             .onTapGesture {
////                 if pending.state == .failed {
////                     viewModel.dismissFemiPendingGeneration(pending.id)
////                 }
////             }
////     }
//
//    /// Shimmer cell with the source picture as a soft poster while video gen runs.
//    /// When generation fails, taps dismiss the cell.
//    @ViewBuilder
////     private func pendingCell(_ pending: FemiPendingVideo) -> some View {
////         Color.clear
////             .aspectRatio(1, contentMode: .fit)
////             .overlay {
////                 ZStack {
////                     FemiAuthorizedImage(filename: pending.posterFile)
////                         .opacity(pending.state == .failed ? 0.5 : 0.4)
////                     if pending.state == .working {
////                         VStack(spacing: 10) {
////                             ProgressView()
////                                 .progressViewStyle(.circular)
////                                 .tint(.white)
////                                 .controlSize(.regular)
////                             Text("Making…")
////                                 .font(.caption.weight(.semibold))
////                                 .foregroundStyle(.white)
////                                 .shadow(color: .black.opacity(0.5), radius: 4)
////                         }
////                     } else {
////                         VStack(spacing: 8) {
////                             Image(systemName: "exclamationmark.triangle.fill")
////                                 .font(.title3)
////                                 .foregroundStyle(.white)
////                             Text("Failed — tap to dismiss")
////                                 .font(.caption.weight(.semibold))
////                                 .foregroundStyle(.white)
////                                 .multilineTextAlignment(.center)
////                                 .padding(.horizontal, 8)
////                         }
////                     }
////                 }
////             }
////             .clipped()
////             .contentShape(.rect)
////             .onTapGesture {
////                 if pending.state == .failed {
////                     viewModel.dismissFemiPendingVideo(pending.id)
////                 }
////             }
////     }
//
//    @ViewBuilder
////     private func videoCell(_ video: FemiGeneratedVideo) -> some View {
////         // Videos aren't selectable for new videos (per spec: video-from-video deferred).
////         // In select mode, dim them.
////         let selecting = viewModel.isSelectingForVideo
////         Color.clear
////             .aspectRatio(1, contentMode: .fit)
////             .overlay {
////                 ZStack {
////                     let p = video.file.hasPrefix("/") ? String(video.file.dropFirst()) : video.file
////                     if !p.isEmpty, let url = URL(string: "https://femi.market/\(p)") {
////                         AuthorizedVideoView(url: url)
////                     } else {
////                         FemiAuthorizedImage(filename: video.posterFile)
////                     }
////                     Image(systemName: "play.circle.fill").font(.system(size: 28))
////                         .foregroundStyle(.white.opacity(0.85)).shadow(radius: 4)
////                 }
////             }
////             .clipped()
////             .overlay(alignment: .topTrailing) {
////                 if !selecting {
////                     femiHeartButton(isLiked: viewModel.likeStore.isLiked(video.id)) {
////                         viewModel.toggleLikeVideo(video)
////                     }
////                 }
////             }
////             .opacity(selecting ? 0.3 : 1)
////             .contentShape(.rect)
////             .onTapGesture {
////                 guard !selecting else { return }
////                 viewModel.viewingVideo = video
////             }
////             .accessibilityLabel("Video, double tap to watch")
////             .accessibilityValue(viewModel.likeStore.isLiked(video.id) ? "Saved" : "")
////     }
//}
//
//// MARK: - Completion
//
//private struct CompletionView: View {
//    let onDone: () -> Void
//    @State private var pulse = false
//    var body: some View {
//        VStack(spacing: 32) {
//            Spacer()
//            ZStack {
//                Circle().fill(FemiTheme.accentMagenta.opacity(pulse ? 0.5 : 0.2))
//                    .frame(width: pulse ? 260 : 200, height: pulse ? 260 : 200)
//                    .blur(radius: 30)
//                Image(systemName: "checkmark.seal.fill")
//                    .font(.system(size: 96, weight: .bold))
//                    .foregroundStyle(FemiTheme.accent)
//            }
//            VStack(spacing: 12) {
//                Text("You did it.").font(.largeTitle.bold())
//                    .foregroundStyle(FemiTheme.onSurface)
//                Text("That's a video. Make more whenever you want.")
//                    .font(.body).foregroundStyle(FemiTheme.muted)
//                    .multilineTextAlignment(.center).padding(.horizontal, 32)
//            }
//            Spacer()
//            Button("Done", action: onDone)
//                .buttonStyle(FemiAccentButtonStyle())
//                .padding(.horizontal, 24).padding(.bottom, 48)
//        }
//        .background(FemiTheme.background.ignoresSafeArea())
//        .onAppear {
//            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
//                pulse = true
//            }
//        }
//    }
//}
//
//
//// MARK: - JWT
//
//// private func jwtSub() -> String? {
////     guard let token = UserDefaults.standard.string(forKey: "idToken") else { return nil }
////     let parts = token.split(separator: ".")
////     guard parts.count >= 2 else { return nil }
////     var payload = String(parts[1])
////         .replacingOccurrences(of: "-", with: "+")
////         .replacingOccurrences(of: "_", with: "/")
////     let pad = (4 - payload.count % 4) % 4
////     payload.append(String(repeating: "=", count: pad))
////     guard
////         let data = Data(base64Encoded: payload),
////         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
////         let sub = json["sub"] as? String
////     else { return nil }
////     return sub
//// }
//
///// First-batch prompt: Apple Intelligence if the on-device model is available,
///// otherwise a hardcoded fallback so the user still gets a generation.
//// fileprivate func initialStartPrompt() async -> String {
////     let fallback = "A vibrant music video opening scene"
////     guard case .available = SystemLanguageModel.default.availability else {
////         return fallback
////     }
////     do {
////         let session = LanguageModelSession(
////             instructions: "Write a single vivid one-sentence visual prompt for the opening scene of a music video. Respond with only the scene description, no preamble."
////         )
////         let response = try await session.respond(to: "Generate a music video opening scene prompt.")
////         let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
////         return text.isEmpty ? fallback : text
////     } catch {
////         return fallback
////     }
//// }
