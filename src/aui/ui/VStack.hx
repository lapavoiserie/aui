package aui.ui;

import aui.View;
import aui.modifiers.ViewModifier;

class VStack extends View {
	public var spacing:Null<Float>;
	public var alignment:HorizontalAlignment;

	public function new(?alignment:HorizontalAlignment, ?spacing:Float, content:Array<View>) {
		super();
		this.viewType = "VStack";
		this.alignment = alignment != null ? alignment : HorizontalAlignment.Center;
		this.spacing = spacing;
		this.children = content;
	}
}

enum HorizontalAlignment {
	Start;
	Center;
	End;
}
