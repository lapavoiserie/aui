package aui.mui;


/**
	`aui`'s conformance for `mui.ui.Button`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
class Button extends aui.ui.Button {
    public function new(label:String, ?action:() -> Void) {
        super(label);
        if (action != null) {
            onTapGesture(action);
        }
    }
}
