package aui.ui;

import aui.View;
import aui.state.State;

class ProgressView extends View {
	public var progressState:Null<State<Float>>;
	public var isIndeterminate:Bool;

	public function new(?progressState:State<Float>) {
		super();
		this.viewType = "ProgressView";
		this.progressState = progressState;
		this.isIndeterminate = progressState == null;
	}
}
