import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;

/**
	Utilise un type que le renderer dynamique ne dessine pas.

	Le `TextField` est dans une **méthode auxiliaire**, pas dans `body()` : un
	`taskItem(...)` est du rendu autant que `body()`, et ne pas l'y suivre
	laisserait passer précisément ce que les vraies apps écrivent.
**/
class NonCouvert extends App {
	@:state var texte:String = "";

	public function new() {
		super();
		appName = "NonCouvert";
		packageName = "com.aui.noncouvert";
	}

	public static function main() {}

	function champ():View {
		return new aui.ui.TextField("Titre", texte);
	}

	override public function body():View {
		return new VStack(null, null, [new Text("saisie"), champ()]);
	}
}
