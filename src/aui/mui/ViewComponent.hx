package aui.mui;


/**
	`aui`'s conformance for `mui.ViewComponent`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
// Was declared inline here for want of a real one -- which meant no
// @:autoBuild, so a component's own @:state fields were never turned into
// cells. aui has had aui.ViewComponent since 2026-08-09.
typedef ViewComponent = aui.ViewComponent;
