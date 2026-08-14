package aui.mui;


/**
	`aui`'s conformance for `mui.ui.HStack`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
class HStack extends aui.ui.HStack {
    public function new(content:Array<aui.View>, ?spacing:Float) {
        super(null, spacing, content);
    }
}
