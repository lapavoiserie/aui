package aui.ui;

import aui.View;

class TabView extends View {
	public var tabs:Array<Tab>;

	public function new(tabs:Array<Tab>) {
		super();
		this.viewType = "TabView";
		this.tabs = tabs;
	}
}
