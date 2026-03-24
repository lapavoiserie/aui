package aui.ui;

import aui.View;

class NavigationStack extends View {
	public var rootContent:View;

	public function new(content:View) {
		super();
		this.viewType = "NavigationStack";
		this.rootContent = content;
		this.children = [content];
	}
}
