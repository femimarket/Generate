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


// MARK: - App root

/// Root view of the Generate2 library. Shows the grid + chrome.
/// Generate2 does not own a NavigationStack and emits no internal routes.
public struct ContentView: View {
    /// Credentials passed on every Api call (user / password auth).
    let user: String
    let password: String
    /// Fired when the user taps the song-title slot in the toolbar.
    let onUploadSong: () async -> Void
    let menuItemName1: String
    let menuItemIcon1: String
    let onMenuItemTapped1: () -> Void

    public init(
        user: String,
        password: String,
        onUploadSong: @escaping () async -> Void,
        menuItemName1: String,
        menuItemIcon1: String,
        onMenuItemTapped1: @escaping () -> Void
    ) {
        self.user = user
        self.password = password
        self.onUploadSong = onUploadSong
        self.menuItemName1 = menuItemName1
        self.menuItemIcon1 = menuItemIcon1
        self.onMenuItemTapped1 = onMenuItemTapped1
    }

    public var body: some View {
        Generate(
            user: user,
            password: password,
            onUploadSong: onUploadSong,
            menuItemName1: menuItemName1,
            menuItemIcon1: menuItemIcon1,
            onMenuItemTapped1: onMenuItemTapped1
        )
    }
}

// MARK: - Theme

enum Theme {
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

struct AccentButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
     func makeBody(configuration: Configuration) -> some View {
         configuration.label
             .font(.headline.weight(.semibold))
             .foregroundStyle(.white)
             .padding(.vertical, 16)
             .frame(maxWidth: fullWidth ? .infinity : nil)
             .padding(.horizontal, fullWidth ? 0 : 28)
             .background(Theme.accent, in: .capsule)
             .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
             .shadow(color: Theme.accentMagenta.opacity(0.35), radius: 18, y: 8)
             .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
             .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
     }
}

// MARK: - Local models (client-side state)

/// A single timed lyric line. Server-side forced alignment is the production
/// path; the client stub in `pasteLyrics` assigns equal 6s windows as a
/// placeholder until that pipeline exists.
struct SongLine: Identifiable, Hashable, Sendable {
    let id: UUID
    let index: Int
    let text: String
    let startMs: Int
    let durationMs: Int
}

struct GeneratedVideo: Identifiable, Hashable, Sendable {
    let id: UUID
    let file: String
    let posterFile: String
    let sourceImageIds: [String]
}

/// A video that's being generated in the background. The grid renders this as a
/// shimmer cell so the user can keep doing other things while it cooks.
struct PendingVideo: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable { case working, failed }
    let id: UUID
    let sourceImageIds: [String]
    let posterFile: String
    var state: State = .working
}

/// Drag payload for moving an image between lyric line sections.
struct DraggedImage: Codable, Transferable {
    let filename: String
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

/// An image being uploaded from the user's photo library. Mirrors PendingVideo —
/// the grid shows a shimmer cell while the upload happens in the background.
struct PendingImage: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable { case working, failed }
    let id: UUID
    var state: State = .working
}

/// An in-flight image generation (derive or fill-line). Rendered as a shimmer
/// cell in the grid so the rest of the UI stays interactive. `lineIndex` is
/// pre-computed at task start so the cell lands in the correct section.
struct PendingGeneration: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable { case working, failed }
    let id: UUID
    let lineIndex: Int?
    var state: State = .working
}

// MARK: - Shared enums (top-level so views can hold them without a view model)

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

// MARK: - Like store (focused @Observable, reused by every image/video cell)

