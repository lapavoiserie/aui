package aui.ui;

import aui.View;
import aui.modifiers.ViewModifier;

@:node("HStack")
@:content("content")
class HStack extends View {
	@:prop public var spacing:Null<Float>;
	public var alignment:VerticalAlignment;

	public function new(?alignment:VerticalAlignment, ?spacing:Float, content:Array<View>) {
		super();
		this.viewType = "HStack";
		this.alignment = alignment != null ? alignment : VerticalAlignment.Center;
		this.spacing = spacing;
		this.children = content;
	}
}

enum VerticalAlignment {
	Top;
	Center;
	Bottom;
}
