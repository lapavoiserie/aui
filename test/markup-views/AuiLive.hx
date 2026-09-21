import mui.macros.Markup.ui;

/**
	A value computed from a cell, written in markup, is deferred into a thunk --
	so displaying it does not make the cell structural. See `check.sh`.
**/
class AuiLive {
	static function main() {
		var count = new rui.state.State(3); // aui.state.State needs the Kotlin StateBridge class loaded
		var screen:aui.View = ui(<VStack>
			<Text text={"n = " + count.get()}/>
		</VStack>);
		var text:aui.View = cast screen.children[0];
		Sys.println("deferred: " + (text.liveBuild != null));
	}
}
