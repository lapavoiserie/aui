package aui.state

import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf

/**
 * JVM/Kotlin side of the AUI Haxe→Compose state bridge.
 *
 * AUI's `aui.state.State<T>` (Haxe class) is backed at runtime by a Compose
 * `MutableState<T>`. Reads through `MutableState.value` are tracked by the
 * Compose snapshot system, so any composable that reads a state via
 * `state.get()` automatically recomposes when another piece of code calls
 * `state.set(...)` — including code paths that originate in pure Haxe JVM
 * bytecode (e.g. lifted closures from `Button("...", () -> { ... })`).
 *
 * Haxe code never imports Compose types directly; it only sees the opaque
 * `Dynamic` reference held in `State<T>` and routes reads/writes through
 * these static methods. This keeps the Haxe state class portable.
 */
object StateBridge {
    // All return types are the loose `Any` (`java.lang.Object`) so the JVM
    // method signatures match what Haxe's extern declares (Dynamic → Object).
    // Internally we still know they hold MutableState<Any?>; the cast happens
    // on read/write.

    @JvmStatic
    fun create(initialValue: Any?): Any = mutableStateOf(initialValue)

    @JvmStatic
    fun read(state: Any): Any? = @Suppress("UNCHECKED_CAST") (state as MutableState<Any?>).value

    @JvmStatic
    fun write(state: Any, value: Any?) {
        @Suppress("UNCHECKED_CAST") (state as MutableState<Any?>).value = value
    }
}
