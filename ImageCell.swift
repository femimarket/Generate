//
//  ImageCell.swift
//  Generate
//
//  Created by u on 21/06/2026.
//

import SwiftUI
import UIKit
import ProjectService

// MARK: - Authorized image (reads from local project folder)

struct FemiAuthorizedImage: View {
    let filename: String
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var failed = false

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        ZStack {
            if isPreview {
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

    private var bundledPreviewImage: UIImage? {
        let ns = filename as NSString
        let name = ns.deletingPathExtension
        let ext = ns.pathExtension.isEmpty ? "png" : ns.pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    private func load() async {
        let localURL = ProjectService.getUrl(for: (filename as NSString).lastPathComponent)
        if let data = try? Data(contentsOf: localURL), let img = UIImage(data: data) {
            await MainActor.run { self.image = img }
        } else {
            await MainActor.run { self.failed = true }
        }
    }
}

// MARK: - Grid image cell

struct FemiImageCell: View {
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

// MARK: - Selection badge (image-only affordance)

@ViewBuilder
func femiSelectionBadge(order: Int?) -> some View {
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
