package aui.ui;

import aui.View;

@:node("ScrollView")
@:content("content")
class ScrollView extends View {
	public function new(content:Array<View>) {
		super();
		this.viewType = "ScrollView";
		this.children = content;
	}
}
