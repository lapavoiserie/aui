import mui.macros.Markup.ui;

/** A tag no aui control declares. Refused at compile time. **/
class BadTag {
	static function main() {
		var t = ui(<Hologramme/>);
	}
}