@MainActor @Observable
final class LikeStore {
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

// MARK: - File-private helpers

/// Persist bytes returned by an Api method to the project folder under
/// a fresh local filename. `ext` is sniffed from the bytes via ImageIO
/// when not supplied (video callers pass `"mp4"` since ImageIO doesn't
/// cover video). Returns the new filename for grid wiring.
fileprivate func saveResponseData(_ data: Data, ext: String? = nil, prompt: String? = nil, model: String? = nil, subject: [String]? = nil) -> String {
    let finalExt: String
    if let ext {
        finalExt = ext
    } else {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(src) as? String,
              let sniffed = UTType(uti)?.preferredFilenameExtension
        else { preconditionFailure("saveResponseData: response bytes aren't a recognized image format") }
        finalExt = sniffed
    }
    let name = "gen-\(UUID().uuidString).\(finalExt)"
    ProjectService.saveFile(data, named: name, prompt: prompt, model: model, subject: subject)
    return name
}

/// Read a project file from disk as raw bytes — the new Api contract
/// for `image` / `audio` parameters.
fileprivate func bytesOf(_ file: String) -> Data {
    try! Data(contentsOf: ProjectService.getUrl(for: file))
}

// MARK: - Generate (the screen)

struct Generate: View {
    let user: String
    let password: String
    let onUploadSong: () async -> Void
    let menuItemName1: String
    let menuItemIcon1: String
    let onMenuItemTapped1: () -> Void

    // All screen state — was previously dumped on FemiGenerateViewModel.
    @State private var phase: Phase = .grid
    @State private var filter: GridFilter = .all
    @State private var isSelectingForVideo: Bool = false
    @State private var selectedImageIds: [String] = []
    @State private var viewingVideo: GeneratedVideo? = nil
    @State private var images: [String] = []
    @State private var imageLineIndex: [String: Int] = [:]
    @State private var videoLineIndex: [String: Int] = [:]
    @State private var videos: [GeneratedVideo] = []
    @State private var pendingVideos: [PendingVideo] = []
    @State private var pendingImages: [PendingImage] = []
    @State private var pendingGenerations: [PendingGeneration] = []
    @State private var audiolines: [SongLine]? = nil
    @State private var likeStore = LikeStore()
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false

    private var canMakeVideo: Bool {
        images.contains { likeStore.isLiked($0) }
    }

