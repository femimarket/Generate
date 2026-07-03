# Generate2

**Generate2** is a cross-platform (iOS & Android) library and application for generating AI-powered music videos. It allows users to upload a song, automatically extract timed lyrics, generate AI images for each lyric line, and compose those images into a synchronized music video.

The project is built as a shared UI library with native hosts for both platforms:
- **iOS**: SwiftUI (`ContentView.swift`)
- **Android**: Jetpack Compose (`ContentView.kt`)

## Features

- **AI Image Generation**: Generates cinematic stills using multiple models (Flux2Pro, NanoBanana2, ZImageTurbo) based on lyrics or prompts.
- **Lyric Extraction**: Automatically parses SYLT timestamps from uploaded audio files to sync images with the song.
- **Video Composition**: Composes selected images into a video using LTX-2.3A2V, with AI-generated prompts via Qwen3.
- **Cross-Platform Sync**: Identical UI/UX and logic across iOS and Android.
- **Interactive Grid**: Drag-and-drop images between lyric lines, like/save content, and filter views.

## Architecture

The project follows a **Shared Logic, Native UI** pattern. The core state management and API interactions are mirrored in both Swift and Kotlin, while the UI is implemented natively.

### Key Components

1.  **`ContentView` / `ContentView.kt`**: The main screen. Manages the grid of images/videos, the toolbar, and the "Make Video" flow.
2.  **`GenerateViewModel` / `@State`**:
    -   **iOS**: State is managed via SwiftUI `@State` properties within `ContentView`.
    -   **Android**: State is managed in `GenerateViewModel` to survive configuration changes.
3.  **`ProjectService`**: A shared abstraction (via Rust JNI on Android and Swift Package on iOS) for file I/O. It handles saving generated images/videos, managing the project folder, and persisting metadata (likes, prompts).
4.  **`Api`**: A shared client for calling remote AI models.
    -   **Image Models**: `flux2Pro`, `nanoBanana2`, `zImageTurbo`.
    -   **Video Model**: `ltx2_3a2v`.
    -   **LLM**: `qwen3_6_35b_a3b` (used to generate video prompts from image prompts).
5.  **`LyricExtractor`**: Extracts timed lyrics from audio files.
    -   **iOS**: Uses `AudioMarker` framework.
    -   **Android**: Uses a Rust core via JNI (`extractSylt`).
6.  **`AudioClipper`** (Android Only): Trims audio segments for video generation using Android's `MediaCodec` and `MediaMuxer`.

### File Structure

```text
.
├── ContentView.swift          # iOS Main Screen & Logic
├── Generate2App.swift         # iOS App Entry Point
├── Package.swift              # Swift Package Dependencies
├── Kmp/
│   ├── demo/                  # Android Demo App
│   │   └── src/main/java/studio/femi/demo/
│   │       ├── MainActivity.kt # Android Entry Point
│   │       └── ...
│   └── generate/              # Android Library
│       └── src/androidMain/kotlin/studio/femi/androidgenerate3/
│           ├── ContentView.kt       # Android Main Screen & Logic
│           ├── GenerateViewModel.kt # State Management
│           ├── ImageCell.kt         # Grid Image Component
│           ├── VideoCell.kt         # Grid Video Component
│           ├── PendingCell.kt       # Loading/Error Placeholders
│           ├── AudioClipper.kt      # Audio Trimming Logic
│           ├── LyricExtractor.kt    # Lyric Parsing Logic
│           └── ProjectServiceInitializer.kt # Rust Init
└── ... (Shared UI components like Shimmer, Theme, etc.)
```

## Installation & Setup

### Prerequisites
- **iOS**: Xcode 15+, iOS 16+
- **Android**: Android Studio, API 26+
- **Rust**: Required for Android JNI bindings (`ProjectService` and `LyricExtractor`).

### iOS Setup
1.  Clone the repository.
2.  Open the Xcode project.
3.  The project uses Swift Packages. Ensure dependencies are resolved:
    -   `swiftapi`
    -   `swift-project-service`
    -   `swift-audio-marker`
4.  **Launch Arguments**: The app requires credentials to be passed via launch arguments.
    -   Go to **Product > Scheme > Edit Scheme... > Run > Arguments**.
    -   Add: `-user <your_username>` and `-password <your_password>`.

### Android Setup
1.  Open the project in Android Studio.
2.  Sync Gradle files.
3.  **Launch Arguments**: The demo app expects credentials via intent extras.
    -   **ADB**: `adb shell am start -n studio.femi.demo/.MainActivity -e user <u> -e password <p>`
    -   **Android Studio**: Add `-e user <u> -e password <p>` to the **Run Configuration > Launch Flags**.

## Usage

### 1. Upload a Song
-   Tap the song title in the toolbar (or "No song" if none is set).
-   Select an audio file (MP3, M4A, WAV) from your device.
-   The app automatically extracts timed lyrics (SYLT) and displays them in the grid.

### 2. Generate Images
-   Tap the **"+"** button in the toolbar.
-   Select **"Generate"** to create 3 images based on a default cinematic prompt.
-   Alternatively, long-press a lyric line header and select **"Make pictures for this line"** to generate images specific to that lyric.
-   Generated images appear in the grid with a shimmer effect while processing.

### 3. Organize & Like
-   **Like**: Tap the heart icon on any image to save it. Liked images can be used for video generation.
-   **Drag & Drop**: Drag images between lyric line sections to reassign them.
-   **Filter**: Use the top bar to filter by **All**, **Liked**, or **Videos**.

### 4. Create a Video
-   Tap **"Make Video"** in the toolbar.
-   Select up to 3 liked images.
-   Tap **"Make video"** in the bottom shelf.
-   The app will:
    1.  Extract the audio segment corresponding to the primary image's lyric.
    2.  Generate a prompt using Qwen3 based on the selected images.
    3.  Generate the video using LTX-2.3A2V.
    4.  Display the result in the grid.

## Technical Details

### State Management
-   **iOS**: Uses SwiftUI `@State` and `@Observable` for reactive UI updates.
-   **Android**: Uses `ViewModel` with `mutableStateOf` and `mutableStateListOf` for Compose state.

### Image Generation
-   The app uses a **fan-out** strategy, calling three different models (`Flux2Pro`, `NanoBanana2`, `ZImageTurbo`) simultaneously for the default generation.
-   Results are saved to the project folder with metadata (prompt, model, subject).

### Audio Processing
-   **Lyrics**: Extracted via `AudioMarker` (iOS) or Rust core (Android).
-   **Trimming**: On Android, `AudioClipper` uses `MediaCodec` to decode and re-encode audio segments to AAC-LC in an MP4 container. On iOS, `AVAssetExportSession` is used.

### Theming
-   Both platforms use a consistent dark theme with magenta and blue accents.
-   **iOS**: `Theme` enum in `ContentView.swift`.
-   **Android**: `Theme` object in `ContentView.kt`.

## Contributing

1.  Fork the repository.
2.  Create a feature branch.
3.  Ensure changes are mirrored in both iOS and Android implementations.
4.  Submit a pull request.

## License

This project is proprietary. All rights reserved.