#!/usr/bin/env bash
#
# Markup builds aui's OWN controls, not a node.
#
#   ./test/markup-views/check.sh
#
# Type-checked, never run: `aui.state.StateBridge` is bound to the JVM, so
# the interpreter cannot make a cell. What is being proved is a TYPE --
# `ui(<VStack>…)` answers an `aui.View` -- so type-checking is the whole of it.
#
# It matters here because this backend DESCRIBES and never builds a view out
# of a node. Markup that produced a node could not reach it at all except by
# going out over a wire and coming back.

set -u
cd "$(dirname "$0")/../.."
common="-cp src -cp test/markup-views -lib rui -lib nui -lib mui -D mui_backend=aui"
fails=0

if haxe $common -D mui_views --macro "aui.nui.Vocabulary.registerWithMui()" \
		-main AuiMarkup -D jvm --jvm /tmp/aui-views.jar --no-output 2>/dev/null; then
	echo "ok   markup builds aui's own controls"
else
	echo "FAIL markup did not build aui's own controls:"
	haxe $common -D mui_views --macro "aui.nui.Vocabulary.registerWithMui()" \
		-main AuiMarkup -D jvm --jvm /tmp/aui-views.jar --no-output
	fails=$((fails + 1))
fi

# Without the flag the same source does not even mean the same thing: the node
# path wants a Bool where the view path wants the cell. Asserted rather than
# assumed -- a check that passed either way would say nothing.
out=$(haxe $common --macro "aui.nui.Vocabulary.registerWithMui()" \
	-main AuiMarkup -D jvm --jvm /tmp/aui-views.jar --no-output 2>&1)
if echo "$out" | grep -q "should be Bool"; then
	echo "ok   and without -D mui_views the node path wants a value, not a cell"
else
	echo "FAIL the flag made no difference:"; echo "$out"; fails=$((fails + 1))
fi

echo ""
[ "$fails" -eq 0 ] && echo "all good" || echo "$fails failed"
exit "$fails"
