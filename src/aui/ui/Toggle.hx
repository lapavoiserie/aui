package aui.ui;

import aui.View;
import aui.state.State;

class Toggle extends View {
	public var label:String;
	public var isOnState:Null<State<Bool>>;

	public function new(label:String, ?isOnState:State<Bool>) {
		super();
		this.viewType = "Toggle";
		this.label = label;
		this.isOnState = isOnState;
	}
}
