#!/usr/bin/env bash
#
# Checks the aui end of the Companion pipe: describe (canonical nodes,
# through the LiveProps thunks) → snapshot → wire → inflate → invoke — the
# closures and cells must answer across the loop. Judged on the exit code.
#
# On the JVM like NuiCheck: aui's State needs the StateBridge stub, which
# the interpreter cannot stand in for.
#
#   ./test/describe.sh

set -u
cd "$(dirname "$0")/.."

javac -d test/stubs-classes test/stubs/aui/state/StateBridge.java || exit 1

haxe -cp src -cp test \
	-lib mui -lib kui -lib rui -lib nui \
	-D mui_backend=aui \
	--macro "mui.macros.Bind.all()" \
	--macro "aui.kui.Platform.registerWithKui()" \
	-D jvm --jvm test/describe-check.jar \
	-main DescribeCheck || exit 1

java -cp "test/describe-check.jar:test/stubs-classes" haxe.root.DescribeCheck
