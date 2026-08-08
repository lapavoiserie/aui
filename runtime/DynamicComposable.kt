package aui.runtime

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp

/**
 * Renders a live Haxe view tree with Compose, at runtime.
 *
 * The static path — `ComposeGenerator` reading the typed AST and emitting
 * `MainScreen` — is what an aui app ships. This one walks the tree the app
 * builds *while running*, so the UI can change without regenerating Kotlin.
 * Enable it with `-D aui_dynamic`.
 *
 * ## How it reaches Haxe
 *
 * By calling it. `ViewNodeBridge` below is not declared here: it is the **Haxe**
 * class `aui.runtime.ViewNodeBridge`, compiled into `app-logic.jar`, in this
 * very package — so the JVM class loader resolves it with no import, no JNI and
 * no `System.loadLibrary`. `aui.state.StateBridge` already works this way in
 * the other direction, Haxe calling Kotlin.
 *
 * This file previously declared its own `object ViewNodeBridge` full of
 * `external fun` over a native library. That is right for **sui**, which
 * compiles Haxe to C++; aui compiles to the JVM. Nothing implemented those
 * externs, so the file sat dead — its own header said so.
 *
 * ## Where the tree comes from
 *
 * `ViewNodeBridge.rebuild()` re-runs the app's `body()` and hands back a fresh
 * root. A node crosses as an opaque `Any`; `ViewNode` is a thin Kotlin wrapper
 * that asks Haxe about it. The tree is reachable from the Haxe side, so nothing
 * here has to keep it alive.
 *
 * ## What it does not do yet
 *
 * `Text.withState("count: {n}")` builds a *template* consumed by the static
 * generator, so it renders empty here. Plain interpolation — `Text("count: " +
 * n.get())` — works, because `body()` runs again on every generation.
 */

/** A node of the Haxe tree, seen from Kotlin. */
@JvmInline
value class ViewNode(val handle: Any) {
    val viewType: String get() = ViewNodeBridge.getType(handle)
    val childCount: Int get() = ViewNodeBridge.childCount(handle)
    fun child(index: Int) = ViewNode(ViewNodeBridge.getChild(handle, index))
    val children: List<ViewNode> get() = (0 until childCount).map { child(it) }

    val textContent: String get() = ViewNodeBridge.getText(handle)
    val buttonLabel: String get() = ViewNodeBridge.getButtonLabel(handle)
    val actionId: Int get() = ViewNodeBridge.actionId(handle)

    fun property(key: String): String = ViewNodeBridge.getProperty(handle, key)

    val modifierCount: Int get() = ViewNodeBridge.modifierCount(handle)
    fun modifierType(index: Int): String = ViewNodeBridge.modifierType(handle, index)
    fun modifierFloat(index: Int, param: Int = 0): Double =
        ViewNodeBridge.modifierFloat(handle, index, param)

    /**
     * Whether a modifier parameter was actually given.
     *
     * `Padding()` means the default 16dp — that is what the static generator
     * emits — while `Padding(0)` means none, and `modifierFloat` answers 0.0 to
     * both. nui's pull contract has no optional-parameter answer yet, so aui's
     * bridge adds this one rather than reading a sentinel value.
     */
    fun modifierHasParam(index: Int, param: Int = 0): Boolean =
        ViewNodeBridge.modifierHasParam(handle, index, param)
}

/**
 * The current tree generation.
 *
 * An action writes into a Haxe `State<T>`, which is a Compose `MutableState`
 * underneath — but the *tree* holds values read when `body()` ran, so a write
 * changes nothing until `body()` runs again. Bumping this is what asks for that,
 * and because it is Compose state, the recomposition is Compose's own.
 */
object DynamicHost {
    var generation by mutableIntStateOf(0)
        private set

    fun invalidate() {
        generation++
    }
}

/** Root composable for the dynamic path: rebuilds the tree, then draws it. */
@Composable
fun DynamicRoot() {
    val root = remember(DynamicHost.generation) {
        ViewNodeBridge.rebuild()
        ViewNodeBridge.getRoot()?.let { ViewNode(it) }
    }

    if (root == null) {
        // setApp() has not run, or body() returned nothing. Draw nothing rather
        // than crash: this is the state a host is in for one frame at startup.
        return
    }

    DynamicView(root)
}

