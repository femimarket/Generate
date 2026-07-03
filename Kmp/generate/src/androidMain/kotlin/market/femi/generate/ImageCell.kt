//
//  ImageCell.kt
//  AndroidGenerate3
//
//  Port of Generate2/ImageCell.swift.
//

package market.femi.generate

import android.content.ClipData
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.draganddrop.dragAndDropSource
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Photo
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draganddrop.DragAndDropTransferData
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil3.compose.SubcomposeAsyncImage

// MARK: - Grid image cell

@OptIn(ExperimentalFoundationApi::class)
@Composable
internal fun ImageCell(image: String, vm: GenerateViewModel) {
    val liked = vm.likeStore.isLiked(image)
    val selecting = vm.isSelectingForVideo
    val selectedOrder = vm.selectedImageIds.indexOf(image).takeIf { it >= 0 }
    val selected = selectedOrder != null
    val eligible = !selecting || liked
    val haptics = LocalHapticFeedback.current

    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .clipToBounds()
            .graphicsLayer { alpha = if (eligible) 1f else 0.3f }
            .dragAndDropSource { _ ->
                DragAndDropTransferData(ClipData.newPlainText(DRAGGED_IMAGE_LABEL, image))
            }
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                enabled = selecting && eligible,
            ) {
                if (vm.tapImageInSelection(image)) {
                    haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
                }
            }
            .semantics {
                contentDescription = if (selecting) {
                    if (selected) "Picture, selected" else "Picture, double tap to select"
                } else {
                    "Picture"
                }
                stateDescription = if (liked) "Saved" else ""
            },
    ) {
        SubcomposeAsyncImage(
            model = vm.fileFor(image),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize(),
            loading = { Shimmer() },
            error = {
                Box(
                    Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.Photo, contentDescription = null, tint = Theme.muted)
                }
            },
        )
        if (selecting && selected) {
            Box(Modifier.fillMaxSize().background(Theme.accentMagenta.copy(alpha = 0.18f)))
        }
        Box(Modifier.align(Alignment.TopEnd)) {
            if (selecting) {
                if (eligible) SelectionBadge(order = selectedOrder)
            } else {
                HeartButton(isLiked = liked, onToggle = { vm.toggleImageLike(image) })
            }
        }
    }
}

// MARK: - Selection badge (image-only affordance)

@Composable
internal fun SelectionBadge(order: Int?) {
    Box(Modifier.padding(8.dp), contentAlignment = Alignment.Center) {
        if (order != null) {
            Box(
                modifier = Modifier
                    .size(26.dp)
                    .clip(CircleShape)
                    .background(Theme.accent)
                    .border(1.5.dp, Color.White, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "${order + 1}",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
            }
        } else {
            Box(
                Modifier
                    .size(26.dp)
                    .clip(CircleShape)
                    .background(Color.Black.copy(alpha = 0.25f))
                    .border(1.5.dp, Color.White.copy(alpha = 0.9f), CircleShape)
            )
        }
    }
}
