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

/// Standalone host for Generate2. Credentials come from named Xcode scheme
/// launch arguments: `-user <value> -password <value>`.
private struct AppRoot: View {
    @State private var songBridge = SongBridge()

    private func arg(_ flag: String) -> String {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else {
            preconditionFailure("Missing required launch argument: \(flag)")
        }
        return args[i + 1]
    }

    var body: some View {
        NavigationStack {
            ContentView(
                user: arg("-user"),
                password: arg("-password"),
                onUploadSong: { await songBridge.request() },
                menuItemName1: "Editorial",
                menuItemIcon1: "rectangle.stack",
                onMenuItemTapped1: {}
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

/// Async-to-sheet bridge for the dummy song picker. Resolves with `Void` —
/// parent writes audio to disk itself.
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
