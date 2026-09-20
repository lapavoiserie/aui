import mui.macros.Markup.ui;

/** Markup builds aui's own controls. See `test/markup-views/check.sh`. **/
class AuiMarkup {
	static function main() {
		var lit = new aui.state.State(true, "lit");
		var screen:aui.View = ui(<VStack spacing={8}>
			<Text text="built by aui itself"/>
			<Toggle label="lit" isOn={lit.get()} onToggle={v -> lit.set(v)}/>
		</VStack>);
		Sys.println("built: " + Type.getClassName(Type.getClass(screen)));
	}
}
