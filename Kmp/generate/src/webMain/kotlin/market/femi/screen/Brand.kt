package market.femi.screen

// Brand-font slot for the Generate screen. The screen itself ships no font —
// matching the iOS original (system fonts) and the Android target (Material
// defaults). A host app supplies its brand family by wrapping the screen:
//
//     CompositionLocalProvider(LocalBrandFont provides myFamily) {
//         GenerateImage(...)
//     }

import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.text.font.FontFamily

val LocalBrandFont = staticCompositionLocalOf<FontFamily> { FontFamily.SansSerif }

/** Kept so Generate.kt stays line-compatible with the webApp original: the
 *  screen's own `LocalBrandFont provides brandFamily()` becomes a passthrough
 *  of whatever the host provided. */
@Composable
internal fun brandFamily(): FontFamily = LocalBrandFont.current
