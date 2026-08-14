package aui.mui;


/**
	`aui`'s conformance for `mui.ui.SafeArea`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
class SafeArea extends aui.ui.SafeArea {
    public function new(content:Array<aui.View>) {
        super(content);
        // Material's page margin, on top of the inset Compose already applies
        // for the system bars: staying out of the notch and sitting a sensible
        // distance from the edge are two different things.
        padding(16);
    }

    public function safeArea():aui.View {
        return this;
    }
}
