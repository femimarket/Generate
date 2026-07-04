# Generate2

**Generate2** is a cross-platform UI library for generating AI-powered music videos. It provides a unified interface for iOS (SwiftUI), Android (Jetpack Compose), and Web (Kotlin/JS) that allows users to generate images from text, organize them by song lyrics, and compose them into synchronized music videos.

The library is designed to be embedded into host applications. It does not own navigation stacks or internal routing; instead, it exposes a single `ContentView` (iOS) or `GenerateImage` (Android/Web) composable that manages the entire "Grid → Derive → Like → Compose Video → Done" workflow.

## Features

*   **Cross-Platform UI**: Identical visual design and interaction patterns across iOS, Android, and Web.
*   **AI Image Generation**: Fan-out generation using multiple models (Flux2Pro, NanoBanana2, ZImageTurbo) with shimmer placeholders for pending states.
*   **Lyric-Synced Organization**: Automatically extracts SYLT lyrics from uploaded audio files and groups generated images into sections based on the song's timeline.
*   **Drag-and-Drop Reassignment**: Move images between lyric sections (iOS/Android) or use a picker (Web) to reassign images to specific lines.
*   **Video Composition**: Compose music videos by selecting up to 3 hearted images. The system uses an LLM to generate a timestamped prompt and an AI video model (LTX-2) to render the final clip.
*   **Audio Trimming**: Automatically trims audio to the specific lyric line duration when composing videos.
*   **Dark Theme**: Native dark navy aesthetic with magenta/blue accent gradients.

## Architecture

The project consists of three main implementation targets sharing the same logic:

1.  **iOS (SwiftUI)**: `ContentView.swift`, `ImageCell.swift`, `VideoCell.swift`, etc.
2.  **Android (Jetpack Compose)**: `ContentView.kt`, `GenerateViewModel.kt`, `ImageCell.kt`, etc.
3.  **Web (Kotlin/JS)**: `Generate.kt`, `LyricExtractor.kt`, etc.

### Key Dependencies

*   **Api**: External package (`swiftapi` / `market.femi.api`) providing FFI bindings to Rust-based AI inference (Flux, LTX, Qwen).
*   **ProjectService**: External package (`swift-project-service` / `market.femi.api.ProjectService`) handling local file storage (OPFS on Web, Documents directory on native).
*   **AudioMarker**: iOS-specific package for SYLT extraction. Android/Web use a Rust-based `extractSylt` function via the Api package.

## Installation & Integration

### iOS

Add the library via Swift Package Manager.

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/femimarket/generate2", branch: "main"),
]
```

In your app's entry point, wrap the `ContentView` in a `NavigationStack` (if needed) and provide credentials via launch arguments or configuration.

```swift
import SwiftUI
import Generate2

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                user: "your-api-user",
                password: "your-api-password",
                onUploadSong: { await uploadSong() },
                menuItemName1: "Editorial",
                menuItemIcon1: "rectangle.stack",
                onMenuItemTapped1: { /* Handle custom menu item */ }
            )
        }
    }
}
```

### Android

Add the library to your `build.gradle.kts`.

```kotlin
dependencies {
    implementation("market.femi:generate:latest.release")
}
```

In your `MainActivity`, initialize the view:

```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            GenerateTheme {
                ContentView(
                    user = "your-api-user",
                    password = "your-api-password",
                    onUploadSong = { /* Handle song upload */ },
                    menuItemName1 = "Editorial",
                    menuItemIcon1 = Icons.Filled.Collections,
                    onMenuItemTapped1 = { /* Handle custom menu item */ }
                )
            }
        }
    }
}
```

### Web

Include the Kotlin/JS artifact in your web build. The entry point is `GenerateImage`.

```kotlin
@Composable
fun App() {
    GenerateImage(
        user = "your-api-user",
        password = "your-api-password",
        onEngineer = { /* Handle engineer menu item */ }
    )
}
```

## Usage Guide

### 1. Initial Setup
Upon first launch, the grid is empty. The user must:
1.  **Upload a Song**: Tap the song title in the toolbar to select an audio file (MP3/M4A/WAV). The app extracts SYLT lyrics if present.
2.  **Generate Images**: Tap the `+` button and select "Generate". This triggers a 3-model fan-out to create initial images.

### 2. Organizing Content
*   **Lyric Sections**: If a song with lyrics is loaded, the grid displays sections for each lyric line.
*   **Unassigned Images**: Images not yet assigned to a line appear at the top of the "All" view.
*   **Reassigning**:
    *   **iOS/Android**: Drag an image onto a lyric header to move it.
    *   **Web**: Long-press an image to open a "Move to line" sheet.
*   **Generating per Line**: Long-press a lyric header to trigger generation specifically for that line's text.

### 3. Liking and Selecting
*   **Hearting**: Tap the heart icon on any image or video to save it.
*   **Making a Video**:
    1.  Tap "Make Video" in the toolbar.
    2.  Select up to 3 hearted images.
    3.  Tap "Make video" in the bottom shelf.
    4.  The system composes a prompt using the selected images' prompts and an LLM, then generates a video using the primary image and the corresponding audio segment.

### 4. Viewing Videos
*   **Grid**: Videos loop muted in the grid.
*   **Preview**: Tap a video to enter full-screen playback with audio.

## Key Files Reference

### iOS
*   `ContentView.swift`: Main entry point, state management, and view composition.
*   `ImageCell.swift`: Individual image grid cell with like/drag logic.
*   `VideoCell.swift`: Video grid cell using `AVPlayer`.
*   `PendingCell.swift`: Shimmer placeholders for in-flight tasks.
*   `LyricExtractor.swift`: SYLT parsing logic.

### Android
*   `ContentView.kt`: Jetpack Compose entry point.
*   `GenerateViewModel.kt`: Holds all screen state, handles async generation, and manages `ProjectService` calls.
*   `AudioClipper.kt`: Native Android audio trimming using `MediaCodec` and `MediaMuxer`.
*   `LyricExtractor.kt`: SYLT parsing via Rust FFI.

### Web
*   `Generate.kt`: Kotlin/JS implementation of the UI.
*   `LyricExtractor.kt`: SYLT parsing via Rust FFI.

## Non-Obvious Conventions

*   **State Persistence**: All generated images and videos are saved to the `ProjectService` directory. The app scans this directory on load to rehydrate the grid.
*   **Audio Session Management**:
    *   **iOS**: Switches `AVAudioSession` to `.playback` during video preview, reverts to `.ambient` on dismiss.
    *   **Android**: Uses `AudioAttributes` with `USAGE_MEDIA` and `CONTENT_TYPE_MOVIE` to request audio focus during preview.
    *   **Web**: Uses native HTML5 video controls; audio focus is handled by the browser.
*   **Image Format Sniffing**: The `saveResponseData` helper sniffs image extensions from magic bytes (PNG, JPG, WebP, GIF, HEIC) to ensure correct file handling.
*   **Pending States**: All in-flight tasks (image gen, video gen, uploads) use a `Pending` struct with `Working`/`Failed` states. Failed cells are tappable to dismiss them from the grid.
*   **Selection Mode**: When "Make Video" is active, the toolbar hides, and a bottom shelf appears. The grid highlights selected images with a numbered badge.

## Troubleshooting

*   **Empty Grid**: Ensure `ProjectService` is correctly initialized and the app has storage permissions.
*   **No Lyrics**: If the grid doesn't show lyric sections, the uploaded audio file may not contain embedded SYLT metadata.
*   **Video Generation Fails**: Check that the primary image has an associated prompt. The video generation step relies on the LLM to combine image prompts into a video prompt.