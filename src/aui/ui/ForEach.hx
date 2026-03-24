package aui.ui;

import aui.View;
import aui.state.State;

class ForEach extends View {
	public var itemsState:Dynamic;
	public var builder:Dynamic;

	public function new(items:Dynamic, builder:Dynamic) {
		super();
		this.viewType = "ForEach";
		this.itemsState = items;
		this.builder = builder;
	}
}
