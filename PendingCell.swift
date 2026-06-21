//
//  PendingCell.swift
//  Generate
//
//  Created by u on 21/06/2026.
//

import SwiftUI

// MARK: - Shimmer placeholder (used only by pending cells)

struct Shimmer: View {
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

// MARK: - Pending image upload cell

struct PendingImageCell: View {
    let pending: FemiPendingImage
    @Bindable var viewModel: FemiGenerateViewModel

    var body: some View {
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
}

// MARK: - Pending image-generation cell (derive / fill-line)

struct PendingGenerationCell: View {
    let pending: FemiPendingGeneration
    @Bindable var viewModel: FemiGenerateViewModel

    var body: some View {
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
}

// MARK: - Pending video cell (poster + shimmer)

struct PendingVideoCell: View {
    let pending: FemiPendingVideo
    @Bindable var viewModel: FemiGenerateViewModel

    var body: some View {
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
}
