//
//  ProjectServiceInitializer.kt
//  AndroidGenerate3
//
//  Points Rust's ProjectService at the app's filesDir before any UI runs, as
//  the Api contract requires. Registered in this library's manifest, so every
//  consumer gets it automatically.
//

package studio.femi.androidgenerate3

import android.content.Context
import androidx.startup.Initializer
import market.femi.api.ProjectService

class ProjectServiceInitializer : Initializer<Unit> {
    override fun create(context: Context) {
        ProjectService.initDocuments(context.filesDir.absolutePath)
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}
