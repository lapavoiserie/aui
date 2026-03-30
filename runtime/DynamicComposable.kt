package com.aui.runtime

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * Recursively renders a Haxe view tree at runtime using Jetpack Compose.
 * Used by `mui watch` for hot reload — the Compose host stays running
 * while the .cppia script is reloaded with new view code.
 *
 * Each ViewNode maps to its Compose equivalent via a when() on viewType.
 * Modifiers are applied dynamically from the modifier chain.
 */

// ViewNode data class — mirrors the C bridge API
data class ViewNode(
    val pointer: Long  // opaque pointer from the native bridge
) {
    val viewType: String get() = ViewNodeBridge.getType(pointer)
    val childCount: Int get() = ViewNodeBridge.childCount(pointer)
    fun child(index: Int) = ViewNode(ViewNodeBridge.getChild(pointer, index))
    val children: List<ViewNode> get() = (0 until childCount).map { child(it) }
    val textContent: String get() = ViewNodeBridge.getText(pointer)
    val buttonLabel: String get() = ViewNodeBridge.getButtonLabel(pointer)
    val buttonActionId: Int get() = ViewNodeBridge.getButtonActionId(pointer)
    fun property(key: String): String = ViewNodeBridge.getProperty(pointer, key)
    val modifierCount: Int get() = ViewNodeBridge.modifierCount(pointer)
    fun modifierType(index: Int): String = ViewNodeBridge.modifierType(pointer, index)
    fun modifierFloat(index: Int, param: Int = 0): Double =
        ViewNodeBridge.modifierFloat(pointer, index, param)
}

// JNI bridge to the C functions
object ViewNodeBridge {
    external fun rebuild()
    external fun getRoot(): Long
    external fun getType(node: Long): String
    external fun childCount(node: Long): Int
    external fun getChild(node: Long, index: Int): Long
    external fun getText(node: Long): String
    external fun getButtonLabel(node: Long): String
    external fun getButtonActionId(node: Long): Int
    external fun getProperty(node: Long, key: String): String
    external fun modifierCount(node: Long): Int
    external fun modifierType(node: Long, index: Int): String
    external fun modifierFloat(node: Long, index: Int, param: Int): Double

    init {
        System.loadLibrary("haxebridge")
    }
}

// Dynamic Compose renderer
@Composable
fun DynamicView(node: ViewNode, modifier: Modifier = Modifier) {
    val mod = applyModifiers(node, modifier)

    when (node.viewType) {
        "VStack" -> {
            Column(modifier = mod) {
                node.children.forEach { child ->
                    DynamicView(child)
                }
            }
        }
        "HStack" -> {
            Row(modifier = mod) {
                node.children.forEach { child ->
                    DynamicView(child)
                }
            }
        }
        "ZStack" -> {
            Box(modifier = mod) {
                node.children.forEach { child ->
                    DynamicView(child)
                }
            }
        }
        "Text" -> {
            Text(
                text = node.textContent,
                modifier = mod
            )
        }
        "Button" -> {
            val actionId = node.buttonActionId
            Button(
                onClick = { if (actionId >= 0) ViewNodeBridge.rebuild() },
                modifier = mod
            ) {
                Text(node.buttonLabel)
            }
        }
        "Spacer" -> {
            Spacer(modifier = mod.weight(1f))
        }
        "Divider" -> {
            HorizontalDivider(modifier = mod)
        }
        "ProgressView" -> {
            CircularProgressIndicator(modifier = mod)
        }
        "ScrollView" -> {
            Column(
                modifier = mod
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
            ) {
                node.children.forEach { child ->
                    DynamicView(child)
                }
            }
        }
        "SafeArea" -> {
            Column(modifier = mod.safeDrawingPadding()) {
                node.children.forEach { child ->
                    DynamicView(child)
                }
            }
        }
        else -> {
            // Unknown type — render children if any
            if (node.childCount > 0) {
                Column(modifier = mod) {
                    node.children.forEach { child ->
                        DynamicView(child)
                    }
                }
            }
        }
    }
}

// Apply modifiers from the Haxe modifier chain
@Composable
fun applyModifiers(node: ViewNode, base: Modifier): Modifier {
    var mod = base
    for (i in 0 until node.modifierCount) {
        when (node.modifierType(i)) {
            "Padding" -> {
                val value = node.modifierFloat(i).dp
                mod = mod.padding(value)
            }
            "PaddingDefault" -> {
                mod = mod.padding(16.dp)
            }
            "Opacity" -> {
                val value = node.modifierFloat(i).toFloat()
                mod = mod.alpha(value)
            }
            "FillMaxWidth" -> mod = mod.fillMaxWidth()
            "FillMaxHeight" -> mod = mod.fillMaxHeight()
            "FillMaxSize" -> mod = mod.fillMaxSize()
        }
    }
    return mod
}

// Hot reload root
@Composable
fun HotReloadRoot() {
    var reloadCount by remember { mutableIntStateOf(0) }

    val root = remember(reloadCount) {
        ViewNodeBridge.rebuild()
        ViewNode(ViewNodeBridge.getRoot())
    }

    MaterialTheme {
        Surface {
            DynamicView(root)
        }
    }
}
