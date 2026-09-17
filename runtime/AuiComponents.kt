package aui.runtime

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * Node types this renderer was taught, beyond the ones it knows.
 *
 * A component library registers what it draws — `vui`'s level meter is the
 * first — so a node nobody here has heard of is still drawn rather than
 * appearing as `?LevelMeter` on a panel.
 *
 * Registered by the LIBRARY, not by the application: a tree that arrives naming
 * a meter must find one without the panel having to wire it. `pui` says the
 * same thing in `pui.nui.NodeRenderer.register`, and `wui` in
 * `wui::components::find`; this is aui's.
 *
 * Nothing in aui names a component library. The direction is the one the whole
 * ecosystem uses: the library knows the backend, the backend never knows the
 * library.
 */
object AuiComponents {
    /**
     * What draws one node type.
     *
     * The node and its structural path, which is what a component needs to keep
     * anything under: the tree is rebuilt from Haxe on every recomposition, so a
     * `remember` inside the recursive `DynamicView` is not a stable home. The
     * path is, and `DynamicHost` is where things keyed by it live.
     */
    fun interface Draws {
        @Composable
        fun draw(node: ViewNode, path: String, modifier: Modifier)
    }

    private val known = mutableMapOf<String, Draws>()

    /** Teach the renderer a type. Called by the library that draws it. */
    @JvmStatic
    fun register(type: String, draws: Draws) {
        known[type] = draws
    }

    /** Whether something draws this type here. */
    @JvmStatic
    fun knows(type: String): Boolean = known.containsKey(type)

    /** What draws it, or null. */
    fun find(type: String): Draws? = known[type]
}
