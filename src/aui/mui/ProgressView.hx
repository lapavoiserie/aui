package aui.mui;


/**
	`aui`'s conformance for `mui.ui.ProgressView`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
class ProgressView extends aui.ui.ProgressView {
    public function new(?label:String, ?value:Float) {
        super(null);
    }
}
