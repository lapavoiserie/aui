package aui.runtime

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * Renders a live Haxe view tree with Compose, at runtime.
 *
 * This is how an aui app draws. It walks the tree the app builds *while
 * running*, so Compose sees the state each view reads and a write recomposes
 * the node that read it -- and so a `ViewComponent`, expanded here, is just a
 * view.
 *
 * The other path -- `ComposeGenerator` reading the typed AST and emitting a
 * `MainScreen` ahead of time -- is decommissioned, behind `-D aui_static`.
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
 * generator; here the bridge resolves its names against the state registry.
 * Plain interpolation — `Text("count: " + n.get())` — works too, because
 * `body()` runs again on every recomposition.
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

    /**
     * A child's identity among its siblings, for Compose's `key()`.
     *
     * Positional unless the node carries one, which is what
     * [nui's contract](https://lapavoiserie.github.io/nui/#/pull-mode) says
     * identity is: `keyOf` returns null because aui's trees have no sibling
     * keys. Compose already treats a `forEach` positionally, so for an app this
     * changes nothing and says out loud what was implicit.
     *
     * It changes something for a tree that arrives as **data** and sets a
     * `nodeId`. There, rows genuinely move, and positional matching reuses a
     * control against a different node -- correct for text, wrong for anything
     * being interacted with: the field someone is typing in silently becomes a
     * different one. `wui`'s Reconciler has said this all along; this is aui
     * paying the same advice.
     *
     * Never the handle: a rebuild allocates a fresh tree, so every handle
     * changes and every child looks new.
     */
    fun identity(index: Int): String {
        val nodeId = property("nodeId")
        return if (nodeId.isEmpty()) "#$index" else nodeId
    }

    val sectionHeader: String get() = ViewNodeBridge.sectionHeader(handle)
    fun tabTitle(index: Int): String = ViewNodeBridge.tabTitle(handle, index)
    val conditionValue: Boolean get() = ViewNodeBridge.conditionValue(handle)

    val fieldPlaceholder: String get() = ViewNodeBridge.fieldPlaceholder(handle)
    val fieldText: String get() = ViewNodeBridge.fieldText(handle)
    fun setFieldText(value: String) = ViewNodeBridge.setFieldText(handle, value)

    val toggleLabel: String get() = ViewNodeBridge.toggleLabel(handle)
    val toggleValue: Boolean get() = ViewNodeBridge.toggleValue(handle)
    fun setToggleValue(value: Boolean) = ViewNodeBridge.setToggleValue(handle, value)

    val sliderValue: Double get() = ViewNodeBridge.sliderValue(handle)
    fun setSliderValue(value: Double) = ViewNodeBridge.setSliderValue(handle, value)
    val sliderMin: Double get() = ViewNodeBridge.sliderMin(handle)
    val sliderMax: Double get() = ViewNodeBridge.sliderMax(handle)

    val modifierCount: Int get() = ViewNodeBridge.modifierCount(handle)
    fun modifierType(index: Int): String = ViewNodeBridge.modifierType(handle, index)
    fun modifierFloat(index: Int, param: Int = 0): Double =
        ViewNodeBridge.modifierFloat(handle, index, param)
    fun modifierString(index: Int, param: Int = 0): String =
        ViewNodeBridge.modifierString(handle, index, param)

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
 * State the renderer owns, as opposed to state the view tree describes.
 */
