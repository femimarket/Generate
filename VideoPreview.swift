//
//  VideoPreview.swift
//  Generate2
//
//  Full-screen video playback for the grid's video cell tap.
//  Switches AVAudioSession to .playback so the user's silent switch doesn't
//  mute the video (intentional: they tapped to watch, that's consent).
//  Reverts to .ambient on dismiss so the rest of the app stays polite.
//

import SwiftUI
import AVKit
import AVFoundation
import ProjectService

struct VideoPreview: View {
    let video: GeneratedVideo
    let onDismiss: () -> Void
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                AsyncImage(url: ProjectService.getUrl(for: video.posterFile)) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: Color.black
                    }
                }
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
        .task {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            let asset = AVURLAsset(url: ProjectService.getUrl(for: video.file))
            let item = AVPlayerItem(asset: asset)
            let p = AVPlayer(playerItem: item)
            p.isMuted = false
            self.player = p
            p.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
            try? AVAudioSession.sharedInstance().setCategory(
                .ambient, mode: .default, options: [.mixWithOthers]
            )
        }
    }
}
