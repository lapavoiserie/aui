package aui.mui;


/**
	`aui`'s conformance for `mui.ui.TextInputBinding`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
abstract TextInputBinding(aui.state.State<String>) {
    public inline function new(v:aui.state.State<String>) this = v;

    @:from static inline function fromState(s:aui.state.State<String>):TextInputBinding
        return new TextInputBinding(s);

    public inline function unwrap():aui.state.State<String> return this;
}
