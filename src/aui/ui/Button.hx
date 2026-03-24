package aui.ui;

import aui.View;
import aui.state.StateAction;

class Button extends View {
	public var label:String;
	public var labelView:Null<View>;
	public var action:Null<() -> Void>;
	public var stateAction:Null<StateAction>;

	static var _actionRegistry:Map<String, () -> Void> = new Map();
	static var _nextActionId:Int = 0;

	public function new(label:String, ?action:() -> Void, ?stateAction:StateAction) {
		super();
		this.viewType = "Button";
		this.label = label;
		this.action = action;
		this.stateAction = stateAction;

		if (action != null) {
			var actionId = "action_" + _nextActionId++;
			_actionRegistry.set(actionId, action);
			this.properties.set("actionId", actionId);
		}
	}

	public static function withView(labelView:View, ?action:() -> Void, ?stateAction:StateAction):Button {
		var btn = new Button("", action, stateAction);
		btn.labelView = labelView;
		return btn;
	}

	public static function _invokeAction(actionId:String):Void {
		var action = _actionRegistry.get(actionId);
		if (action != null) {
			action();
		}
	}
}
