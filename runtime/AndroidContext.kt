package aui.runtime

import android.content.Context

/**
 * The application Context, for code that needs one and is not an Activity.
 *
 * A `kui` capability is plain Haxe with a native payload: it has no Activity,
 * no Application subclass and no way to ask Android for a Context. Almost every
 * Android API needs one — the Wear Data Layer, connectivity, sensors — so
 * something has to hold it, and only the backend knows when it exists.
 *
 * Set once, from the same place the generated entry point tells the Haxe
 * application about its context. The *application* context, never an Activity:
 * an Activity outlives nothing, and a capability that captured one would hold a
 * destroyed screen across a rotation — the exact leak `aui.App.release` exists
 * to close.
 *
 * Null before the first Activity runs. A capability reading it must say what it
 * does with nothing rather than assume: a widget process, a broadcast receiver
 * or a unit test can all reach this before anybody set it.
 */
object AndroidContext {
    @JvmStatic
    var application: Context? = null
}
