# Generate2

**Generate2** is a cross-platform (iOS & Android) SwiftUI/Compose library for generating AI-powered music videos. It provides a complete UI workflow: users upload a song, the app extracts lyrics, generates images per lyric line using multiple AI models, and composes those images into a synchronized music video.

The library is designed to be embedded into host applications. It does not own navigation stacks or internal routing; instead, it exposes a single `ContentView` (iOS) / `ContentView` (Android) composable that renders the entire grid, generation, and video-composition flow.

## Features

- **AI Image Generation**: Fan-out generation using three models (`Flux2Pro`, `NanoBanana2`, `ZImageTurbo`) for both initial generation and per-lyric-line derivation.
- **Lyric Synchronization**: Extracts SYLT (synchronized lyrics) from audio files and organizes generated media into sections based on lyric lines.
- **Video Composition**: Composes selected images into a video using `Ltx23A2V`, with audio trimming to match specific lyric timestamps.
- **Cross-Platform UI**: Identical logic and theming across iOS (SwiftUI) and Android (Jetpack Compose).
- **State Management**: Handles pending states for uploads, generations, and video rendering with shimmer placeholders.
- **Media Management**: Local file persistence, liking/saving media, and drag-and-drop reassignment of images to lyric lines.

## Architecture

The project consists of two main implementations sharing the same logical flow:

1.  **iOS (Swift)**: Located in the root directory. Uses SwiftUI, `@Observable` for state, and `Task` groups for concurrent API calls.
2.  **Android (Kotlin)**: Located in `Kmp/generate/`. Uses Jetpack Compose, `ViewModel` for state survival, and Kotlin Coroutines for concurrency.

### Key Components

#### 1. Core Logic & State
- **`ContentView`**: The root view for both platforms. It manages the high-level phase (`Grid`, `Generating`, `Complete`) and delegates to sub-views.
- **`GenerateViewModel` (Android) / `@State` (iOS)**: Holds all screen state, including lists of images, videos, pending tasks, and lyric lines.
- **`LikeStore`**: A shared observable store tracking which images/videos are "liked" (saved).

#### 2. UI Modules
- **`GridView`**: Renders the main feed. Supports two modes:
    - **Flat Grid**: Simple list of all media.
    - **Sectioned Grid**: Groups media by lyric line (if a song is loaded). Supports drag-and-drop to reassign images to lines.
- **`MakeVideoShelf`**: A bottom sheet that appears when selecting images for video composition. It handles the final API call to generate the video.
- **`GeneratingOverlay`**: Full-screen overlay shown during generation phases.
- **`VideoPreview`**: Full-screen playback view for watching generated videos.

#### 3. Services & Helpers
- **`ProjectService`**: Abstracts local file storage. Saves generated images/videos and metadata (prompts, models, subjects) to disk.
- **`LyricExtractor`**: Parses audio files to extract synchronized lyrics.
    - **iOS**: Uses `AudioMarker` library.
    - **Android**: Uses a Rust core via JNI (`extractSylt`).
- **`AudioClipper` (Android)**: Trims audio files to specific time ranges for video composition using `MediaExtractor` and `MediaCodec`.

## Installation

### iOS (Swift Package Manager)

Add the package to your Xcode project:

```swift
.package(url: "https://github.com/femimarket/generate2", branch: "main")
```

Include the `Generate2` target in your app's dependencies. Ensure you also include its dependencies:
- `swiftapi`
- `swift-project-service`
- `swift-audio-marker`

### Android (Gradle)

Add the library to your `build.gradle.kts`:

```kotlin
dependencies {
    implementation("studio.femi:androidgenerate3:latest.version")
}
```

Ensure your app has the necessary permissions for file access and audio playback. The library includes a `ProjectServiceInitializer` that sets up the local storage directory automatically.

## Usage

### iOS Integration

In your host app's root view, instantiate `ContentView` with credentials and callbacks:

