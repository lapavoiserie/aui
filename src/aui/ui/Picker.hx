package aui.ui;

import aui.View;
import aui.state.State;

/**
	A drop-down: a label, a list of options, and the index of the one chosen.

	The options are `String`s here rather than the `Text` children nui's canon
	describes, for the reason `pui.ui.Picker` gives: an application writes
	`new Picker("Transition", ["Cut", "Mix"], transition)` and a list of labels
	is what that is. `aui.nui.Describe` turns them into the canonical children
	on the way out, and the dynamic renderer reads them back the same way, so a
	tree that crosses a wire is the canon's and not this library's convenience.
**/
class Picker extends View {
	public var label:String;
	public var options:Array<String>;
	public var selectedState:Null<State<Int>>;

	public function new(label:String, options:Array<String>, ?selectedState:State<Int>) {
		super();
		this.viewType = "Picker";
		this.label = label;
		this.options = options == null ? [] : options;
		this.selectedState = selectedState;
	}
}
