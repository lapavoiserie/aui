package aui.ui;

import aui.View;
import aui.state.State;

@:node("Slider")
class Slider extends View {
	@:prop("value", "onValue") public var valueState:Null<State<Float>>;
	@:prop public var min:Float;
	@:prop public var max:Float;

	public function new(?valueState:State<Float>, min:Float = 0.0, max:Float = 1.0) {
		super();
		this.viewType = "Slider";
		this.valueState = valueState;
		this.min = min;
		this.max = max;
	}
}
