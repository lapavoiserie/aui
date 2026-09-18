package aui.ui;

import aui.View;
import aui.modifiers.ViewModifier;

@:node("ZStack")
@:content("content")
class ZStack extends View {
	public var alignment:aui.modifiers.ViewModifier.Alignment;

	public function new(?alignment:aui.modifiers.ViewModifier.Alignment, content:Array<View>) {
		super();
		this.viewType = "ZStack";
		this.alignment = alignment != null ? alignment : aui.modifiers.ViewModifier.Alignment.Center;
		this.children = content;
	}
}
