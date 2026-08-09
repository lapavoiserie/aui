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

    val sectionHeader: String get() = ViewNodeBridge.sectionHeader(handle)
    fun tabTitle(index: Int): String = ViewNodeBridge.tabTitle(handle, index)
    val conditionValue: Boolean get() = ViewNodeBridge.conditionValue(handle)

    val fieldPlaceholder: String get() = ViewNodeBridge.fieldPlaceholder(handle)
    val fieldText: String get() = ViewNodeBridge.fieldText(handle)
    fun setFieldText(value: String) = ViewNodeBridge.setFieldText(handle, value)

    val toggleLabel: String get() = ViewNodeBridge.toggleLabel(handle)
    val toggleValue: Boolean get() = ViewNodeBridge.toggleValue(handle)
    fun setToggleValue(value: Boolean) = ViewNodeBridge.setToggleValue(handle, value)

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

    /**
     * Which tab is showing.
     *
     * Held here rather than in a `remember` inside the TabView branch: the tree
     * is rebuilt from Haxe on every generation, so a slot inside a recursive
     * `DynamicView` is not a stable home for selection -- it reset to 0 on the
     * recomposition the click itself caused, and the tab appeared not to
     * respond at all.
     *
     * One index, so one TabView at a time. aui apps root a single one; the day
     * that stops being true this becomes a map keyed by something stable across
     * rebuilds, which a node handle is not.
     */
    var tabIndex by mutableIntStateOf(0)

    fun selectTab(index: Int) {
        tabIndex = index
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

    // Keep the tree out from under the system bars.
    //
    // Android draws edge-to-edge by default since API 35, so without this the
    // top of the tree sits *under* the status bar -- and the system, not the
    // app, receives the touches there. A TabView rooted at the top was drawn
    // correctly and could not be tapped at all: the click never reached Compose.
    // The counter never showed it, its content being in the middle of the
    // screen.
    Box(modifier = Modifier.safeDrawingPadding()) {
        DynamicView(root)
    }
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
                    // This one stays, and it is worth saying why.
                    //
                    // A value read *live* -- a state template, a field, a toggle
                    // -- refreshes on its own, because Compose tracks the read.
                    // But a value **frozen** into the node when `body()` ran does
                    // not: `new Text("count: " + n.get())` computed its string
                    // once, and nothing will recompute it. A StateAction can
                    // change either, and can change the tree's *shape*, so the
                    // rebuild stays here until property reads are live too.
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

        // A card is a surface around its children; nothing more is claimed.
        "Card" -> Card(modifier = mod) {
            Column(modifier = Modifier.padding(16.dp)) { dynamicChildren(node) }
        }

        // A section is its children under a header. An empty header draws no
        // header rather than an empty line -- `Section(content)` is legal.
        "Section" -> Column(modifier = mod) {
            val header = node.sectionHeader
            if (header.isNotEmpty()) {
                Text(
                    text = header,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }
            dynamicChildren(node)
        }

        // The source reports the live branch as child 0 and the other as child
        // 1, so the choice is made here against the state -- read now, not when
        // the tree was built.
        "ConditionalView" -> {
            val index = if (node.conditionValue) 0 else 1
            if (index < node.childCount) {
                DynamicView(node.child(index), mod)
            }
        }

        // Tabs: the bar comes from the titles, the pages are the children. A
        // `Tab` is not a view and never reaches here as a node -- the source
        // reports each tab's *content* as a child.
        "TabView" -> {
            val count = node.childCount
            val selected = DynamicHost.tabIndex
            Column(modifier = mod) {
                if (count > 0) {
                    TabRow(selectedTabIndex = selected.coerceIn(0, count - 1)) {
                        for (i in 0 until count) {
                            androidx.compose.material3.Tab(
                                selected = i == selected,
                                onClick = { DynamicHost.selectTab(i) },
                                text = { Text(node.tabTitle(i)) }
                            )
                        }
                    }
                    DynamicView(node.child(selected.coerceIn(0, count - 1)))
                }
            }
        }

        // Edited by the user, so the value travels back into the Haxe state and
        // the tree is rebuilt -- the state is the single source of truth, and a
        // field that kept its own copy would drift from what the rest of the
        // view reads.
        "TextField" -> OutlinedTextField(
            value = node.fieldText,
            onValueChange = {
                // No invalidate: `value` above reads the state through Haxe
                // *during composition*, and Compose's snapshot system records
                // that read however deep the call stack -- including through
                // JVM frames Haxe emitted. Writing the state recomposes this
                // field, and every other view whose value is read the same way.
                // Proven on a device: a counter advanced 0 -> 1 -> 2 with the
                // generation counter untouched.
                node.setFieldText(it)
            },
            placeholder = { Text(node.fieldPlaceholder) },
            singleLine = true,
            modifier = mod
        )

        "Toggle" -> Row(
            modifier = mod.fillMaxWidth(),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
        ) {
            Text(text = node.toggleLabel, modifier = Modifier.weight(1f))
            Switch(
                checked = node.toggleValue,
                onCheckedChange = {
                    // No invalidate -- see the TextField above.
                    node.setToggleValue(it)
                }
            )
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
