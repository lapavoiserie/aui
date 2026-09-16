package aui.mui;

/**
	`aui`'s conformance for `mui.ui.Icon`: a name the compiler has checked
	against the shared vocabulary.
**/
class Icon extends aui.ui.Icon {
	public function new(name:mui.ui.IconName, ?label:String) {
		super((name : String), label);
	}
}
