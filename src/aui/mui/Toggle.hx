package aui.mui;


/**
	`aui`'s conformance for `mui.ui.Toggle`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
class Toggle extends aui.ui.Toggle {
    public function new(label:String, state:ToggleBinding) {
        super(label, state.unwrap());
    }
}