/**
 * Draw a node's children inside a column.
 *
 * `Spacer` is handled here rather than in `DynamicView` because `weight` only
 * exists **inside** a `Column`/`Row` scope -- it is what tells the parent to
 * share out its leftover space. The previous version called it on a bare
 * `Modifier`, which does not compile; nothing noticed, because nothing ever
 * compiled this file.
 */
@Composable
private fun ColumnScope.dynamicChildren(node: ViewNode) {
    node.children.forEach { child ->
        if (child.viewType == "Spacer") Spacer(modifier = Modifier.weight(1f))
        else DynamicView(child)
    }
}

/** The same, sharing horizontal space. */
@Composable
private fun RowScope.dynamicChildren(node: ViewNode) {
    node.children.forEach { child ->
        if (child.viewType == "Spacer") Spacer(modifier = Modifier.weight(1f))
        else DynamicView(child)
    }
}

@Composable
fun DynamicView(node: ViewNode, modifier: Modifier = Modifier) {
    val mod = applyModifiers(node, modifier)

    when (node.viewType) {
        "VStack" -> Column(modifier = mod) { dynamicChildren(node) }
        "HStack" -> Row(modifier = mod) { dynamicChildren(node) }
        "ZStack" -> Box(modifier = mod) { node.children.forEach { DynamicView(it) } }

        "Text" -> Text(text = node.textContent, modifier = mod)

        "Button" -> {
            val handle = node.handle
            val hasAction = node.actionId >= 0
            Button(
                onClick = {
                    // Run the action, then ask for a new generation. The old
                    // version of this file called rebuild() and never invoked
                    // anything -- every button redrew the same tree.
                    if (hasAction) {
                        ViewNodeBridge.invokeAction(handle)
                        DynamicHost.invalidate()
                    }
                },
                enabled = hasAction,
                modifier = mod
            ) {
                Text(node.buttonLabel)
            }
        }

        // A Spacer reached outside a Column/Row has nothing to share space
        // with, so it is just an empty box. Inside one, `dynamicChildren`
        // gives it the weight.
        "Spacer" -> Spacer(modifier = mod)
        "Divider" -> HorizontalDivider(modifier = mod)
        "ProgressView" -> CircularProgressIndicator(modifier = mod)

        "ScrollView" -> Column(
            modifier = mod.fillMaxSize().verticalScroll(rememberScrollState())
        ) { dynamicChildren(node) }

        "SafeArea" -> Column(modifier = mod.safeDrawingPadding()) { dynamicChildren(node) }

        else -> {
            // A type this renderer does not know.
            //
            // **A view written in the app never reaches here.** ComposeGenerator
            // refuses to compile it under -D aui_dynamic, naming the type and
            // the covered set -- a knowable defect belongs at compile time, not
            // on screen. This branch is for a tree that arrives as **data**,
            // where nothing could have been checked: the same boundary wui
            // draws with `Foreign.node`.
            //
            // There, naming the type still beats silence -- a container that
            // keeps its content somewhere other than `children` would otherwise
            // draw nothing at all, and a blank screen is not a diagnosis.
            Column(modifier = mod) {
                if (node.childCount > 0) {
                    dynamicChildren(node)
                } else {
                    Text(text = "?" + node.viewType)
                }
            }
        }
    }
}

/** Apply the Haxe modifier chain, in order. */
@Composable
fun applyModifiers(node: ViewNode, base: Modifier): Modifier {
    var mod = base
    for (i in 0 until node.modifierCount) {
        mod = when (node.modifierType(i)) {
            // Padding() with no argument is the default; Padding(0) is none.
            "Padding" ->
                if (node.modifierHasParam(i)) mod.padding(node.modifierFloat(i).dp)
                else mod.padding(16.dp)

            "PaddingHorizontal" -> mod.padding(horizontal = node.modifierFloat(i).dp)
            "PaddingVertical" -> mod.padding(vertical = node.modifierFloat(i).dp)

            "Opacity" -> mod.alpha(node.modifierFloat(i).toFloat())

            "FillMaxWidth" -> mod.fillMaxWidth()
            "FillMaxHeight" -> mod.fillMaxHeight()
            "FillMaxSize" -> mod.fillMaxSize()

            // Everything else is left to the static path for now. Unknown is
            // not the same as none -- see aui/docs for what is covered.
            else -> mod
        }
    }
    return mod
}
