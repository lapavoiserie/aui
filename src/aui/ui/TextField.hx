package aui.ui;

import aui.View;
import aui.state.State;

class TextField extends View {
	public var placeholder:String;
	public var textState:Null<State<String>>;

	public function new(placeholder:String, ?textState:State<String>) {
		super();
		this.viewType = "TextField";
		this.placeholder = placeholder;
		this.textState = textState;
	}
}
