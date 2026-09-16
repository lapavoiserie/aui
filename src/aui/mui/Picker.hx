package aui.mui;


/**
	`aui`'s conformance for `mui.ui.Picker`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`.
**/
class Picker extends aui.ui.Picker {
    public function new(label:String, options:Array<String>, state:PickerBinding) {
        super(label, options, state.unwrap());
    }
}