    private var isOnGrid: Bool {
        if case .grid = phase { return true }
        return false
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
        }
        .toolbar { toolbar }
        .fullScreenCover(item: $viewingVideo) { video in
            VideoPreview(video: video) { viewingVideo = nil }
        }
        .preferredColorScheme(.dark)
        .task {
            let existingImages = Set(images)
            let existingVideos = Set(videos.map(\.file))
            for url in ProjectService.getAllGenerations() {
                let filename = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                switch ext {
                case "png", "jpg", "jpeg", "webp", "gif", "heic", "heif":
                    if !existingImages.contains(filename) {
                        images.append(filename)
                        if let subject = ProjectService.getSubject(filename),
                           let idx = subject.compactMap(Int.init).first {
                            imageLineIndex[filename] = idx
                        }
                    }
                case "mp4":
                    if !existingVideos.contains(filename) {
                        videos.append(GeneratedVideo(
                            id: UUID(), file: filename, posterFile: "", sourceImageIds: []
                        ))
                        if let subject = ProjectService.getSubject(filename),
                           let idx = subject.compactMap(Int.init).first {
                            videoLineIndex[filename] = idx
                        }
                    }
                default: break
                }
            }
            for image in images where ProjectService.getLike(image) {
                likeStore.setLiked(image, true)
            }
            if let song = ProjectService.getAudio()?.lastPathComponent {
                extractAudiolines(filename: song)
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker,
                      selection: $photoPickerItem,
                      matching: .images)
        .onChange(of: photoPickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    let name = "upload-\(UUID().uuidString).jpg"
                    ProjectService.saveFile(data, named: name, prompt: nil, model: nil, subject: nil)
                    withAnimation(.spring(duration: 0.4)) {
                        images.append(name)
                    }
                }
                photoPickerItem = nil
            }
        }
        .toolbar(isSelectingForVideo ? .hidden : .visible, for: .tabBar)
        .animation(.spring(duration: 0.3), value: isSelectingForVideo)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelectingForVideo {
                MakeVideoShelf(
                    user: user, password: password,
                    isSelectingForVideo: $isSelectingForVideo,
                    selectedImageIds: $selectedImageIds,
                    imageLineIndex: $imageLineIndex,
                    videoLineIndex: $videoLineIndex,
                    videos: $videos,
                    pendingVideos: $pendingVideos,
                    audiolines: audiolines
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .generating(let kind):
            GeneratingOverlay(kind: kind)
        case .grid:
            GridView(
                user: user, password: password,
                filter: $filter,
                isSelectingForVideo: isSelectingForVideo,
                selectedImageIds: $selectedImageIds,
                viewingVideo: $viewingVideo,
                images: $images,
                imageLineIndex: $imageLineIndex,
                videoLineIndex: videoLineIndex,
                videos: videos,
                pendingVideos: $pendingVideos,
                pendingImages: $pendingImages,
                pendingGenerations: $pendingGenerations,
                audiolines: audiolines,
                likeStore: likeStore
            )
        case .complete:
            CompletionView(onDone: { phase = .grid })
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isSelectingForVideo {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    withAnimation(.spring(duration: 0.3)) {
                        isSelectingForVideo = false
                        selectedImageIds = []
                    }
                }
                .foregroundStyle(Theme.onSurface)
            }
            ToolbarItem(placement: .principal) {
                Text("\(selectedImageIds.count) of 3 picked")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .contentTransition(.numericText(value: Double(selectedImageIds.count)))
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                if isOnGrid {
                    Menu {
                        Button {
                            Task { await runDefaultGenerate() }
                        } label: {
                            Label("Generate", systemImage: "sparkles")
                        }
                        Button {
                            showingPhotoPicker = true
                        } label: {
                            Label("Upload from Photos", systemImage: "photo")
                        }
                        Button {
                            onMenuItemTapped1()
                        } label: {
                            Label(menuItemName1, systemImage: menuItemIcon1)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.onSurface)
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                Button {
                    Task {
                        await onUploadSong()
                        audiolines = nil
                        if let file = ProjectService.getAudio()?.lastPathComponent {
                            extractAudiolines(filename: file)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let song = ProjectService.getAudio()?.lastPathComponent {
                            Text(song)
                                .font(.headline)
                                .foregroundStyle(Theme.onSurface)
                                .lineLimit(1)
                        } else {
                            Text("No song")
                                .font(.headline)
                                .foregroundStyle(Theme.muted)
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isOnGrid {
                    Button {
                        guard canMakeVideo else { return }
                        selectedImageIds = []
                        withAnimation(.spring(duration: 0.3)) { isSelectingForVideo = true }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "film.fill")
                            Text("Make Video")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(canMakeVideo ? Theme.onSurface : Theme.muted)
                    .disabled(!canMakeVideo)
                    .accessibilityLabel("Make video")
                    .accessibilityHint(canMakeVideo
                        ? "Pick up to three of your saved pictures"
                        : "Save at least one picture first")
                }
            }
        }
    }

    /// Off-main SYLT read via AudioMarker. Fire-and-forget — kicks off a
    /// detached task and returns immediately; the `withAnimation` hop back
    /// to main runs whenever the read completes.
    private func extractAudiolines(filename: String) {
        let url = ProjectService.getUrl(for: filename)
        Task.detached(priority: .userInitiated) {
            let lines = LyricExtractor.read(audioURL: url)
            guard !lines.isEmpty else { return }
            await MainActor.run {
                withAnimation(.spring(duration: 0.5)) {
                    self.audiolines = lines
                    var nextLine = 0
                    for i in self.images.indices where self.imageLineIndex[self.images[i]] == nil {
                        self.imageLineIndex[self.images[i]] = lines[nextLine % lines.count].index
                        nextLine += 1
                    }
                }
            }
        }
    }

    /// 3-model fan-out: Flux2Pro / NanoBanana2 / ZImageTurbo for the default
    /// "make me 3 pictures" tap.
    private func runDefaultGenerate() async {
        let pendings = (0..<3).map { _ in
            PendingGeneration(id: UUID(), lineIndex: nil)
        }
        var queue = pendings.map(\.id)
        withAnimation(.spring(duration: 0.4)) {
            pendingGenerations.append(contentsOf: pendings)
            phase = .grid
        }
        let prompt = "cinematic music video still, vivid color grade, dramatic lighting, expressive performer mid-motion, shallow depth of field, 35mm film grain, emotional and atmospheric"
        await withTaskGroup(of: (Data, String).self) { group in
            group.addTask { (await Api.flux2Pro(user: user, password: password, prompt: prompt), "Flux2Pro") }
            group.addTask { (await Api.nanoBanana2(user: user, password: password, prompt: prompt), "NanoBanana2") }
            group.addTask { (await Api.zImageTurbo(user: user, password: password, prompt: prompt), "ZImageTurbo") }
            for await (data, model) in group {
                let file = saveResponseData(data, model: model)
                guard !queue.isEmpty else { continue }
                let pid = queue.removeFirst()
                withAnimation(.spring(duration: 0.35)) {
                    pendingGenerations.removeAll { $0.id == pid }
                    images.append(file)
                }
            }
        }
        for pid in queue {
            if let i = pendingGenerations.firstIndex(where: { $0.id == pid }) {
                pendingGenerations[i].state = .failed
            }
        }
    }
}

// MARK: - Generating overlay

private struct GeneratingOverlay: View {
    let kind: GenerationKind
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().stroke(Theme.accentMagenta.opacity(0.4), lineWidth: 3)
                    .frame(width: 140, height: 140).blur(radius: 2)
                ProgressView().controlSize(.large).tint(Theme.accentMagenta)
            }
            Text(title).font(.title3.bold()).foregroundStyle(Theme.onSurface)
            Text(subtitle).font(.subheadline).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
        }
        .background(Theme.background.ignoresSafeArea())
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

// MARK: - Heart button (shared by image + video cells)

@ViewBuilder
 func heartButton(isLiked: Bool, action: @escaping @MainActor () -> Void) -> some View {
     Button {
         withAnimation(.spring(duration: 0.35)) { action() }
         UIImpactFeedbackGenerator(style: .medium).impactOccurred()
     } label: {
         if isLiked {
             Image(systemName: "heart.fill")
                 .font(.caption.weight(.bold))
                 .foregroundStyle(.white)
                 .padding(7)
                 .background(Theme.accent, in: .circle)
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

// MARK: - Make-video shelf

/// Commit shelf while picking pictures for a video (Photos pattern).
private struct MakeVideoShelf: View {
    let user: String
    let password: String
    @Binding var isSelectingForVideo: Bool
    @Binding var selectedImageIds: [String]
    @Binding var imageLineIndex: [String: Int]
    @Binding var videoLineIndex: [String: Int]
    @Binding var videos: [GeneratedVideo]
    @Binding var pendingVideos: [PendingVideo]
    let audiolines: [SongLine]?

    var body: some View {
        Button("Make video") {
            Task {
                let ids = selectedImageIds
                let firstId = ids.first!
                let primary = firstId
                isSelectingForVideo = false
                selectedImageIds = []
                let pending = PendingVideo(
                    id: UUID(), sourceImageIds: ids, posterFile: primary
                )
                withAnimation(.spring(duration: 0.3)) {
                    pendingVideos.append(pending)
                }
                let audioFile = ProjectService.getAudio()!.lastPathComponent
                let imagePrompts = ids.compactMap { ProjectService.getPrompt($0) }
                let imageData = bytesOf(primary)
                let lineRange: (start: Int, duration: Int)? = {
                    guard let lineIndex = imageLineIndex[primary],
                          let line = audiolines?.first(where: { $0.index == lineIndex })
                    else { return nil }
                    return (line.startMs, 10_000)
                }()
                let audioData: Data
                if let lineRange {
                    let inURL = ProjectService.getUrl(for: audioFile)
                    let outURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(UUID().uuidString).m4a")
                    let asset = AVURLAsset(url: inURL)
                    let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)!
                    exporter.outputURL = outURL
                    exporter.outputFileType = .m4a
                    exporter.timeRange = CMTimeRange(
                        start: CMTime(value: Int64(lineRange.start), timescale: 1000),
                        duration: CMTime(value: Int64(lineRange.duration), timescale: 1000)
                    )
                    try! await exporter.export(to: outURL, as: .m4a)
                    defer { try? FileManager.default.removeItem(at: outURL) }
                    audioData = try! Data(contentsOf: outURL)
                } else {
                    audioData = bytesOf(audioFile)
                }
                let instruction = "Convert these \(imagePrompts.count) image prompts into a timestamped music-video prompt with exactly \(imagePrompts.count) multishot timestamps. Under 100 words. Return only the prompt itself — no title, no preamble, no commentary, no trailing notes, no markdown.\n\n\(imagePrompts.joined(separator: "\n---\n"))"
                let chatReply = await Api.qwen3_6_35b_a3b(
                    user: user, password: password,
                    messages: [(role: .user, content: instruction)]
                )
                guard let prompt = chatReply.last?.content, !prompt.isEmpty else {
                    print("← chat FAIL: empty reply")
                    if let idx = pendingVideos.firstIndex(where: { $0.id == pending.id }) {
                        pendingVideos[idx].state = .failed
                    }
                    return
                }
                let videoData = await Api.ltx2_3a2v(
                    user: user, password: password,
                    image: imageData, audio: audioData, prompt: prompt
                )
                let lineSubject: [String]? = {
                    guard let idx = imageLineIndex[primary],
                          let text = audiolines?.first(where: { $0.index == idx })?.text
                    else { return nil }
                    return ["\(idx)", text]
                }()
                let file = saveResponseData(
                    videoData, ext: "mp4",
                    prompt: prompt, model: "Ltx23A2V", subject: lineSubject
                )
                withAnimation(.spring(duration: 0.4)) {
                    pendingVideos.removeAll { $0.id == pending.id }
                    videos.append(GeneratedVideo(
                        id: UUID(), file: file, posterFile: primary, sourceImageIds: ids
                    ))
                    if let idx = imageLineIndex[primary] {
                        videoLineIndex[file] = idx
                    }
                }
            }
        }
        .buttonStyle(AccentButtonStyle())
        .disabled(selectedImageIds.isEmpty)
        .opacity(selectedImageIds.isEmpty ? 0.5 : 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }
}

// MARK: - Grid

private struct GridView: View {
    let user: String
    let password: String
    @Binding var filter: GridFilter
    let isSelectingForVideo: Bool
    @Binding var selectedImageIds: [String]
    @Binding var viewingVideo: GeneratedVideo?
    @Binding var images: [String]
    @Binding var imageLineIndex: [String: Int]
    let videoLineIndex: [String: Int]
    let videos: [GeneratedVideo]
    @Binding var pendingVideos: [PendingVideo]
    @Binding var pendingImages: [PendingImage]
    @Binding var pendingGenerations: [PendingGeneration]
    let audiolines: [SongLine]?
    let likeStore: LikeStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    private var filteredImages: [String] {
        switch filter {
        case .all, .videos: images
        case .liked: images.filter { likeStore.isLiked($0) }
        }
    }

    private var visibleVideos: [GeneratedVideo] {
        switch filter {
        case .all, .videos: return videos
        case .liked: return videos.filter { likeStore.isLiked($0.id.uuidString) }
        }
    }

    private var visiblePendingVideos: [PendingVideo] {
        switch filter {
        case .all, .videos: return pendingVideos
        case .liked: return []
        }
    }

    private var visiblePendingImages: [PendingImage] {
        filter == .all ? pendingImages : []
    }

    private var visiblePendingGenerations: [PendingGeneration] {
        filter == .all ? pendingGenerations : []
    }

    private var hasNoContent: Bool {
        let imagesEmpty = filter == .videos
            || (filteredImages.isEmpty
                && visiblePendingImages.isEmpty
                && visiblePendingGenerations.isEmpty)
        let videosEmpty = visibleVideos.isEmpty && visiblePendingVideos.isEmpty
        return imagesEmpty && videosEmpty
    }

    private var shouldSection: Bool {
        filter == .all && audiolines != nil
    }

    private var bottomChromeMargin: CGFloat {
        isSelectingForVideo ? 80 : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if hasNoContent {
                emptyState
            } else if shouldSection, let audiolines {
                let unassignedPendings = visiblePendingGenerations.filter { $0.lineIndex == nil }
                let unassignedImages = filteredImages.filter { imageLineIndex[$0] == nil }
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        if !visiblePendingImages.isEmpty || !visiblePendingVideos.isEmpty
                            || !unassignedPendings.isEmpty || !unassignedImages.isEmpty {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(visiblePendingImages) {
                                    PendingImageCell(pending: $0, pendingImages: $pendingImages)
                                }
                                ForEach(visiblePendingVideos) {
                                    PendingVideoCell(pending: $0, pendingVideos: $pendingVideos)
                                }
                                ForEach(unassignedPendings) {
                                    PendingGenerationCell(pending: $0, pendingGenerations: $pendingGenerations)
                                }
                                ForEach(unassignedImages, id: \.self) {
                                    ImageCell(
                                        image: $0,
                                        isSelectingForVideo: isSelectingForVideo,
                                        selectedImageIds: $selectedImageIds,
                                        likeStore: likeStore
                                    )
                                }
                            }
                            .padding(.horizontal, 2)
                            .padding(.top, 6)
                        }
                        ForEach(audiolines) { line in
                            let imagesForLine = filteredImages.filter { imageLineIndex[$0] == line.index }
                            let pendingsForLine = visiblePendingGenerations.filter { $0.lineIndex == line.index }
                            let videosForLine = visibleVideos.filter { videoLineIndex[$0.file] == line.index }
                            let count = imagesForLine.count + pendingsForLine.count + videosForLine.count
                            Section {
                                if !pendingsForLine.isEmpty || !imagesForLine.isEmpty || !videosForLine.isEmpty {
                                    LazyVGrid(columns: columns, spacing: 2) {
                                        ForEach(pendingsForLine) {
                                            PendingGenerationCell(pending: $0, pendingGenerations: $pendingGenerations)
                                        }
                                        ForEach(imagesForLine, id: \.self) {
                                            ImageCell(
                                                image: $0,
                                                isSelectingForVideo: isSelectingForVideo,
                                                selectedImageIds: $selectedImageIds,
                                                likeStore: likeStore
                                            )
                                        }
                                        ForEach(videosForLine) {
                                            VideoCell(
                                                video: $0,
                                                isSelectingForVideo: isSelectingForVideo,
                                                viewingVideo: $viewingVideo,
                                                likeStore: likeStore
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                    .padding(.top, 4)
                                    .dropDestination(for: DraggedImage.self) { items, _ in
                                        withAnimation(.spring(duration: 0.25)) {
                                            for item in items {
                                                imageLineIndex[item.filename] = line.index
                                                if let data = try? Data(contentsOf: ProjectService.getUrl(for: item.filename)) {
                                                    ProjectService.saveFile(
                                                        data,
                                                        named: item.filename,
                                                        prompt: ProjectService.getPrompt(item.filename),
                                                        model: ProjectService.getModel(item.filename),
                                                        subject: ["\(line.index)", line.text]
                                                    )
                                                }
                                            }
                                        }
                                        return !items.isEmpty
                                    }
                                }
                            } header: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.text)
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(Theme.onSurface)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text(count == 0 ? "No pictures yet"
                                                    : "\(count) \(count == 1 ? "picture" : "pictures")")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 28)
                                .padding(.bottom, 10)
                                .background(Theme.background)
                                .dropDestination(for: DraggedImage.self) { items, _ in
                                    withAnimation(.spring(duration: 0.25)) {
                                        for item in items {
                                            imageLineIndex[item.filename] = line.index
                                            if let data = try? Data(contentsOf: ProjectService.getUrl(for: item.filename)) {
                                                ProjectService.saveFile(
                                                    data,
                                                    named: item.filename,
                                                    prompt: ProjectService.getPrompt(item.filename),
                                                    model: ProjectService.getModel(item.filename),
                                                    subject: ["\(line.index)", line.text]
                                                )
                                            }
                                        }
                                    }
                                    return !items.isEmpty
                                }
                                .contextMenu {
                                    Button {
                                        Task { await fillLine(line) }
                                    } label: {
                                        Label("Make pictures for this line", systemImage: "sparkles")
                                    }
                                }
                                .accessibilityLabel(line.text)
                            }
                        }
                        let orphanVideos = visibleVideos.filter { videoLineIndex[$0.file] == nil }
                        if !orphanVideos.isEmpty {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(orphanVideos) {
                                    VideoCell(
                                        video: $0,
                                        isSelectingForVideo: isSelectingForVideo,
                                        viewingVideo: $viewingVideo,
                                        likeStore: likeStore
                                    )
                                }
                            }
                            .padding(.horizontal, 2)
                            .padding(.top, 12)
                        }
                    }
                }
                .contentMargins(.bottom, bottomChromeMargin, for: .scrollContent)
            } else {
                flatScroll
            }
        }
    }

    private var flatScroll: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                if filter != .videos {
                    ForEach(visiblePendingImages) {
                        PendingImageCell(pending: $0, pendingImages: $pendingImages)
                    }
                    ForEach(visiblePendingGenerations) {
                        PendingGenerationCell(pending: $0, pendingGenerations: $pendingGenerations)
                    }
                    ForEach(filteredImages, id: \.self) {
                        ImageCell(
                            image: $0,
                            isSelectingForVideo: isSelectingForVideo,
                            selectedImageIds: $selectedImageIds,
                            likeStore: likeStore
                        )
                    }
                }
                ForEach(visiblePendingVideos) {
                    PendingVideoCell(pending: $0, pendingVideos: $pendingVideos)
                }
                ForEach(visibleVideos) {
                    VideoCell(
                        video: $0,
                        isSelectingForVideo: isSelectingForVideo,
                        viewingVideo: $viewingVideo,
                        likeStore: likeStore
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 6)
        }
        .contentMargins(.bottom, bottomChromeMargin, for: .scrollContent)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: emptyIcon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.muted)
            Text(emptyTitle)
                .font(.headline)
                .foregroundStyle(Theme.onSurface)
            Text(emptyBody)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIcon: String {
        switch filter {
        case .all: "photo.on.rectangle"
        case .liked: "heart"
        case .videos: "film"
        }
    }
    private var emptyTitle: String {
        switch filter {
        case .all: "No pictures yet"
        case .liked: "Nothing hearted yet"
        case .videos: "No videos yet"
        }
    }
    private var emptyBody: String {
        switch filter {
        case .all: "Tap Start to make your first ones."
        case .liked: "Hold a picture to heart it. Hearted pictures can become videos."
        case .videos: "Heart a few pictures, then make a video."
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(GridFilter.allCases, id: \.self) { f in
                Button {
                    withAnimation(.spring) { filter = f }
                } label: {
                    Text(f.label)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background {
                    if filter == f {
                        Capsule().fill(Theme.accentMagenta.opacity(0.25))
                            .overlay(Capsule().stroke(Theme.accentMagenta.opacity(0.6), lineWidth: 1))
                    } else {
                        Capsule().fill(.white.opacity(0.08))
                    }
                }
                .foregroundStyle(filter == f ? Theme.onSurface : Theme.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    /// Per-line generate from contextMenu — same 3-model fan-out as the
    /// default Generate button but pendings are scoped to the lyric line.
    private func fillLine(_ line: SongLine) async {
        let lineIndex = line.index
        let prompt = line.text
        let pendings = (0..<3).map { _ in
            PendingGeneration(id: UUID(), lineIndex: lineIndex)
        }
        var queue = pendings.map(\.id)
        withAnimation(.spring(duration: 0.3)) {
            pendingGenerations.append(contentsOf: pendings)
        }
        await withTaskGroup(of: (Data, String).self) { group in
            group.addTask { (await Api.flux2Pro(user: user, password: password, prompt: prompt), "Flux2Pro") }
            group.addTask { (await Api.nanoBanana2(user: user, password: password, prompt: prompt), "NanoBanana2") }
            group.addTask { (await Api.zImageTurbo(user: user, password: password, prompt: prompt), "ZImageTurbo") }
            for await (data, model) in group {
                let file = saveResponseData(data, prompt: prompt, model: model, subject: ["line:\(lineIndex)"])
                guard !queue.isEmpty else { continue }
                let pid = queue.removeFirst()
                withAnimation(.spring(duration: 0.35)) {
                    pendingGenerations.removeAll { $0.id == pid }
                    images.append(file)
                    imageLineIndex[file] = lineIndex
                }
            }
        }
        for pid in queue {
            if let i = pendingGenerations.firstIndex(where: { $0.id == pid }) {
                pendingGenerations[i].state = .failed
            }
        }
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
                Circle().fill(Theme.accentMagenta.opacity(pulse ? 0.5 : 0.2))
                    .frame(width: pulse ? 260 : 200, height: pulse ? 260 : 200)
                    .blur(radius: 30)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(spacing: 12) {
                Text("You did it.").font(.largeTitle.bold())
                    .foregroundStyle(Theme.onSurface)
                Text("That's a video. Make more whenever you want.")
                    .font(.body).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(AccentButtonStyle())
                .padding(.horizontal, 24).padding(.bottom, 48)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