object DynamicHost {
    /**
     * Which tab is showing.
     *
     * Held here rather than in a `remember` inside the TabView branch: the tree
     * is rebuilt from Haxe on every recomposition, so a slot inside a recursive
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
    // Build the tree **inside** composition, deliberately, and not in a
    // `remember`.
    //
    // `body()` reads the app's states, and those reads go through StateBridge to
    // a Compose MutableState. Performed here, they are recorded by the snapshot
    // system -- so a write to any state the view depends on recomposes this and
    // rebuilds the tree, with nothing to call by hand.
    //
    // A `remember(generation)` did the opposite: it hid every read behind a
    // cache, which is why each editing control had to invalidate a counter. It
    // also meant a state written from anywhere *other* than a UI event -- a
    // timer, an async load -- never reached the screen at all.
    //
    // The cost is honest: any write rebuilds the whole tree. Per-property
    // liveness is finer and needs the values to be thunks rather than computed
    // when `body()` ran; see atelier/transpiler-vs-live-tree.md.
    ViewNodeBridge.rebuild()
    val root = ViewNodeBridge.getRoot()?.let { ViewNode(it) }

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
    node.children.forEachIndexed { index, child ->
        key(child.identity(index)) {
            if (child.viewType == "Spacer") Spacer(modifier = Modifier.weight(1f))
            else DynamicView(child)
        }
    }
}

/** The same, sharing horizontal space. */
@Composable
private fun RowScope.dynamicChildren(node: ViewNode) {
    node.children.forEachIndexed { index, child ->
        key(child.identity(index)) {
            if (child.viewType == "Spacer") Spacer(modifier = Modifier.weight(1f))
            else DynamicView(child)
        }
    }
}

@Composable
fun DynamicView(node: ViewNode, modifier: Modifier = Modifier) {
    val mod = applyModifiers(node, modifier)

    when (node.viewType) {
        "VStack" -> Column(modifier = mod) { dynamicChildren(node) }
        "HStack" -> Row(modifier = mod) { dynamicChildren(node) }
        "ZStack" -> Box(modifier = mod) {
            node.children.forEachIndexed { index, child ->
                key(child.identity(index)) { DynamicView(child) }
            }
        }

        "Text" -> Text(
            text = node.textContent,
            modifier = mod,
            style = typographyOf(node) ?: LocalTextStyle.current,
            fontWeight = if (isBold(node)) FontWeight.Bold else null,
        )

        "Button" -> {
            val handle = node.handle
            val hasAction = node.actionId >= 0
            Button(
                onClick = {
                    // No invalidate here either: the action writes a state that
                    // `body()` read during composition, so Compose recomposes
                    // DynamicRoot and the tree is rebuilt from it. The old
                    // version of this file called rebuild() and never invoked
                    // anything -- every button redrew the same tree.
                    if (hasAction) {
                        ViewNodeBridge.invokeAction(handle)
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

        // A Slider writes back on every drag, and reads its value from the cell
        // rather than keeping a copy: two copies of a value are two things that
        // can disagree, and the state write recomposes this anyway.
        "Slider" -> {
            val lo = node.sliderMin.toFloat()
            val hi = node.sliderMax.toFloat()
            Slider(
                value = node.sliderValue.toFloat().coerceIn(minOf(lo, hi), maxOf(lo, hi)),
                onValueChange = { node.setSliderValue(it.toDouble()) },
                valueRange = lo..(if (hi > lo) hi else lo + 0.0001f),
                modifier = mod
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
            // refuses to compile it, naming the type and the covered set -- a
            // knowable defect belongs at compile time, not on screen. This branch is for a tree that arrives as **data**,
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

/**
 * The typography step a node asked for, or null for the ambient one.
 *
 * ## Why this is not in `applyModifiers`
 *
 * Because in Compose typography is **not a Modifier**. A size, a padding and an
 * alpha are things done to a box; a type scale is a parameter of `Text` itself,
 * and there is no `Modifier.textStyle()` to reach for. Font arrived in the
 * modifier chain because that is where Haxe carries it -- `View.font(style)` --
 * and it fell through `applyModifiers`'s `else` branch, silently: a heading was
 * described, crossed the bridge intact, and was drawn at body size.
 *
 * So the chain is read here instead, where a style can actually be applied.
 *
 * ## Why the names map one to one
 *
 * `aui.modifiers.FontStyle` **is** Material's scale -- Display, Headline,
 * Title, Body, Label, each in three sizes. Nothing is being translated; the
 * enum is being spelled the way Compose spells it. `mui.ui.TextScale` sits a
 * layer above and picks four of these, which is a separate decision made where
 * four platforms have to agree.
 *
 * `CustomFont` is not here: it carries a name and a size rather than a step,
 * and answering it means building a TextStyle rather than choosing one.
 */
@Composable
fun typographyOf(node: ViewNode): TextStyle? {
    for (i in 0 until node.modifierCount) {
        if (node.modifierType(i) != "Font") continue
        val scale = MaterialTheme.typography
        return when (node.modifierString(i)) {
            "DisplayLarge" -> scale.displayLarge
            "DisplayMedium" -> scale.displayMedium
            "DisplaySmall" -> scale.displaySmall
            "HeadlineLarge" -> scale.headlineLarge
            "HeadlineMedium" -> scale.headlineMedium
            "HeadlineSmall" -> scale.headlineSmall
            "TitleLarge" -> scale.titleLarge
            "TitleMedium" -> scale.titleMedium
            "TitleSmall" -> scale.titleSmall
            "BodyLarge" -> scale.bodyLarge
            "BodyMedium" -> scale.bodyMedium
            "BodySmall" -> scale.bodySmall
            "LabelLarge" -> scale.labelLarge
            "LabelMedium" -> scale.labelMedium
            "LabelSmall" -> scale.labelSmall
            else -> null
        }
    }
    return null
}

/** Whether the chain asked for bold. A weight is a `Text` parameter too. */
fun isBold(node: ViewNode): Boolean {
    for (i in 0 until node.modifierCount) {
        if (node.modifierType(i) == "Bold") return true
    }
    return false
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

            // Font and Bold are absent on purpose: in Compose neither is a
            // Modifier. Both are parameters of `Text`, and both are read by
            // `typographyOf` and `isBold` where that parameter can be passed.
            //
            // Everything else is left to the static path for now. Unknown is
            // not the same as none -- see aui/docs for what is covered.
            else -> mod
        }
    }
    return mod
}
