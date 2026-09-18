import mui.macros.Markup.ui;

/** `ui(<VStack>…)` compiled against `aui`'s own declarations. **/
class MarkupCheck {
	static var failures = 0;

	static function check(what:String, ok:Bool, ?extra:Dynamic):Void {
		Sys.println((ok ? "ok   " : "FAIL ") + what + (ok || extra == null ? "" : " — " + extra));
		if (!ok) failures++;
	}

	static function main() {
		var sources = ["Caméra", "Pupitre"];
		var tree = ui(<VStack spacing={8}>
			<Text text="Régie"/>
			<Toggle label="Muet" isOn={false} onToggle={v -> {}}/>
			<Picker label="Source" selectedIndex={0} onSelect={i -> {}}>
				{[for (s in sources) ui(<Text text={s}/>)]}
			</Picker>
			<Image src="asset:logo" alt="logo" width={64.0}/>
		</VStack>);

		check("the markup builds the declared type", tree.type == "VStack");
		check("children keep the order they were written in",
			[for (c in tree.children) c.type].join(",") == "Text,Toggle,Picker,Image",
			[for (c in tree.children) c.type].join(","));
		check("a two-way act carries what its value is",
			switch (tree.children[1].props.get("onToggle")) {
				case PCallbackBool(_): true; case _: false;
			});
		check("and a prop that lives in aui's bag is still written as an attribute",
			switch (tree.children[3].props.get("width")) {
				case PFloat(64.0): true; case _: false;
			}, tree.children[3].props.get("width"));

		Sys.println(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}
