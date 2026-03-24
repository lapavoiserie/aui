package aui.ui;

import aui.View;

class NavigationLink extends View {
	public var label:String;
	public var destination:View;

	public function new(label:String, destination:View) {
		super();
		this.viewType = "NavigationLink";
		this.label = label;
		this.destination = destination;
		this.children = [destination];
	}
}
