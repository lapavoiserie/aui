import mui.macros.Markup.ui;

/** Markup builds aui's own controls. See `test/markup-views/check.sh`. **/
class AuiMarkup {
	static function main() {
		var lit = new aui.state.State(true, "lit");
		var screen:aui.View = ui(<VStack spacing={8} padding={{top: 8.0, right: 8.0, bottom: 8.0, left: 8.0}} backgroundColor={nui.Color.role(Surface)} clip={true}>
			<Text text="built by aui itself"/>
			<Toggle label="lit" isOn={lit.get()} onToggle={v -> lit.set(v)}/>
		</VStack>);
		Sys.println("built: " + Type.getClassName(Type.getClass(screen)));
	}
}
