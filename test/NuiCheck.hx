import aui.View;
import aui.nui.ViewSource;
import aui.runtime.ViewNodeBridge;
import aui.state.State;
import aui.state.StateAction;
import aui.ui.Button;
import aui.ui.Text;
import aui.ui.VStack;

/**
	Checks the Haxe half of aui's dynamic renderer, on a plain JVM.

	## Why this exists

	Everything here is reached from **Kotlin**, by name, through the class
	loader. Nothing in Haxe calls it, so nothing in Haxe type-checks the way
	Kotlin uses it — and the failure mode is not a crash. `ViewSource` was first
	copied from `sui`, where a Button carries a closure in a field named
	`action`; aui has never had that field, so `Reflect.field` answered null and
	**every button would have done nothing at all, in silence**. A renderer that
	draws correctly and ignores every tap looks like a Compose problem.

	So these tests exercise the parts that no compiler can check: the field names
	read reflectively, and the meaning given to a `StateAction`.

	Run with `test/run.sh`. The Compose half is not involved — `aui.state.State`
	needs a JVM `aui.state.StateBridge`, and a stub in `test/stubs` provides one.
**/
class NuiCheck {
	static var failures = 0;

	static function check(what:String, ok:Bool, ?detail:String):Void {
		if (ok) {
			Sys.println('  ok   $what');
		} else {
			failures++;
			Sys.println('  FAIL $what' + (detail == null ? "" : '  -- $detail'));
		}
	}

