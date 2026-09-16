package aui.ui;

import aui.View;
import aui.state.StateAction;

class Button extends View {
	public var label:String;
	public var labelView:Null<View>;
	public var stateAction:Null<StateAction>;

	/**
		`icon` is a name from the shared vocabulary (`nui.Icons`), drawn beside
		the label -- or alone, when the label is empty, and then it names the
		button for TalkBack.
	**/
	public function new(label:String, ?stateAction:StateAction, ?icon:String) {
		super();
		this.viewType = "Button";
		this.label = label;
		this.stateAction = stateAction;
		if (icon != null && icon != "") properties.set("icon", icon);
	}

	public static function withView(labelView:View, ?stateAction:StateAction):Button {
		var btn = new Button("", stateAction);
		btn.labelView = labelView;
		return btn;
	}
}
