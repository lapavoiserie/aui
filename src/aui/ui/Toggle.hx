package aui.ui;

import aui.View;
import aui.state.State;

@:node("Toggle")
class Toggle extends View {
	@:prop public var label:String;
	@:prop("isOn", "onToggle") public var isOnState:Null<State<Bool>>;

	public function new(label:String, ?isOnState:State<Bool>) {
		super();
		this.viewType = "Toggle";
		this.label = label;
		this.isOnState = isOnState;
	}
}
