# Generate2

**Generate2** is a cross-platform UI library for generating music videos from images and audio. It provides a unified "Generate → Like → Compose" workflow implemented in **SwiftUI** (iOS), **Jetpack Compose** (Android), and **Kotlin/Compose for Web**.

The library handles the full lifecycle of media generation:
1.  **Generate:** Fan-out image generation using multiple AI models (Flux2Pro, NanoBanana2, ZImageTurbo).
2.  **Organize:** Drag-and-drop images into lyric-line sections derived from audio SYLT metadata.
3.  **Compose:** Combine selected images and audio clips into a final music video using LTX-2.

## Architecture

The project is structured as a multi-platform library with platform-specific host applications.

### Directory Structure

*   **`ContentView.swift`**: The flagship SwiftUI implementation. Contains the main `Generate` view, state management (`@State`), and UI components.
*   **`Kmp/generate/src/androidMain/`**: The Android (Jetpack Compose) port.
    *   `ContentView.kt`: Main screen logic.
    *   `GenerateViewModel.kt`: State holder and async orchestration (replaces SwiftUI `@State`/`Task`).
    *   `AudioClipper.kt`: Native Android audio trimming (MediaCodec/MediaMuxer) to replace iOS `AVAssetExportSession`.
*   **`Kmp/generate/src/webMain/`**: The Web (Kotlin/Compose) port.
    *   `Generate.kt`: Web-specific UI and logic.
    *   `LyricExtractor.kt`: Web-specific SYLT parsing.
*   **`Package.swift`**: Swift Package Manager manifest defining dependencies (`Api`, `ProjectService`, `AudioMarker`).

### Key Dependencies

The library relies on three external packages (defined in `Package.swift`):
1.  **`Api`**: Handles calls to AI models (Image generation, Video generation, LLM prompting).
2.  **`ProjectService`**: Manages local file storage (OPFS on Web, Documents directory on iOS/Android).
3.  **`AudioMarker`**: Extracts synchronized lyrics (SYLT) from audio files.

## Installation & Setup

### iOS (SwiftUI)

Add the library via Swift Package Manager:

```swift
.package(url: "https://github.com/femimarket/generate2", branch: "main")
```

Include the `Generate2` target in your app's dependencies.

### Android (Kotlin)

The Android implementation is located in `Kmp/generate`. It uses `ProjectServiceInitializer` to set up the storage path automatically. Ensure your Android app includes the necessary Compose dependencies and the `market.femi.generate` module.

### Web (Kotlin)

The Web implementation is in `Kmp/generate/src/webMain`. It relies on Kotlin/JS and Compose for Web.

## Usage

### iOS Integration

Initialize the `ContentView` in your app's root view. You must provide credentials for the API and a callback for song uploading.

```swift
import Generate2

struct AppRoot: View {
    var body: some View {
        NavigationStack {
            ContentView(
                user: "your_user",
                password: "your_password",
                onUploadSong: { await uploadSong() },
                menuItemName1: "Editorial",
                menuItemIcon1: "rectangle.stack",
                onMenuItemTapped1: {}
            )
        }
    }
}
```

### Android Integration

Initialize `ContentView` in your `MainActivity` or Compose host.

```kotlin
@Composable
fun AppRoot(user: String, password: String) {
    ContentView(
        user = user,
        password = password,
        onUploadSong = { /* Handle song upload */ },
        menuItemName1 = "Editorial",
        menuItemIcon1 = Icons.Filled.Collections,
        onMenuItemTapped1 = {}
    )
}
```

### Web Integration

```kotlin
@Composable
fun App() {
    GenerateImage(
        user = "your_user",
        password = "your_password",
        onEngineer = {}
    )
}
```

## Core Workflows

### 1. Image Generation
When the user taps "Generate", the app performs a **3-model fan-out**:
*   `Flux2Pro`
*   `NanoBanana2`
*   `ZImageTurbo`

Results are saved to `ProjectService` and displayed in the grid as they arrive. Pending states are shown as shimmer placeholders.

### 2. Lyric Extraction & Sectioning
If an audio file is loaded, the app extracts SYLT (synchronized lyrics) using `AudioMarker` (iOS) or `LyricExtractor` (Android/Web).
*   The grid automatically sections images under their corresponding lyric lines.
*   Users can drag images between sections to reassign them.
*   Users can long-press a section header to "Fill Line" (generate new images for that specific lyric).

### 3. Video Composition
1.  User taps "Make Video" and selects up to 3 hearted images.
2.  The app uses an LLM (`qwen3_6_35b_a3b`) to generate a prompt based on the selected images' prompts.
3.  The app clips the audio track to the duration of the primary image's lyric line.
4.  The app calls `ltx2_3a2v` (LTX-2) with the image, audio, and generated prompt.
5.  The resulting video is saved and added to the grid.

## Configuration

### Launch Arguments (iOS)
The standalone iOS host (`Generate2App.swift`) expects credentials via launch arguments:
*   `-user <value>`
*   `-password <value>`

### Launch Arguments (Android)
The Android demo (`MainActivity.kt`) expects credentials via intent extras:
```bash
adb shell am start -n studio.femi.demo/.MainActivity -e user <value> -e password <value>
```

## Key Files Reference

| File | Platform | Description |
| :--- | :--- | :--- |
| `ContentView.swift` | iOS | Main SwiftUI view, state, and theme. |
| `ContentView.kt` | Android | Main Compose view, theme, and top bar. |
| `GenerateViewModel.kt` | Android | State management and async logic for Android. |
| `Generate.kt` | Web | Main Compose Web view and logic. |
| `AudioClipper.kt` | Android | Native audio trimming (MediaCodec). |
| `LyricExtractor.swift` | iOS | SYLT parsing using `AudioMarker`. |
| `LyricExtractor.kt` | Android/Web | SYLT parsing using `extractSylt` API. |
| `Package.swift` | iOS | SPM manifest. |

## Theme

The library uses a consistent dark theme across platforms:
*   **Background:** Deep Navy (`#0A0A12` / `Color(0.039, 0.039, 0.071)`)
*   **Accent:** Gradient from Magenta (`#FF2BD6`) to Blue (`#3AA0FF`)
*   **Surface:** Dark Grey (`#171723`)

## Non-Obvious Conventions

*   **State Persistence:** All generated media is saved to `ProjectService`. The grid scans this directory on load to rehydrate the UI.
*   **Audio Session:** On iOS, `VideoPreview` switches `AVAudioSession` to `.playback` to bypass the silent switch. On Android, `ExoPlayer` handles audio focus automatically.
*   **Drag & Drop:** On iOS, images are dragged between sections. On Android, drag-and-drop is implemented via `DragAndDropTarget`. On Web, a "Move to Line" sheet is used as a fallback for drag-and-drop limitations.
*   **Pending States:** All background tasks (generation, upload, video creation) show a shimmer placeholder. Failed tasks show an error overlay that can be tapped to dismiss.