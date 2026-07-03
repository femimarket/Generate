# Generate2

**Generate2** is a cross-platform (iOS & Android) SwiftUI/Compose library for generating music videos from user-uploaded audio and AI-generated imagery. It provides a complete UI flow: upload a song, generate images using multiple AI models, organize them by lyric line, and compose them into a synchronized music video.

The project is structured as a reusable library (`Generate2` for iOS, `AndroidGenerate3` for Android) with standalone demo hosts for each platform.

## Features

- **AI Image Generation**: Fan-out generation using three models (`Flux2Pro`, `NanoBanana2`, `ZImageTurbo`) for default generation or per-lyric-line generation.
- **Lyric Synchronization**: Automatically extracts SYLT timestamps from audio files to organize generated images into lyric-based sections.
- **Video Composition**: Composes selected images into a video using `Ltx23A2V`, with audio trimming based on the primary image's lyric timing.
- **Cross-Platform UI**: Identical logic and visual design implemented in SwiftUI (iOS) and Jetpack Compose (Android).
- **Interactive Grid**: Drag-and-drop images between lyric sections, like/save images, and filter by status (All, Liked, Videos).
- **Background Processing**: Handles pending states for uploads, generations, and video rendering with shimmer placeholders.

## Architecture

The project consists of two main platform implementations that share the same logical flow:

### iOS Implementation
- **Library**: `Generate2` (Swift Package).
- **Entry Point**: `ContentView.swift` acts as the root view, delegating to the `Generate` struct.
- **State Management**: Uses SwiftUI `@State` and `@Observable` (`LikeStore`) for local state.
- **Key Files**:
  - `ContentView.swift`: Main screen logic, grid rendering, and video composition.
  - `LyricExtractor.swift`: Parses SYLT metadata from audio files.
  - `PendingCell.swift` / `ImageCell.swift` / `VideoCell.swift`: Grid cell components.

### Android Implementation
- **Library**: `AndroidGenerate3` (Kotlin/Compose).
- **Entry Point**: `ContentView.kt` mirrors the iOS root view.
- **State Management**: Uses `ViewModel` (`GenerateViewModel.kt`) to survive configuration changes.
- **Key Files**:
  - `ContentView.kt`: Main screen logic and Compose UI.
  - `GenerateViewModel.kt`: All business logic, async tasks, and state.
  - `AudioClipper.kt`: Native Android audio trimming (equivalent to iOS `AVAssetExportSession`).
  - `LyricExtractor.kt`: Parses SYLT metadata via Rust bindings.

### Shared Logic
- **ProjectService**: A shared abstraction (Rust-based) for file I/O, saving generated assets, and managing the project directory.
- **Api**: A shared abstraction for calling external AI models (Image, Video, Chat).

## Installation & Setup

### Prerequisites
- **iOS**: Xcode 15+, iOS 16+
- **Android**: Android Studio, API 24+

### iOS Setup
1. Clone the repository.
2. Open the Xcode project or use Swift Package Manager.
3. Add dependencies:
   - `swiftapi` (API client)
   - `swift-project-service` (File management)
   - `swift-audio-marker` (Lyric extraction)
4. Configure launch arguments for the demo app:
   - `-user <username>`
   - `-password <password>`

### Android Setup
1. Open the `Kmp` folder in Android Studio.
2. Ensure the `market.femi.api` module is available (contains Rust JNI bindings).
3. Configure launch intent extras for the demo app:
   - `user <username>`
   - `password <password>`

## Usage

### 1. Initialize the View
**iOS:**
```swift
ContentView(
    user: "your_user",
    password: "your_password",
    onUploadSong: { await uploadSong() },
    menuItemName1: "Editorial",
    menuItemIcon1: "rectangle.stack",
    onMenuItemTapped1: {}
)
```

**Android:**
```kotlin
ContentView(
    user = "your_user",
    password = "your_password",
    onUploadSong = { uploadSong() },
    menuItemName1 = "Editorial",
    menuItemIcon1 = Icons.Filled.Collections,
    onMenuItemTapped1 = {}
)
```

### 2. Upload a Song
- Tap the song title in the toolbar.
- Select an audio file (`.mp3`, `.m4a`, `.wav`).
- The app extracts SYLT lyrics and organizes the grid into lyric sections.

### 3. Generate Images
- Tap the `+` button to generate 3 images using `Flux2Pro`, `NanoBanana2`, and `ZImageTurbo`.
- Alternatively, long-press a lyric line header and select "Make pictures for this line" to generate images specific to that lyric.

### 4. Organize & Like
- Drag and drop images between lyric sections.
- Tap the heart icon to like/save images.
- Filter the grid by "All", "Liked", or "Videos".

### 5. Create a Video
- Tap "Make Video" in the toolbar.
- Select up to 3 liked images.
- The app composes a video using the primary image's lyric timing and audio clip.
- View the result in the grid or full-screen.

## Key Conventions

- **Pending States**: All async operations (uploads, generations, video rendering) show a shimmer placeholder in the grid. Failed states show an error overlay that can be tapped to dismiss.
- **Lyric Indexing**: Images are assigned to lyric lines based on SYLT timestamps. Unassigned images appear in an "unassigned" section at the top.
- **Audio Trimming**: When creating a video, the app trims the audio to a 10-second window starting at the primary image's lyric start time.
- **Theme**: The app uses a dark theme with magenta/blue accents. Colors are defined in `Theme` objects in both iOS and Android implementations.

## File Structure

```
.
├── ContentView.swift          # iOS main screen
├── LyricExtractor.swift       # iOS SYLT parsing
├── PendingCell.swift          # iOS pending state cells
├── ImageCell.swift            # iOS image grid cell
├── VideoCell.swift            # iOS video grid cell
├── VideoPreview.swift         # iOS full-screen video player
├── Generate2App.swift         # iOS demo host
├── Package.swift              # iOS SPM manifest
├── Kmp/
│   ├── demo/                  # Android demo app
│   │   └── src/main/java/studio/femi/demo/
│   │       ├── MainActivity.kt
│   │       └── ...
│   └── generate/              # Android library
│       └── src/androidMain/kotlin/studio/femi/androidgenerate3/
│           ├── ContentView.kt
│           ├── GenerateViewModel.kt
│           ├── AudioClipper.kt
│           ├── LyricExtractor.kt
│           ├── PendingCell.kt
│           ├── ImageCell.kt
│           ├── VideoCell.kt
│           └── VideoPreview.kt
```

## Dependencies

- **iOS**:
  - `swiftapi`: API client for AI models.
  - `swift-project-service`: File management.
  - `swift-audio-marker`: Audio metadata extraction.
- **Android**:
  - `market.femi.api`: Rust JNI bindings for API and ProjectService.
  - `androidx.media3`: Media playback.
  - `coil3`: Image loading.