# Generate2

**Generate2** is a SwiftUI-based iOS application and library for creating music videos from user-uploaded songs and AI-generated imagery. It provides a grid-based interface to manage images, derive variations, and compose timestamped videos synchronized with song lyrics.

## Features

*   **Music-Driven Workflow**: Upload an audio file (MP3, M4A, WAV) to extract embedded SYLT lyrics. The UI organizes generated content into sections based on lyric lines.
*   **AI Image Generation**: Generate images using a 3-model fan-out (Flux2Pro, NanoBanana2, ZImageTurbo) with cinematic prompts. Supports deriving new images from existing ones.
*   **Video Composition**: Select up to three liked images to generate a synchronized music video using LTX-2.3A2V. The system automatically extracts relevant audio segments based on the assigned lyric line.
*   **Lyric Synchronization**: Images and videos can be dragged and dropped onto specific lyric line sections to sync them with the song's timeline.
*   **Interactive Grid**: Filter content by All, Liked, or Videos. Use a "Make Video" shelf to compose content.
*   **Dark Mode UI**: Custom theme with accent gradients and shimmer placeholders for loading states.

## Architecture

The project is structured as a Swift Package that can be used as a library or run as a standalone app.

### Key Components

*   **`ContentView.swift`**: The flagship screen. Contains the main `Generate` view, state management (`@State`), theme definitions, and the logic for the grid, toolbar, and video creation shelf.
*   **`Generate2App.swift`**: The `@main` entry point for the standalone app. Handles launch arguments for credentials and the song upload sheet.
*   **`ImageCell.swift` & `VideoCell.swift`**: Individual grid items. Handles display, liking, selection for video composition, and drag-and-drop functionality.
*   **`PendingCell.swift`**: Shimmer placeholders for in-flight operations (image generation, video rendering, uploads).
*   **`LyricExtractor.swift`**: Parses SYLT metadata from audio files using the `AudioMarker` library to create `SongLine` objects.
*   **`VideoPreview.swift`**: Full-screen video player that temporarily switches the audio session to `.playback` to bypass the silent switch.

### Dependencies

The project relies on three external Swift packages:
1.  **`swiftapi`**: Handles API calls to image generation models (Flux, NanoBanana, ZImage) and video generation (LTX-2).
2.  **`swift-project-service`**: Manages local file storage, metadata persistence (likes, prompts, subjects), and URL resolution.
3.  **`swift-audio-marker`**: Extracts synchronized lyrics (SYLT) from audio files.

## Installation & Setup

### Prerequisites
*   iOS 26+ (as defined in `Package.swift`)
*   Swift 6.2+

### Building the Package
Clone the repository and build using Swift Package Manager:

```bash
swift build
```

### Running the Standalone App
To run the app locally, you must provide authentication credentials via Xcode Scheme launch arguments.

1.  Open the project in Xcode.
2.  Go to **Product > Scheme > Edit Scheme...**.
3.  Select **Run** > **Arguments** tab.
4.  Add the following arguments:
    *   `-user` followed by your username.
    *   `-password` followed by your password.
    *   *Example*: `-user` `admin` `-password` `secret123`

## Usage Guide

### 1. Initial Setup
When the app launches, it loads any previously generated images and videos from the project service. If an audio file exists, it attempts to extract lyrics.

### 2. Uploading a Song
1.  Tap the **Song Title** slot in the toolbar (center).
2.  Select **Upload Song** or pick an audio file from the Files app.
3.  The app extracts lyrics and creates sections in the grid for each lyric line.

### 3. Generating Images
1.  Tap the **Plus (+)** button in the toolbar.
2.  Select **Generate** to create 3 new images using the default cinematic prompt.
3.  Alternatively, long-press an existing image to derive variations (if supported by the specific grid interaction).
4.  Pending generations appear as shimmer cells.

### 4. Liking and Organizing
1.  Tap the **Heart** icon on any image to save it.
2.  Use the **Filter Bar** (All/Liked/Videos) to view specific content.
3.  **Drag and Drop**: Drag an image onto a lyric line section header to assign it to that timestamp.

### 5. Creating a Video
1.  Tap **Make Video** in the toolbar (requires at least one liked image).
2.  Select up to 3 liked images.
3.  The **Make Video Shelf** appears at the bottom.
4.  Tap **Make Video**. The app will:
    *   Extract the audio segment corresponding to the primary image's lyric line.
    *   Generate a prompt for the video model based on the selected images.
    *   Render the video using LTX-2.3A2V.
5.  The completed video appears in the grid.

## Configuration

### Theme Customization
The app uses a custom `Theme` enum in `ContentView.swift` for colors. Key colors include:
*   `background`: Dark blue-black (`#060612`)
*   `accent`: Gradient from Magenta (`#FF2BD6`) to Blue (`#3A9FE6`)

### API Credentials
Credentials are passed directly to the `ContentView` initializer. In the standalone app, these are read from launch arguments. In library usage, pass them via the `ContentView` init:

```swift
ContentView(
    user: "your_user",
    password: "your_password",
    onUploadSong: { /* handle upload */ },
    menuItemName1: "Custom Menu",
    menuItemIcon1: "star",
    onMenuItemTapped1: { /* handle action */ }
)
```

## File Structure

```text
.
├── ContentView.swift       # Main screen, state, theme, grid logic
├── Generate2App.swift      # App entry point, song picker sheet
├── ImageCell.swift         # Image grid cell, selection logic
├── VideoCell.swift         # Video grid cell, playback integration
├── PendingCell.swift       # Shimmer/Loading placeholders
├── LyricExtractor.swift    # SYLT parsing logic
├── Package.swift           # Swift Package Manifest
└── Assets.xcassets         # (Excluded from library target)
```

## Troubleshooting

*   **Missing Launch Arguments**: The app will crash with `preconditionFailure` if `-user` or `-password` are missing in standalone mode.
*   **No Lyrics Extracted**: Ensure the uploaded audio file contains embedded SYLT metadata. The `LyricExtractor` returns an empty array if no lyrics are found.
*   **Video Generation Fails**: Check that the primary image assigned to the video has a valid lyric line index. The system attempts to extract a specific audio segment; if the index is missing, it falls back to the full audio.