package aui.mui;

import mui.ui.TextScale;

/**
	`aui`'s conformance for `mui.ui.Text`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
class Text extends aui.ui.Text {
    public function new(content:String, ?scale:TextScale) {
        super(content);
        if (scale != null) font(switch (scale) {
            // Material's Display steps are for a single number filling a
            // screen, not for a page title. Headline is the step its own
            // guidance points at, which is where the mapping starts.
            case Title: aui.modifiers.ViewModifier.FontStyle.HeadlineSmall;
            case Subtitle: aui.modifiers.ViewModifier.FontStyle.TitleMedium;
            case Body: aui.modifiers.ViewModifier.FontStyle.BodyLarge;
            case Caption: aui.modifiers.ViewModifier.FontStyle.BodySmall;
        });
    }
}
