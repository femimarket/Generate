# Generate2

## Overview
Generate2 is a SwiftUI-based iOS application and library for AI-powered music video generation. It provides a grid-based interface for managing generated images and videos, syncing media to extracted song lyrics, and composing timestamped music videos from user-selected assets. The app is designed as a reusable library (`Generate2`) with a standalone host target for development and testing.

## Key Features
- **AI Image Generation**: One-tap generation using a 3-model fan-out (Flux2Pro, NanoBanana2, ZImageTurbo) for cinematic music video stills.
- **Lyric-Synced Grid**: Automatically extracts SYLT lyrics from uploaded audio files and groups generated media by lyric line. Supports drag-and-drop assignment to specific timestamps.
- **Video Composition**: Select up to 3 liked images, optionally extract a specific audio segment based on the primary image's lyric line, and generate a synchronized music video using LTX-2.3A2V.
- **Media Management**: Like/save assets, filter by All/Liked/Videos, and full-screen playback with automatic audio session handling.
- **Async-First UI**: Shimmer placeholders and background task groups keep the interface responsive during generation, uploads, and video rendering.

## Architecture & Key Files
- `ContentView.swift` — Core screen orchestrator. Manages app state, theme, grid layout, video composition shelf, and API orchestration.
- `Generate2App.swift` — App entry point. Handles credential injection via launch arguments and bridges the audio file picker sheet.
- `ImageCell.swift` — Grid cell for images. Handles selection badges, liking, and drag-and-drop payload creation.
- `VideoCell.swift` — Grid cell for videos. Implements auto-muted looping playback and full-screen preview triggering.
- `PendingCell.swift` — Shimmer placeholders and error states for in-flight uploads, image generation, and video rendering.
- `LyricExtractor.swift` — Parses SYLT metadata from audio files using the `AudioMarker` engine. Reconstructs lines from word-level timestamps.
- `VideoPreview.swift` — Full-screen playback view. Manages `AVAudioSession` category switching for uninterrupted viewing.
- `Package.swift` — Swift Package Manager manifest. Defines the `Generate2` library target, excludes app-specific files, and declares external dependencies.

## Installation & Build
Generate2 is distributed as a Swift Package. To build locally:
1. Clone the repository.
2. Open the project in Xcode or run `swift build` from the terminal.
3. Ensure your environment supports iOS 26+ (as declared in `Package.swift`).

## Configuration & Running
The app requires API credentials passed at launch. Configure these in your Xcode scheme's **Run > Arguments** tab:
- `-user <your_username>`
- `-password <your_password>`

The `AppRoot` view in `Generate2App.swift` parses these arguments and injects them into the `ContentView` initializer. No hardcoded credentials or config files are used.

## Usage Workflow
1. **Upload Audio**: Tap the song title in the toolbar to pick an `.mp3`, `.m4a`, or `.wav` file. SYLT lyrics are extracted automatically and displayed in the grid.
2. **Generate Images**: Tap the `+` menu and select **Generate** to create three cinematic stills using the default prompt. Alternatively, long-press a lyric line header and select **Make pictures for this line** to generate assets tied to specific lyrics.
3. **Organize & Like**: Heart images to save them. Drag and drop images onto lyric line headers to assign them to specific timestamps.
4. **Compose Video**: Tap **Make Video** in the toolbar, select up to 3 liked images, and confirm. The app extracts the corresponding audio segment, generates a timestamped prompt via an LLM, and renders the final MP4.
5. **Preview**: Tap any video cell to enter full-screen playback. The player temporarily overrides the silent switch for uninterrupted viewing.

## Non-Obvious Conventions & Details
- **Client-Side Lyric Windows**: Until server-side forced alignment is implemented, the client assigns equal 6-second windows to each extracted lyric line as a placeholder (`LyricExtractor.swift`).
- **Metadata Storage**: Generated files are saved with `gen-<UUID>.<ext>` or `upload-<UUID>.jpg` naming conventions. Prompts, model names, and lyric subjects are persisted alongside the files via `ProjectService`.
- **State Management**: The app avoids traditional ViewModels. All screen state lives in `@State` properties on the `Generate` view, with `LikeStore` (`@MainActor @Observable`) shared across cells.
- **Audio Session Handling**: `VideoPreview` switches `AVAudioSession` to `.playback` on appear and reverts to `.ambient` on dismiss, ensuring the video plays even if the device is on silent.
- **Grid Filtering**: The `GridFilter` enum (`all`, `liked`, `videos`) dynamically shows/hides content. Orphaned videos (unassigned to lyric lines) appear at the bottom of the grid.
- **Drag & Drop**: Uses the `Transferable` protocol (`DraggedImage`) to move images between sections. Dropping an image on a lyric header updates both the UI index and the file's metadata subject.
- **Video Generation Pipeline**: The composition flow extracts a precise audio segment matching the primary image's lyric line, uses `Qwen3` to generate a concise timestamped prompt from the selected image prompts, and finally calls `LTX-2.3A2V` to render the MP4.

## Dependencies
- `Api` (via `swiftapi` package, branch `main`) — Wraps AI model endpoints.
- `ProjectService` (via `swift-project-service` package, branch `main`) — Local file I/O, metadata storage, and liking state.
- `AudioMarker` (>= 0.1.1, via `swift-audio-marker` package) — SYLT lyric extraction engine.