	static function main() {
		Sys.println("aui — contrat pull de nui");

		var count = new State<Int>(0, "count");
		var flag = new State<Bool>(false, "flag");

		var text = new Text("compteur");
		var plus = new Button("Plus", Increment(count));
		var toggle = new Button("Bascule", Toggle(flag));
		var mute = new Button("Sans action");
		var root:View = new VStack(null, null, [text, plus, toggle, mute]);

		var src = new ViewSource(root);

		// --- the walk ---
		check("le type est le nom nu", src.typeOf(root) == "VStack", src.typeOf(root));
		check("les enfants sont comptés", src.childCount(root) == 4, Std.string(src.childCount(root)));
		check("un enfant est atteint", src.typeOf(src.childAt(root, 1)) == "Button");

		// --- the fields read reflectively ---
		//
		// These are the ones a compiler cannot check: they are read by name.
		check("le texte d'un Text est lu", ViewNodeBridge.getText(text) == "compteur",
			ViewNodeBridge.getText(text));
		check("le libellé d'un Button est lu", ViewNodeBridge.getButtonLabel(plus) == "Plus",
			ViewNodeBridge.getButtonLabel(plus));

		// --- actions ---
		check("un bouton avec action a un id", src.actionId(plus) >= 0, Std.string(src.actionId(plus)));
		check("un bouton sans action n'en a pas", src.actionId(mute) < 0, Std.string(src.actionId(mute)));
		check("un id est stable", src.actionId(plus) == src.actionId(plus));
		check("deux boutons ont des ids distincts", src.actionId(plus) != src.actionId(toggle));

		// The heart of it: aui's actions are a declarative enum the static
		// generator translates to Kotlin. At runtime that translation does not
		// exist, so the source has to apply the enum itself.
		src.invokeAction(plus);
		check("Increment écrit dans l'état", count.get() == 1, Std.string(count.get()));
		src.invokeAction(plus);
		check("Increment est cumulatif", count.get() == 2, Std.string(count.get()));

		src.invokeAction(toggle);
		check("Toggle inverse l'état", flag.get() == true, Std.string(flag.get()));

		src.invokeAction(mute);
		check("un bouton sans action ne casse rien", true);

		// Through the id, which is what a foreign consumer holds.
		src.invokeActionId(src.actionId(plus));
		check("invoquer par id fait la même chose", count.get() == 3, Std.string(count.get()));
		src.invokeActionId(-1);
		src.invokeActionId(999);
		check("un id hors bornes n'exécute rien", count.get() == 3);

		// SetValue / Decrement / Append, and the animated wrapper, which changes
		// how a change is shown -- never what is written.
		var direct = new Button("Fixe", SetValue(count, 40));
		new ViewSource(direct).invokeAction(direct);
		check("SetValue écrit la valeur", count.get() == 40, Std.string(count.get()));

		var moins = new Button("Moins", Decrement(count, 8));
		new ViewSource(moins).invokeAction(moins);
		check("Decrement retire le montant donné", count.get() == 32, Std.string(count.get()));

		var anim = new Button("Animé", Animated(Increment(count), Default));
		new ViewSource(anim).invokeAction(anim);
		check("Animated applique l'action intérieure", count.get() == 33, Std.string(count.get()));

		var mot = new State<String>("a", "mot");
		var ajout = new Button("Ajoute", Append(mot, "b"));
		new ViewSource(ajout).invokeAction(ajout);
		check("Append concatène", mot.get() == "ab", mot.get());

		// --- the optional modifier parameter ---
		//
		// `Padding()` means the default 16dp and `Padding(0)` means none, but
		// modifierFloat answers 0.0 to both. This is the difference the pull
		// contract cannot express, so aui's bridge answers it separately.
		var parDefaut = new Text("d");
		parDefaut.padding();
		var explicite = new Text("e");
		explicite.padding(0);

		var sd = new ViewSource(parDefaut);
		var se = new ViewSource(explicite);
		check("un padding par défaut est vu comme absent",
			sd.modifierType(parDefaut, 0) == "Padding" && !sd.modifierHasParam(parDefaut, 0, 0));
		check("un padding explicite de 0 est vu comme présent",
			se.modifierType(explicite, 0) == "Padding" && se.modifierHasParam(explicite, 0, 0));
		check("les deux donnent pourtant la même valeur",
			sd.modifierFloat(parDefaut, 0, 0) == 0.0 && se.modifierFloat(explicite, 0, 0) == 0.0);

		// --- state templates ---
		//
		// `Text.withState` builds a template the *static* generator interpolates
		// into Kotlin. There is no Kotlin at runtime, so the bridge resolves the
		// names against the state registry. Without this the counter example
		// renders an empty string forever -- which reads as a renderer bug.
		var gabarit = aui.ui.Text.withState("compte : {count}");
		check("un gabarit est résolu à l'exécution",
			ViewNodeBridge.getText(gabarit) == "compte : 33", ViewNodeBridge.getText(gabarit));

		var deux = aui.ui.Text.withState("{count}/{mot}");
		check("plusieurs noms dans un gabarit",
			ViewNodeBridge.getText(deux) == "33/ab", ViewNodeBridge.getText(deux));

		// An unknown name stays as written: `{cont}` on screen says the name is
		// wrong, an empty string says nothing at all.
		var faute = aui.ui.Text.withState("x{cont}y");
		check("un nom inconnu reste visible",
			ViewNodeBridge.getText(faute) == "x{cont}y", ViewNodeBridge.getText(faute));

		var brut = aui.ui.Text.withState("sans accolade");
		check("un gabarit sans nom passe tel quel",
			ViewNodeBridge.getText(brut) == "sans accolade", ViewNodeBridge.getText(brut));

		var boiteux = aui.ui.Text.withState("ouvert {count");
		check("une accolade non fermée ne boucle pas",
			ViewNodeBridge.getText(boiteux) == "ouvert {count", ViewNodeBridge.getText(boiteux));

		// --- what the bridge answers before setApp() ---
		//
		// Kotlin composes before the app is handed over, for at least one frame.
		check("le pont répond avant setApp()", ViewNodeBridge.getRoot() == null);
		check("et ne jette pas en lisant un noeud nul",
			ViewNodeBridge.getType(null) == "" && ViewNodeBridge.childCount(null) == 0);

		// --- the tree the bridge hands to Kotlin ---
		ViewNodeBridge.setApp(new DemoApp());
		var handed = ViewNodeBridge.getRoot();
		check("setApp() construit un arbre", handed != null);
		check("le pont décrit cet arbre", ViewNodeBridge.getType(handed) == "VStack",
			ViewNodeBridge.getType(handed));

		// A rebuild re-runs body(): this is what makes a write visible, since
		// the tree holds values read when body() ran.
		var before = ViewNodeBridge.getText(ViewNodeBridge.getChild(handed, 0));
		DemoApp.compteur.set(7);
		ViewNodeBridge.rebuild();
		var after = ViewNodeBridge.getText(ViewNodeBridge.getChild(ViewNodeBridge.getRoot(), 0));
		check("rebuild() rend l'écriture visible", before != after, '"$before" -> "$after"');
		check("et rend la nouvelle valeur", after == "compteur : 7", after);

		Sys.println(failures == 0 ? "\nall good" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

/** The smallest thing that is an app: a body() built from an observable. **/
class DemoApp extends aui.App {
	public static var compteur = new State<Int>(0, "compteur");

	public function new() {
		super();
	}

	override public function body():View {
		return new VStack(null, null, [
			new Text("compteur : " + compteur.get()),
			new Button("Plus", Increment(compteur))
		]);
	}
}
