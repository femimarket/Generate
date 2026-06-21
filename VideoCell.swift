//
//  VideoCell.swift
//  Generate
//
//  Created by u on 21/06/2026.
//

import SwiftUI
import AVKit
import AVFoundation
import UIKit
import ProjectService

// MARK: - Authorized auto-muted looping video view

struct AuthorizedVideoView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PlayerUIView { PlayerUIView(url: url) }
    func updateUIView(_ uiView: PlayerUIView, context: Context) {}
}

final class PlayerUIView: UIView {
    private let player: AVPlayer
    private let layerView = AVPlayerLayer()
    init(url: URL) {
        let asset = AVURLAsset(url: url)
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

// MARK: - Grid video cell

struct VideoCell: View {
    let video: FemiGeneratedVideo
    @Bindable var viewModel: FemiGenerateViewModel

    var body: some View {
        let selecting = viewModel.isSelectingForVideo
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                ZStack {
                    AuthorizedVideoView(url: ProjectService.getUrl(for: video.file))
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
