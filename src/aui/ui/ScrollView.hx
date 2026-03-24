package aui.ui;

import aui.View;

class ScrollView extends View {
	public function new(content:Array<View>) {
		super();
		this.viewType = "ScrollView";
		this.children = content;
	}
}
