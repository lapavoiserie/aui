package aui.mui;

import mui.ui.TabItem;

/**
	`aui`'s conformance for `mui.ui.TabView`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
class TabView extends aui.ui.TabView {
    public function new(tabs:Array<TabItem>) {
        super([for (t in tabs) new aui.ui.Tab(t.label, "", t.content)]);
    }
}
