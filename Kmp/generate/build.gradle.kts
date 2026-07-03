import org.jetbrains.kotlin.gradle.ExperimentalWasmDsl
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.android.kotlin.multiplatform.library)
    alias(libs.plugins.kotlin.compose)
    id("maven-publish")
}

group = "io.github.femimarket"
version = project.findProperty("libraryVersion") as String? ?: "local-dev"

kotlin {
    androidLibrary {
        namespace = "studio.femi.androidgenerate3"
        compileSdk = 37
        minSdk = 33

        compilerOptions {
            jvmTarget = JvmTarget.JVM_11
        }
    }
    js {
        browser()
        useEsModules()
    }
    @OptIn(ExperimentalWasmDsl::class)
    wasmJs {
        browser()
    }

    sourceSets {
        commonMain.dependencies {
            api(libs.femi.api)
        }
        // No shared UI: commonMain stays empty. Each platform ships its own
        // full implementation of the Generate screen.
        androidMain.dependencies {
            // ProjectService / model calls — exposed to consumers (the demo saves audio itself).

            implementation(project.dependencies.platform(libs.androidx.compose.bom))
            implementation(libs.androidx.activity.compose)
            implementation(libs.androidx.compose.material3)
            implementation(libs.androidx.compose.ui)
            implementation(libs.androidx.compose.ui.graphics)
            implementation(libs.androidx.compose.material.icons.extended)
            implementation(libs.androidx.core.ktx)
            implementation(libs.androidx.lifecycle.runtime.ktx)
            implementation(libs.androidx.lifecycle.runtime.compose)
            implementation(libs.androidx.lifecycle.viewmodel.compose)
            implementation(libs.androidx.media3.exoplayer)
            implementation(libs.androidx.media3.ui)
            implementation(libs.androidx.startup.runtime)
            implementation(libs.coil.compose)
            implementation(libs.kotlinx.serialization.json)
        }
        webMain.dependencies {}
    }
}

// The Kotlin Multiplatform plugin auto-creates the publications (one per target + a root);
// we just point them at GitHub Packages, matching Api2/Kmp.
// Publish with: ./gradlew publish -PlibraryVersion=<x.y.z>
publishing {
    repositories {
        maven {
            name = "GitHubPackages"
            url = uri("https://maven.pkg.github.com/femimarket/AndroidGenerate")
            credentials {
                username = providers.gradleProperty("gpr.user").orNull
                    ?: System.getenv("GITHUB_ACTOR")
                password = providers.gradleProperty("gpr.key").orNull
                    ?: System.getenv("GITHUB_TOKEN")
            }
        }
    }
}
