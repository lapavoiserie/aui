package aui.ui;

import aui.View;
import aui.state.StateAction;

class Button extends View {
	public var label:String;
	public var labelView:Null<View>;
	public var stateAction:Null<StateAction>;

	public function new(label:String, ?stateAction:StateAction) {
		super();
		this.viewType = "Button";
		this.label = label;
		this.stateAction = stateAction;
	}

	public static function withView(labelView:View, ?stateAction:StateAction):Button {
		var btn = new Button("", stateAction);
		btn.labelView = labelView;
		return btn;
	}
}
