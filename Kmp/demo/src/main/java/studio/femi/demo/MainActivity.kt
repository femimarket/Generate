//
//  MainActivity.kt
//  demo
//
//  Standalone host for the Generate library — port of Generate2App.swift.
//  Credentials come from launch intent extras:
//
//    adb shell am start -n studio.femi.demo/.MainActivity -e user <value> -e password <value>
//
//  (In Android Studio, add the extras under Run Configuration → Launch Flags.)
//

package studio.femi.demo

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Collections
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import market.femi.api.ProjectService
import market.femi.generate.ContentView
import kotlin.coroutines.resume

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val user = requireLaunchExtra("user")
        val password = requireLaunchExtra("password")
        setContent {
            AppRoot(user = user, password = password)
        }
    }

    private fun requireLaunchExtra(name: String): String =
        intent.getStringExtra(name)
            ?: error(
                "Missing required launch extra: $name. Launch with " +
                    "`adb shell am start -n studio.femi.demo/.MainActivity -e user <u> -e password <p>`"
            )
}

@Composable
private fun AppRoot(user: String, password: String) {
    val songBridge = remember { SongBridge() }

    ContentView(
        user = user,
        password = password,
        onUploadSong = { songBridge.request() },
        menuItemName1 = "Editorial",
        menuItemIcon1 = Icons.Filled.Collections,
        onMenuItemTapped1 = {},
    )

    if (songBridge.showSheet) {
        DummySongPickerSheet(onDone = { songBridge.resolve() })
    }
}

/**
 * Real audio-file picker. Lets the user pick any audio file from the system
 * document picker; we read the bytes and save via ProjectService. SYLT-bearing
 * files retain their embedded lyrics for downstream extraction.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DummySongPickerSheet(onDone: () -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val scope = rememberCoroutineScope()
    val importer = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        // uri == null means the user backed out of the document picker; keep
        // the sheet open, matching SwiftUI's fileImporter cancel semantics.
        if (uri != null) {
            scope.launch {
                withContext(Dispatchers.IO) {
                    runCatching {
                        val name = displayName(context, uri) ?: "song.mp3"
                        context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                            ?.let { ProjectService.saveAudio(it, name) }
                    }
                }
                onDone()
            }
        }
    }

    ModalBottomSheet(onDismissRequest = onDone) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 24.dp),
        ) {
            Icon(
                Icons.Filled.MusicNote,
                contentDescription = null,
                tint = Color(0xFF9C27B0),
                modifier = Modifier.size(48.dp),
            )
            Text(
                "Pick a song",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )
            Text(
                "Choose an audio file from Files. Embedded SYLT lyrics are preserved.",
                style = MaterialTheme.typography.labelMedium,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 32.dp),
            )
            Spacer(Modifier.height(8.dp))
            Button(onClick = { importer.launch(arrayOf("audio/*")) }) {
                Text("Pick audio file")
            }
            TextButton(onClick = onDone) {
                Text("Cancel")
            }
        }
    }
}

private fun displayName(context: Context, uri: Uri): String? =
    context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }

/**
 * Async-to-sheet bridge for the dummy song picker. Resolves with Unit —
 * parent writes audio to disk itself.
 */
private class SongBridge {
    var showSheet by mutableStateOf(false)
        private set
    private var continuation: kotlinx.coroutines.CancellableContinuation<Unit>? = null

    suspend fun request() {
        suspendCancellableCoroutine { cont ->
            continuation = cont
            showSheet = true
            cont.invokeOnCancellation { continuation = null }
        }
    }

    fun resolve() {
        continuation?.let {
            continuation = null
            if (it.isActive) it.resume(Unit)
        }
        showSheet = false
    }
}
