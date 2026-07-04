# Generate2

**Generate2** is a cross-platform library that provides a "Generate" screen for creating music videos from user-uploaded songs and AI-generated images. It implements a complete workflow: upload a song → generate images → organize them by lyric line → compose a video.

The library is available for **iOS** (SwiftUI), **Android** (Compose), and **Web** (Kotlin/JS).

## Features

- **AI Image Generation**: Fan-out generation using Flux2Pro, NanoBanana2, and ZImageTurbo.
- **Lyric Sync**: Extracts SYLT lyrics from audio files to organize generated images into sections.
- **Video Composition**: Composes music videos using LTX-2, driven by prompts generated via Qwen.
- **Cross-Platform**: Identical UI/UX and logic across iOS, Android, and Web.
- **Local State Management**: Handles pending states, likes, and file persistence via `ProjectService`.

## Architecture

The project is structured as a multi-platform library with platform-specific host apps.

### Directory Structure

- `ContentView.swift`: The flagship SwiftUI screen. Contains the main `Generate` view, theme, and local models.
- `Kmp/generate/`: Kotlin Multiplatform implementation.
  - `src/androidMain/`: Android Compose UI and ViewModel.
  - `src/webMain/`: Web Compose UI.
- `Kmp/demo/`: Standalone host apps for iOS and Android to test the library.
- `Package.swift`: Swift Package Manager manifest defining dependencies (`Api`, `ProjectService`, `AudioMarker`).

### Key Components

1.  **ContentView / Generate**: The root view. Manages the grid, toolbar, and video composition shelf.
2.  **GridView**: Renders a 3-column grid of images and videos. Supports filtering (All, Liked, Videos) and sectioning by lyric lines.
3.  **LikeStore**: A shared observable store for tracking liked images/videos.
4.  **MakeVideoShelf**: A bottom sheet that appears when selecting images for video composition.
5.  **ProjectService**: A platform-agnostic service for saving/loading files and metadata.

## Installation

### iOS (SwiftUI)

Add the library to your Xcode project using Swift Package Manager:

```swift
.package(url: "https://github.com/femimarket/generate2", branch: "main")
```

Include the `Generate2` target in your app's dependencies.

### Android (Compose)

Add the library to your `build.gradle.kts`:

```kotlin
dependencies {
    implementation("market.femi:generate:1.0.0")
}
```

### Web (Kotlin/JS)

Add the library to your `build.gradle.kts`:

```kotlin
dependencies {
    implementation("market.femi:generate:1.0.0")
}
```

## Usage

### iOS

Initialize the `ContentView` in your app's root view:

```swift
import Generate2

struct AppRoot: View {
    var body: some View {
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
```

### Android

Initialize the `ContentView` in your Compose activity:

```kotlin
import market.femi.generate.ContentView

@Composable
fun AppRoot(user: String, password: String) {
    ContentView(
        user = user,
        password = password,
        onUploadSong = { uploadSong() },
        menuItemName1 = "Editorial",
        menuItemIcon1 = Icons.Filled.Collections,
        onMenuItemTapped1 = {}
    )
}
```

### Web

Initialize the `GenerateImage` composable:

```kotlin
@Composable
fun AppRoot(user: String, password: String) {
    GenerateImage(
        user = user,
        password = password,
        onEngineer = {}
    )
}
```

## Configuration

- **Credentials**: Pass `user` and `password` to the `ContentView`/`GenerateImage` constructor. These are used for all API calls.
- **Song Upload**: Provide an `onUploadSong` callback that handles the platform-specific file picker and saves the audio file via `ProjectService`.
- **Menu Item**: Customize the third menu item in the toolbar with `menuItemName1`, `menuItemIcon1`, and `onMenuItemTapped1`.

## Workflow

1. **Upload Song**: Tap the song title in the toolbar to upload an audio file.
2. **Generate Images**: Tap the `+` button to generate 3 images using the default prompt.
3. **Like Images**: Tap the heart icon to save images.
4. **Make Video**: Tap "Make Video" to select up to 3 liked images and compose a video.
5. **Organize**: Drag and drop images into lyric line sections (iOS/Android) or use the context menu (Web).

## Dependencies

- `Api`: For AI model calls (Flux2Pro, NanoBanana2, ZImageTurbo, Qwen, LTX-2).
- `ProjectService`: For file persistence and metadata management.
- `AudioMarker`: For SYLT lyric extraction (iOS).

## License

This project is proprietary. All rights reserved.