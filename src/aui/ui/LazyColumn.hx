package aui.ui;

import aui.View;

class LazyColumn extends View {
	public function new(content:Array<View>) {
		super();
		this.viewType = "LazyColumn";
		this.children = content;
	}
}
