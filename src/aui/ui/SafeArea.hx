package aui.ui;

import aui.View;

/**
    A container that applies safe area insets (system bars padding).
    Maps to a Column with Modifier.safeDrawingPadding() in Compose.
**/
@:node("SafeArea")
@:content("content")
class SafeArea extends View {
    public function new(content:Array<View>) {
        super();
        this.viewType = "SafeArea";
        this.children = content;
    }
}
