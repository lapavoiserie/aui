package aui.ui;

import aui.View;
import aui.state.State;

class ConditionalView extends View {
	public var conditionState:Null<State<Bool>>;
	public var thenView:View;
	public var elseView:Null<View>;

	public function new(conditionState:State<Bool>, thenView:View, ?elseView:View) {
		super();
		this.viewType = "ConditionalView";
		this.conditionState = conditionState;
		this.thenView = thenView;
		this.elseView = elseView;
	}
}
