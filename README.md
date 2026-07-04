# Generate2

A cross-platform library for generating music videos from images and audio. It provides a unified UI and logic layer for **SwiftUI (iOS)**, **Jetpack Compose (Android)**, and **Kotlin/JS (Web)**, backed by a Rust core for audio processing and API communication.

The app follows a specific workflow:
1. **Generate**: Create images using AI models (Flux, NanoBanana, ZImage).
2. **Organize**: Assign images to lyric lines extracted from an uploaded song.
3. **Compose**: Select up to 3 hearted images to generate a synchronized music video.

## Architecture

The project is structured as a multi-platform library with platform-specific host applications.

### Directory Structure

*   **Root (`.`)**: Swift/SwiftUI implementation.
    *   `ContentView.swift`: The flagship screen logic, state management, and UI composition.
    *   `Generate2App.swift`: The iOS `@main` entry point and host configuration.
    *   `Package.swift`: Swift Package Manager manifest defining dependencies (`Api`, `ProjectService`, `AudioMarker`).
*   **`Kmp/`**: Kotlin Multiplatform implementation.
    *   `Kmp/demo/`: Android host application (`MainActivity.kt`) and instrumentation tests.
    *   `Kmp/generate/`: The core library code shared across Android and Web.
        *   `src/androidMain/`: Android-specific UI (`ContentView.kt`, `GenerateViewModel.kt`) and native audio clipping (`AudioClipper.kt`).
        *   `src/webMain/`: Web-specific UI (`Generate.kt`) and browser-native video handling.
        *   `src/commonMain/`: Shared models and logic (if any, though much logic is duplicated per platform in this snapshot).
*   **Shared Logic**:
    *   `LyricExtractor.swift` / `LyricExtractor.kt`: Extracts synchronized lyrics (SYLT) from audio files.
    *   `PendingCell.*` / `ImageCell.*` / `VideoCell.*`: Reusable UI components for the grid.

### Key Components

1.  **`ContentView` / `Generate`**: The central view model/view. It manages the `Phase` (Grid, Generating, Complete), `GridFilter` (All, Liked, Videos), and the state of pending operations.
2.  **`ProjectService`**: A platform-agnostic abstraction for file I/O. It handles saving generated images/videos, managing the project folder, and persisting metadata (prompts, likes).
3.  **`Api`**: Wraps calls to remote AI models.
    *   **Image Generation**: `flux2Pro`, `nanoBanana2`, `zImageTurbo`.
    *   **Video Generation**: `ltx2_3a2v` (LTX-2).
    *   **LLM Orchestration**: `qwen3_6_35b_a3b` (used to compose prompts for video generation).
4.  **`AudioClipper` (Android)**: Uses `MediaExtractor` and `MediaCodec` to trim audio tracks to specific lyric timestamps, mirroring the iOS `AVAssetExportSession` logic.

## Features

*   **Multi-Platform UI**: Identical visual design and interaction patterns across iOS, Android, and Web.
*   **Lyric-Synced Grid**: Images and videos can be dragged (or tapped on Web) into specific lyric sections.
*   **AI Video Generation**:
    1.  User uploads a song (MP3/M4A/WAV).
    2.  System extracts lyrics and timestamps.
    3.  User generates images and assigns them to lines.
    4.  User selects 3 "Liked" images.
    5.  System uses an LLM to create a video prompt based on the images' original prompts.
    6.  System generates a video using the selected images, the trimmed audio clip, and the LLM prompt.
*   **Offline-First Storage**: All generated assets are saved to the local project directory. The grid rehydrates from disk on launch.

## Installation & Setup

### Prerequisites

*   **iOS**: Xcode 15+, iOS 16+ (Swift 6).
*   **Android**: Android Studio, JDK 17+, Android SDK 34+.
*   **Web**: Node.js environment for Kotlin/JS compilation.

### Dependencies

The project relies on external Swift Packages and Kotlin libraries:

*   **Swift**:
    *   `swiftapi`: Custom API client library.
    *   `swift-project-service`: File management abstraction.
    *   `swift-audio-marker`: Audio metadata extraction.
*   **Kotlin**:
    *   `market.femi.api`: Kotlin wrapper for the Rust/FFI API.
    *   `market.femi.project-service`: Kotlin file management.
    *   `coil3`: Image loading (Android/Web).
    *   `media3`: Video playback (Android).

## Usage

### iOS

