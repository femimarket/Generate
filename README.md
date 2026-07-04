# Generate2

**Generate2** is a cross-platform UI library for generating AI-powered music videos. It provides a unified "Generate → Derive → Like → Compose" workflow that runs on iOS (SwiftUI), Android (Compose), and Web (Kotlin/JS).

The app allows users to upload a song, automatically extract synchronized lyrics (SYLT), and generate cinematic images for each lyric line using multiple AI models. Users can curate these images, select up to three, and compose a final music video using a generative video model.

## Architecture & Targets

The project is structured as a multi-platform library with platform-specific host applications.

### 1. iOS (SwiftUI)
*   **Library:** `Generate2` (Swift Package).
*   **Host:** `Generate2App.swift` (Standalone app).
*   **Key Files:**
    *   `ContentView.swift`: The flagship screen containing the grid, toolbar, and state management.
    *   `PendingCell.swift`, `ImageCell.swift`, `VideoCell.swift`: UI components for the grid.
    *   `LyricExtractor.swift`: Parses SYLT lyrics from audio files using `AudioMarker`.
*   **Dependencies:** `Api`, `ProjectService`, `AudioMarker`.

### 2. Android (Jetpack Compose)
*   **Library:** `Kmp/generate` (Kotlin Multiplatform).
*   **Host:** `Kmp/demo/src/main/java/studio/femi/demo/MainActivity.kt`.
*   **Key Files:**
    *   `ContentView.kt`: Compose equivalent of `ContentView.swift`.
    *   `GenerateViewModel.kt`: Manages screen state, async generation tasks, and file I/O.
    *   `AudioClipper.kt`: Android-native audio trimming using `MediaCodec` and `MediaMuxer` (equivalent to iOS `AVAssetExportSession`).
    *   `LyricExtractor.kt`: Calls the shared Rust API for SYLT extraction.
*   **Dependencies:** `market.femi.api`, `coil3`, `media3`.

### 3. Web (Kotlin/JS)
*   **Library:** `Kmp/generate/src/webMain`.
*   **Key Files:**
    *   `Generate.kt`: The web implementation of the Generate screen.
    *   `LyricExtractor.kt`: Web-specific SYLT parsing.
*   **Storage:** Uses OPFS (Origin Private File System) via `ProjectService`.

## Core Workflow

1.  **Song Upload:** The user uploads an audio file (MP3/M4A/WAV). The app extracts embedded SYLT lyrics to create timed lyric lines.
2.  **Image Generation:**
    *   **Default:** Tapping "Generate" fans out requests to three models (`Flux2Pro`, `NanoBanana2`, `ZImageTurbo`) using a cinematic prompt.
    *   **Per-Line:** Long-pressing a lyric line header or using the context menu generates images specifically for that lyric.
3.  **Curation:** Users "like" (heart) images. Liked images are eligible for video composition.
4.  **Video Composition:**
    *   User selects up to 3 liked images.
    *   The app uses an LLM (`qwen3_6_35b_a3b`) to create a timestamped prompt based on the image prompts.
    *   It clips the audio to the relevant lyric segment.
    *   It sends the image, audio, and prompt to the video model (`ltx2_3a2v`).
5.  **Playback:** Generated videos loop muted in the grid. Tapping a video plays it unmuted with audio focus.

## Installation & Setup

### Prerequisites
*   **iOS:** Xcode 15+, Swift 6.
*   **Android:** Android Studio, JDK 17+.
*   **Web:** Node.js environment for running the Kotlin/JS build.

### Credentials
The app requires API credentials for all generation tasks. These are passed at runtime:

*   **iOS:** Passed via `ContentView` init. In the demo app, read from launch arguments: `-user <value> -password <value>`.
*   **Android:** Passed via `ContentView` composable. In the demo app, read from intent extras: `adb shell am start -n studio.femi.demo/.MainActivity -e user <u> -e password <p>`.
*   **Web:** Passed to `GenerateImage(user, password)`.

### Building

#### iOS
1.  Open the Xcode project or use Swift Package Manager.
2.  Ensure dependencies (`swiftapi`, `swift-project-service`, `swift-audio-marker`) are resolved.
3.  Build and run `Generate2App`.

#### Android
1.  Open the project in Android Studio.
2.  Sync Gradle files.
3.  Run the `demo` module.
4.  Configure the Run Configuration to pass launch arguments:
    *   Go to **Run > Edit Configurations**.
    *   Under **Launch Options**, add `user` and `password` extras.

#### Web
1.  Navigate to `Kmp/generate`.
2.  Run the web build task (e.g., `./gradlew :Kmp:generate:jsBrowserDevelopmentRun`).

## Key Files & Responsibilities

| File | Platform | Responsibility |
| :--- | :--- | :--- |
| `ContentView.swift` / `ContentView.kt` | iOS / Android | Main screen logic, grid rendering, toolbar, state management. |
| `GenerateViewModel.kt` | Android | ViewModel for Android state, coroutine management, file I/O. |
| `Generate.kt` | Web | Web-specific screen logic, OPFS integration. |
| `PendingCell.swift` / `PendingCell.kt` | iOS / Android | Shimmer placeholders for in-progress generations/uploads. |
| `ImageCell.swift` / `ImageCell.kt` | iOS / Android | Grid image display, like/selection logic, drag source. |
| `VideoCell.swift` / `VideoCell.kt` | iOS / Android | Grid video playback (looping/muted), full-screen preview trigger. |
| `VideoPreview.swift` / `VideoPreview.kt` | iOS / Android | Full-screen video player with audio focus management. |
| `LyricExtractor.swift` / `LyricExtractor.kt` | iOS / Android | Parses SYLT lyrics from audio files. |
| `AudioClipper.kt` | Android | Native audio trimming for video composition. |
| `Package.swift` | iOS | SPM manifest defining targets and dependencies. |

## Non-Obvious Conventions

*   **State Management:**
    *   **iOS:** Uses SwiftUI `@State` and `@Observable` classes (`LikeStore`) directly in views.
    *   **Android:** Uses a `ViewModel` (`GenerateViewModel`) to survive configuration changes. State is exposed via `mutableStateOf`/`mutableStateListOf`.
    *   **Web:** Uses `remember` and `mutableStateOf` directly in the composable.
*   **File Storage:**
    *   **iOS:** Uses `ProjectService` to save files to the app's documents directory.
    *   **Android:** Uses `ProjectService` (JNI passthrough to Rust) to save files.
    *   **Web:** Uses OPFS via `ProjectService`.
*   **Audio Trimming:**
    *   **iOS:** Uses `AVAssetExportSession` to trim audio to the specific lyric segment.
    *   **Android:** Uses `AudioClipper.kt` which decodes PCM and re-encodes to AAC-LC in an M4A container using `MediaCodec`.
*   **Drag & Drop:**
    *   **iOS:** Uses SwiftUI `draggable`/`dropDestination` to move images between lyric sections.
    *   **Android:** Uses Compose `dragAndDropSource`/`dragAndDropTarget` with a custom MIME type label (`DRAGGED_IMAGE_LABEL`).
    *   **Web:** Uses a "Move to Line" sheet picker as a fallback for drag-and-drop.
*   **Like Store:**
    *   A shared `LikeStore` (or equivalent state) is passed to all image/video cells to manage the "liked" state locally before syncing to disk.
*   **Theme:**
    *   The app uses a custom dark theme with magenta/blue accents. The colors are defined in `Theme` objects in each platform's code.