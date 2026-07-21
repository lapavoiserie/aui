package com.aui.counter

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Construct the Haxe App instance: this initializes its @:state
        // fields, each backed by a Compose MutableState via
        // aui.state.StateBridge — reactive throughout the lifetime of
        // the Activity.
        val app = haxe.root.Counter()
        // AUI lifecycle hook: invoked once before composition, gives the
        // app a chance to bootstrap with the Android Context (extract
        // assets, set up symlinks, register JNI bridges, etc.).
        app.onAndroidContextReady(
            applicationInfo.nativeLibraryDir,
            filesDir.absolutePath,
            assets
        )
        setContent {
            MaterialTheme {
                Surface {
                    MainScreen(app)
                }
            }
        }
    }
}
