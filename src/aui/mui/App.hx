package aui.mui;


/**
	`aui`'s conformance for `mui.App`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
class App extends aui.App {
    public var appTitle(get, set):String;
    function get_appTitle():String return appName;
    function set_appTitle(v:String):String { appName = v; return v; }
}
