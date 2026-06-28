//
//  ImageCell.swift
//  Generate
//
//  Created by u on 21/06/2026.
//

import SwiftUI
import ProjectService

// MARK: - Grid image cell

struct ImageCell: View {
    let image: String
    let isSelectingForVideo: Bool
    @Binding var selectedImageIds: [String]
    let likeStore: LikeStore

    var body: some View {
        let liked = likeStore.isLiked(image)
        let selecting = isSelectingForVideo
        let selected = selectedImageIds.contains(image)
        let eligible = !selecting || liked

        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AsyncImage(url: ProjectService.getUrl(for: image)) { phase in
                    switch phase {
                    case .empty: Shimmer()
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    case .failure: Color.black.opacity(0.4).overlay(
                        Image(systemName: "photo").foregroundStyle(Theme.muted)
                    )
                    @unknown default: EmptyView()
                    }
                }
            }
            .clipped()
            .overlay {
                if selecting && selected {
                    Theme.accentMagenta.opacity(0.18)
                }
            }
            .overlay(alignment: .topTrailing) {
                if selecting {
                    if eligible {
                        selectionBadge(
                            order: selectedImageIds.firstIndex(of: image)
                        )
                    }
                } else {
                    heartButton(isLiked: liked) {
                        likeStore.toggle(image)
                        ProjectService.like(image, likeStore.isLiked(image))
                    }
                }
            }
            .opacity(eligible ? 1 : 0.3)
            .contentShape(.rect)
            .onTapGesture {
                guard selecting else { return }
                guard eligible else { return }
                guard likeStore.isLiked(image) else { return }
                withAnimation(.spring(duration: 0.25)) {
                    if let i = selectedImageIds.firstIndex(of: image) {
                        selectedImageIds.remove(at: i)
                    } else if selectedImageIds.count < 3 {
                        selectedImageIds.append(image)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .draggable(DraggedImage(filename: image))
            .accessibilityLabel(
                selecting
                    ? (selected ? "Picture, selected" : "Picture, double tap to select")
                    : "Picture"
            )
            .accessibilityValue(liked ? "Saved" : "")
    }
}

// MARK: - Selection badge (image-only affordance)

@ViewBuilder
func selectionBadge(order: Int?) -> some View {
    ZStack {
        if let order {
            Text("\(order + 1)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Theme.accent, in: .circle)
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
