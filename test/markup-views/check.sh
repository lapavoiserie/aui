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

# A button written in markup: the canon's `onClick` closure. aui had no
# closure-carrying control at all, so `<Button>` was not in its vocabulary.
# Run on the JVM, through the calls DynamicComposable.kt makes when pressed.
jar=/tmp/aui-button.jar
if haxe $common -D mui_views --macro "aui.nui.Vocabulary.registerWithMui()" \
		-main AuiButton -D jvm --jvm $jar 2>/dev/null \
		&& java -jar $jar 2>&1 | grep -q "actionId: 0 | presses: 2"; then
	echo "ok   a markup Button runs its closure, by node and by action id"
else
	echo "FAIL a markup Button did not run its closure:"; java -jar $jar 2>&1 | head -3; fails=$((fails + 1))
fi

# A displayed value computed from a cell is deferred. It was not, for any
# markup screen: `LiveProps` wraps the constructors of body() AS WRITTEN, and
# markup's appear only when ui() expands. Every write rebuilt the tree.
jar=/tmp/aui-live.jar
if haxe $common -D mui_views --macro "aui.nui.Vocabulary.registerWithMui()" \
		-main AuiLive -D jvm --jvm $jar 2>/dev/null \
		&& java -jar $jar 2>&1 | grep -q "deferred: true"; then
	echo "ok   a value markup computes from a cell is deferred, so the cell is not structural"
else
	echo "FAIL a markup value was read while building the tree:"; java -jar $jar 2>&1 | head -3; fails=$((fails + 1))
fi

echo ""
[ "$fails" -eq 0 ] && echo "all good" || echo "$fails failed"
exit "$fails"
