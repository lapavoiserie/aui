package aui.mui;

/**
	`aui`'s conformance for `mui.state.Binding`.

	Moved here from the `#if (mui_backend == "aui")` branch it used to live in.
	`mui` resolves it by name through `mui.Contract`, and lists it as optional
	because the six backends genuinely disagree about which of these exist.
**/
typedef Binding<T> = aui.state.Binding<T>;