1.  Open the project in Xcode.
2.  Configure the **Generate2** scheme.
3.  Go to **Run** → **Options** → **Arguments Passed On Launch**.
4.  Add the following arguments:
    ```
    -user <your_api_username>
    -password <your_api_password>
    ```
5.  Build and Run.

### Android

1.  Open the `Kmp/demo` module in Android Studio.
2.  Configure the **MainActivity** run configuration.
3.  In **Launch Options** (or **Arguments**), add the extras:
    ```
    -e user <your_api_username>
    -e password <your_api_password>
    ```
    *Alternatively, via ADB:*
    ```bash
    adb shell am start -n studio.femi.demo/.MainActivity -e user <u> -e password <p>
    ```
4.  Build and Run.

### Web

1.  Compile the Kotlin/JS target:
    ```bash
    ./gradlew :Kmp:generate:jsBrowserDevelopmentRun
    ```
2.  The web app will serve locally. It expects the `Api` and `ProjectService` implementations to be available in the browser environment (likely via FFI or JS interop wrappers not fully detailed in the UI code).

## Workflow Guide

### 1. Start a Project
*   Tap the **"+"** button in the toolbar.
*   Select **"Generate"** to create 3 initial cinematic images using the default prompt.
*   Or select **"Upload from Photos"** to add existing images.

### 2. Add Music
*   Tap the **Song Title** in the center toolbar.
*   Select **"Pick audio file"** (iOS) or use the system picker (Android).
*   The app extracts lyrics. Images without assigned lines appear in the "Unassigned" section at the top.

### 3. Organize Images
*   **iOS**: Drag and drop images onto a lyric line header.
*   **Android**: Drag and drop images onto a lyric line header.
*   **Web**: Long-press an image to select it, then tap a lyric line to assign it.
*   Alternatively, long-press a lyric line header and select **"Make pictures for this line"** to generate new images specifically for that lyric.

### 4. Create a Video
1.  Tap the **Heart** icon on images you want to include.
2.  Tap **"Make Video"** in the toolbar.
3.  Select up to **3** hearted images.
4.  Tap **"Make video"** in the bottom shelf.
5.  The app will:
    *   Trim the audio to the duration of the first selected image's lyric line.
    *   Ask the LLM to compose a video prompt.
    *   Generate the video using LTX-2.
6.  Once complete, tap the video to watch it in full screen.

## Technical Details

### State Management
*   **iOS**: Uses SwiftUI `@State` and `@Observable` classes (`LikeStore`).
*   **Android**: Uses `ViewModel` with `mutableStateOf`/`mutableStateListOf` to survive configuration changes.
*   **Web**: Uses `remember` and `mutableStateOf` within the composable scope.

### Audio Processing
*   **Lyrics**: Extracted via `AudioMarker` (iOS) or `extractSylt` (Rust/Android/Web). The output is a JSON array of timed lines.
*   **Clipping**:
    *   **iOS**: `AVAssetExportSession` with `timeRange`.
    *   **Android**: `AudioClipper.kt` uses `MediaExtractor` and `MediaCodec` to decode PCM and re-encode to AAC-LC in an MP4 container.
    *   **Web**: Relies on `clipAudio` from the `Api` package (likely WASM-based).

### Video Generation Pipeline
1.  **Prompt Construction**: The app gathers the prompts associated with the selected images and sends them to `qwen3_6_35b_a3b` with a strict instruction to return a timestamped video prompt under 100 words.
2.  **Video Synthesis**: The `ltx2_3a2v` API is called with:
    *   `image`: The primary selected image (base64).
    *   `audio`: The trimmed audio clip (base64).
    *   `prompt`: The LLM-generated prompt.

### Theming
The app uses a consistent dark theme defined in `Theme` objects across platforms:
*   **Background**: `#0A0A12` (iOS/Android) / `rgba(0.039, 0.039, 0.071)` (Web)
*   **Accent**: Gradient from Magenta (`#FF2BD6`) to Blue (`#3AA0FF`).

## Troubleshooting

*   **Missing Launch Arguments**: The app will crash on startup if `-user` and `-password` are not provided.
*   **No Audio**: If no song is uploaded, the "Make Video" button is disabled.
*   **Video Generation Failure**: Check logs for API errors. The `PendingVideo` cell will show "Failed — tap to dismiss" if the generation fails.
*   **Web Playback**: Ensure the browser supports the video codec used by the API (typically H.264/AAC).