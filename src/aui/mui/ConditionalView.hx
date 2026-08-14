package aui.mui;


/**
	`aui`'s conformance for `mui.ui.ConditionalView`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
class ConditionalView extends aui.ui.ConditionalView {
    public function new(condition:aui.state.State<Bool>, thenView:aui.View, ?elseView:aui.View) {
        super(condition, thenView, elseView);
    }
}
