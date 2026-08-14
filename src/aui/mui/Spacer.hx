package aui.mui;


/**
	`aui`'s conformance for `mui.ui.Spacer`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
typedef Spacer = aui.ui.Spacer;
