//
//  Generate2App.swift
//  Generate2
//
//  Created by u on 13/06/2026.
//

import SwiftUI
import ProjectService
import UniformTypeIdentifiers

@main
struct Generate2App: App {
    var body: some Scene {
        WindowGroup {
            AppRoot()
        }
    }
}

/// Standalone host for Generate2. Owns the NavigationStack the way the real
/// parent app will, bridges Generate2's `onTopupNeeded` async closure to a
/// dummy sheet, and provides a dummy "team derive view" so the full Normal →
/// Team → Derive flow is exercisable without the team's actual package.
private struct AppRoot: View {
    @State private var bridge = TopupBridge()
    @State private var songBridge = SongBridge()
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            ContentView(
                onTopupNeeded: { await bridge.request() },
                onImageTapped: { imagePath in
                    path.append(.teamDerive(imagePath: imagePath))
                },
                onUploadSong: { await songBridge.request() }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .teamDerive(let imagePath):
                    DummyTeamDeriveView(imagePath: imagePath) { tweak in
                        // Submit: pop the team view, push Generate2 in derive mode.
                        let filename = URL(fileURLWithPath: imagePath).lastPathComponent
                        path.removeLast()
                        path.append(.generate2Derive(filename: filename, tweak: tweak))
                    }
                case .generate2Derive(let filename, let tweak):
                    ContentView(
                        onTopupNeeded: { await bridge.request() },
                        onImageTapped: { imagePath in
                            path.append(.teamDerive(imagePath: imagePath))
                        },
                        onUploadSong: { await songBridge.request() },
                        filename: filename,
                        tweak: tweak
                    )
                }
            }
        }
        .sheet(isPresented: $bridge.showSheet, onDismiss: bridge.resolveAsFailureIfPending) {
            DummyParentTopupSheet(
                onSuccess: { bridge.resolve(true) },
                onCancel: { bridge.resolve(false) }
            )
        }
        .sheet(isPresented: $songBridge.showSheet, onDismiss: songBridge.resolveAsCancelIfPending) {
            DummySongPickerSheet(onDone: { songBridge.resolve() })
        }
    }
}

/// Real audio-file picker. Lets the user pick any .mp3/.m4a/.wav from the
/// Files app; we read the bytes and save via ProjectService. SYLT-bearing
/// files retain their embedded lyrics for downstream extraction.
private struct DummySongPickerSheet: View {
    let onDone: () -> Void
    @State private var importing = false

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            Image(systemName: "music.note")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.purple)
            Text("Pick a song")
                .font(.title2.bold())
            Text("Choose an audio file from Files. Embedded SYLT lyrics are preserved.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Pick audio file") { importing = true }
                .buttonStyle(.borderedProminent)
            Button("Cancel", role: .cancel) { onDone() }
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
        .presentationDetents([.medium])
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    let data = try! Data(contentsOf: url)
                    ProjectService.saveAudio(data, named: url.lastPathComponent)
                }
            }
            onDone()
        }
    }
}

/// Async-to-sheet bridge for the dummy song picker. Mirrors `TopupBridge`
/// but resolves with `Void` — parent writes audio to disk itself.
@MainActor @Observable
private final class SongBridge {
    var showSheet = false
    private var continuation: CheckedContinuation<Void, Never>?

    func request() async {
        await withCheckedContinuation { cont in
            Task { @MainActor in
                self.continuation = cont
                self.showSheet = true
            }
        }
    }

    func resolve() {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume()
        showSheet = false
    }

    func resolveAsCancelIfPending() {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume()
    }
}

/// Parent-side routing vocabulary. Lives entirely in the parent — Generate2
/// has no awareness of these cases.
private enum Route: Hashable {
    case teamDerive(imagePath: String)
    case generate2Derive(filename: String, tweak: String)
}

/// Pretend version of the team's "Change it" screen. Real parent app pushes
/// the team's package view here instead.
private struct DummyTeamDeriveView: View {
    let imagePath: String
    let onSubmit: (String) -> Void
    @State private var tweak: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Source path: \(imagePath)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            TextField("Tell me what to change", text: $tweak, axis: .vertical)
                .focused($focused)
                .font(.body)
                .lineLimit(3...8)
                .padding(16)
                .background(.gray.opacity(0.15), in: .rect(cornerRadius: 16))
                .padding(.horizontal, 16)
            Spacer()
        }
        .navigationTitle("Team derive view (dummy)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
        .safeAreaInset(edge: .bottom) {
            Button("Submit (dummy)") {
                onSubmit(tweak.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .buttonStyle(.borderedProminent)
            .disabled(tweak.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding()
        }
    }
}

/// Async-to-sheet bridge for the dummy topup. Same shape the real parent
/// app's StoreKit flow will use.
@MainActor @Observable
private final class TopupBridge {
    var showSheet = false
    private var continuation: CheckedContinuation<Bool, Never>?

    func request() async -> Bool {
        await withCheckedContinuation { cont in
            Task { @MainActor in
                self.continuation = cont
                self.showSheet = true
            }
        }
    }

    func resolve(_ success: Bool) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: success)
        showSheet = false
    }

    func resolveAsFailureIfPending() {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: false)
    }
}

private struct DummyParentTopupSheet: View {
    let onSuccess: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            Image(systemName: "creditcard.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.blue)
            Text("Parent topup (dummy)")
                .font(.title2.bold())
            Text("Pretend the parent app is showing its own purchase flow here.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Pretend purchase succeeded") {
                onSuccess()
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel", role: .cancel) {
                onCancel()
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
        .presentationDetents([.medium])
    }
}