```swift
import Generate2

struct HostApp: View {
    var body: some View {
        ContentView(
            user: "your_api_user",
            password: "your_api_password",
            onUploadSong: { await uploadSong() },
            menuItemName1: "Editorial",
            menuItemIcon1: "rectangle.stack",
            onMenuItemTapped1: { print("Editorial tapped") }
        )
    }
    
    func uploadSong() async {
        // Implement song upload logic
    }
}
```

### Android Integration

In your host app's `Activity` or `Composable`:

```kotlin
@Composable
fun HostApp() {
    ContentView(
        user = "your_api_user",
        password = "your_api_password",
        onUploadSong = { uploadSong() },
        menuItemName1 = "Editorial",
        menuItemIcon1 = Icons.Filled.Collections,
        onMenuItemTapped1 = { print("Editorial tapped") }
    )
}

suspend fun uploadSong() {
    // Implement song upload logic
}
```

## Configuration

### Credentials
The API calls require `user` and `password` credentials passed to `ContentView`. These are used for every request to the AI models.

### Launch Arguments (Demo Apps)
The demo apps (`Generate2App.swift` and `MainActivity.kt`) expect credentials via launch arguments:
- **iOS**: `-user <value> -password <value>`
- **Android**: `-e user <value> -e password <value>`

### Theme
The library uses a custom dark theme with magenta and blue accents.
- **iOS**: Defined in `Theme` enum in `ContentView.swift`.
- **Android**: Defined in `Theme` object in `ContentView.kt`.

## Key Files

### iOS
- `ContentView.swift`: Main entry point, state management, and UI composition.
- `ImageCell.swift`: Grid cell for images, including like/selection logic.
- `VideoCell.swift`: Grid cell for videos, including autoplay and preview logic.
- `PendingCell.swift`: Shimmer placeholders for in-progress tasks.
- `LyricExtractor.swift`: SYLT parsing logic.
- `Package.swift`: SPM configuration.

### Android
- `Kmp/generate/src/androidMain/kotlin/studio/femi/androidgenerate3/ContentView.kt`: Main entry point and UI composition.
- `Kmp/generate/src/androidMain/kotlin/studio/femi/androidgenerate3/GenerateViewModel.kt`: State management and business logic.
- `Kmp/generate/src/androidMain/kotlin/studio/femi/androidgenerate3/ImageCell.kt`: Grid cell for images.
- `Kmp/generate/src/androidMain/kotlin/studio/femi/androidgenerate3/VideoCell.kt`: Grid cell for videos.
- `Kmp/generate/src/androidMain/kotlin/studio/femi/androidgenerate3/PendingCell.kt`: Shimmer placeholders.
- `Kmp/generate/src/androidMain/kotlin/studio/femi/androidgenerate3/LyricExtractor.kt`: SYLT parsing logic.
- `Kmp/generate/src/androidMain/kotlin/studio/femi/androidgenerate3/AudioClipper.kt`: Audio trimming logic.
- `Kmp/demo/src/main/java/studio/femi/demo/MainActivity.kt`: Demo host app.

## Workflow

1. **Upload Song**: User taps the song title in the toolbar to upload an audio file. The app extracts lyrics and displays them as sections in the grid.
2. **Generate Images**: User taps "Generate" to create images using the default prompt, or taps a specific lyric line to generate images for that line.
3. **Like Images**: User taps the heart icon to save images. Only liked images can be selected for video composition.
4. **Compose Video**: User taps "Make Video", selects up to 3 liked images, and taps "Make video". The app:
    - Trims the audio to the timestamp of the primary image's lyric line.
    - Sends image prompts to an LLM (`qwen3_6_35b_a3b`) to create a video prompt.
    - Generates the video using `Ltx23A2V`.
5. **Watch Video**: User taps a generated video to watch it in full-screen playback.

## Dependencies

- **iOS**:
    - `swiftapi`: API client for AI models.
    - `swift-project-service`: Local file management.
    - `swift-audio-marker`: Audio metadata extraction.
- **Android**:
    - `market.femi.api`: API client and Rust bindings.
    - `market.femi.api.ProjectService`: Local file management.
    - `androidx.media3`: Video playback.
    - `coil3`: Image loading.