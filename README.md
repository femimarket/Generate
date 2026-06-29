# Generate2

## Overview
Generate2 is a SwiftUI-based iOS media generation library and companion application designed for creating lyric-synced music videos from AI-generated images. It provides a polished, dark-themed grid interface for generating, organizing, liking, and composing visual content synchronized to audio lyrics. The package is structured to be embedded in host applications, with a standalone demo host included for local testing.

## Features
- **Lyric-Synced Grid**: Automatically parses embedded SYLT lyrics from audio files and organizes generated images/videos into per-lyric-line sections.
- **Multi-Model Image Generation**: Fan-out to three AI image models (Flux2Pro, NanoBanana2, ZImageTurbo) for default generation or per-line "fill" actions.
- **Video Composition**: Select up to three liked images to generate a timestamped music video using a chat model for prompt engineering and a dedicated video generation API.
- **Interactive Grid**: Filter by All/Liked/Videos, drag-and-drop images between lyric sections, and manage pending generation states with shimmer placeholders.
- **Seamless Playback**: Auto-muted looping video cells in the grid, with a full-screen preview that temporarily overrides audio session categories for uninterrupted playback.

## Architecture & Key Files
The project is structured as a Swift Package (`Generate2`) that can be embedded in host apps, with a standalone demo host for local testing.

- `ContentView.swift`: The flagship screen. Orchestrates the entire UI state, grid rendering, toolbar, photo picker, and generation workflows. Contains theme definitions, local data models (`SongLine`, `GeneratedVideo`, `PendingVideo`, etc.), and the `LikeStore` observable.
- `Generate2App.swift`: Standalone host application. Bridges launch arguments for credentials, manages the song picker sheet, and instantiates `ContentView`.
- `ImageCell.swift` & `VideoCell.swift`: Grid components. Handle async image loading, selection badges, heart/like toggles, drag payloads, and video playback.
- `LyricExtractor.swift`: Parses audio files using `AudioMarker` to extract word-level SYLT timestamps, grouping them into `SongLine` objects for UI synchronization.
- `PendingCell.swift`: Shimmer placeholders and state management for in-flight image uploads, AI generations, and video compositions.
- `VideoPreview.swift`: Full-screen video player. Manages `AVAudioSession` category switching (`.playback` → `.ambient`) to ensure videos play at volume when opened.
- `Package.swift`: Swift Package manifest. Defines the `Generate2` library target, excludes app-specific files, and declares external dependencies.

## Installation & Setup
Generate2 is distributed as a Swift Package. To integrate it into your own iOS project:

1. Add the package to your Xcode project or `Package.swift`:
   ```swift
   .package(url: "https://github.com/femimarket/generate2", branch: "main")
   ```
2. Link the `Generate2` library to your target.
3. Ensure your host app has the required capabilities and dependencies (see below).

**Standalone Testing**: Clone the repository and open the project in Xcode. The `Generate2App.swift` target serves as a ready-to-run demo. Launch arguments must be provided via the Xcode scheme:
- `-user <your_api_username>`
- `-password <your_api_password>`

## Usage & Workflow
1. **Load Audio**: Tap the song title in the toolbar to pick an audio file. The app extracts embedded SYLT lyrics and prepares the grid for lyric-synced organization.
2. **Generate Images**: Tap the `+` menu → `Generate` to fan out three AI-generated images. Alternatively, long-press a lyric line header and select "Make pictures for this line" to generate images scoped to that specific lyric.
3. **Organize & Like**: Heart images to save them. Drag and drop images into lyric line sections to sync them. Unassigned images appear at the top of the grid.
4. **Compose Video**: Tap "Make Video" in the toolbar, select up to three hearted images, and confirm. The app:
   - Extracts a 10-second audio segment matching the primary image's lyric line.
   - Sends image prompts to a chat model (`qwen3_6_35b_a3b`) to generate a timestamped video prompt.
   - Passes the primary image, audio segment, and prompt to the video generation API (`ltx2_3a2v`).
   - Saves the resulting MP4 and syncs it to the corresponding lyric line.
5. **Preview**: Tap any video cell to open a full-screen player. Tap the close button to return to the grid.

## Configuration & Conventions
- **Authentication**: Credentials are passed directly to `ContentView` via `user` and `password` parameters. Every `Api` call includes these for user/password auth.
- **Local Storage**: All generated assets, prompts, models, and metadata are managed by `ProjectService`. Files are saved with `gen-<UUID>.<ext>` naming, and metadata is attached via `ProjectService.saveFile(..., prompt:, model:, subject:)`.
- **State Management**: The UI relies on SwiftUI's `@State` and `@Observable` (Observation framework). `LikeStore` is a shared `@MainActor @Observable` class reused across all grid cells.
- **Audio Session Handling**: `VideoPreview` temporarily switches `AVAudioSession` to `.playback` on appearance and reverts to `.ambient` on dismissal. This ensures videos play at volume when explicitly opened, while keeping the rest of the app silent-friendly.
- **Lyric Syncing**: `LyricExtractor` splits word-level SYLT data into lines. When lyrics are loaded, unassigned images are automatically distributed across lyric lines in round-robin fashion.
- **Pending State Scoping**: Generation and video pending cells track a `lineIndex` property. When lyrics are extracted, pending items without a line index are assigned to unassigned images, ensuring the grid remains coherent during background tasks.

## Dependencies
Generate2 relies on three external Swift packages:
- `swiftapi` (`Api`): Handles image, video, and chat model requests.
- `swift-project-service` (`ProjectService`): Manages local file persistence, metadata attachment, and like tracking.
- `swift-audio-marker` (`AudioMarker`): Parses audio files and extracts synchronized lyrics (SYLT).

## Requirements
- iOS 26.0+
- Swift 6.2+
- Xcode 16+ (for Swift concurrency and Observation framework)
- Network access for AI API calls
- Photos and Files app permissions for media import