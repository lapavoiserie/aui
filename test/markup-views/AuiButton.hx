import mui.macros.Markup.ui;

/**
	A button written in markup runs its closure, through the same call
	`DynamicComposable.kt` makes when it is pressed. See `check.sh`.
**/
class AuiButton {
	static function main() {
		var presses = 0;
		var screen:aui.View = ui(<VStack>
			<Button label="+1" onClick={() -> presses++}/>
			<Text key="a" text="first row"/>
		</VStack>);
		var source = new aui.nui.ViewSource(screen);
		var button:aui.View = cast source.childAt(screen, 0);
		var id = source.actionId(button);
		source.invokeAction(button);
		source.invokeActionId(id);
		Sys.println("label: " + (cast button : aui.ui.Button).label + " | actionId: " + id
			+ " | presses: " + presses
			+ " | key: " + source.keyOf(cast source.childAt(screen, 1))
			+ " | unkeyed: " + source.keyOf(button));
	}
}
