package aui.ui;

import aui.View;
import aui.state.State;

@:node("TextInput")
class TextField extends View {
	@:prop public var placeholder:String;
	@:prop("text", "onText") public var textState:Null<State<String>>;

	public function new(placeholder:String, ?textState:State<String>) {
		super();
		this.viewType = "TextField";
		this.placeholder = placeholder;
		this.textState = textState;
	}
}
