package aui.ui;

import aui.View;
import aui.state.State;

class Slider extends View {
	public var valueState:Null<State<Float>>;
	public var min:Float;
	public var max:Float;

	public function new(?valueState:State<Float>, min:Float = 0.0, max:Float = 1.0) {
		super();
		this.viewType = "Slider";
		this.valueState = valueState;
		this.min = min;
		this.max = max;
	}
}
