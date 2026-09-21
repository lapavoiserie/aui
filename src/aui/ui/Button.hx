package aui.ui;

import aui.View;
import aui.state.StateAction;

/**
	A button: a label, an optional icon, and what pressing it does.

	## Two ways to say what it does

	`stateAction` is the declarative one -- `Increment(count)`, `Toggle(flag)`
	-- and it is how every button here was written while the only way to put
	one on screen was `ComposeGenerator`, which translated the enum to Kotlin
	and could not have translated a closure.

	`action` is a plain Haxe closure, which is what the canon's `Button`
	carries (`onClick`) and what `mui`'s markup writes. It was missing for no
	reason left standing: the path that renders by default is the dynamic one
	(`docs/render-paths.md`), where the app RUNS on the JVM and
	`DynamicComposable.kt`'s Button calls back into `ViewNodeBridge.invokeAction`
	-- which already ran a closure hung on the modifier chain. So `<Button>`
	did not exist in this backend's vocabulary, the kitchen sink had to leave
	buttons out, and the only capability gap in the table was a field.

	A button given both runs the enum, then the closure.
**/
@:node("Button")
class Button extends View {
	@:prop public var label:String;
	public var labelView:Null<View>;
	public var stateAction:Null<StateAction>;

	/** What pressing it runs. See the class doc. **/
	@:action("onClick") public var action:Null<Void->Void>;

	/**
		`icon` is a name from the shared vocabulary (`nui.Icons`), drawn beside
		the label -- or alone, when the label is empty, and then it names the
		button for TalkBack.
	**/
	public function new(label:String, ?stateAction:StateAction, ?icon:String, ?action:Void->Void) {
		super();
		this.viewType = "Button";
		this.label = label;
		this.stateAction = stateAction;
		this.action = action;
		if (icon != null && icon != "") properties.set("icon", icon);
	}

	/** A button that runs a closure: the canon's shape. **/
	public static function onClick(label:String, action:Void->Void, ?icon:String):Button
		return new Button(label, null, icon, action);

	public static function withView(labelView:View, ?stateAction:StateAction):Button {
		var btn = new Button("", stateAction);
		btn.labelView = labelView;
		return btn;
	}
}
