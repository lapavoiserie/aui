#!/usr/bin/env bash
#
# The Kotlin runtime compiles. Not "reads correctly" -- compiles, against the
# real Compose.
#
#   ./test/kotlin-check.sh
#
# This half of `aui` was unverifiable here for as long as anyone had looked:
# every commit touching `runtime/` said "the Kotlin half is read, not
# compiled". It is not true any more, and what makes it work is worth writing
# down, because getting there took four wrong turns:
#
#   1. It needs a whole generated Android project, not a bare file. An example
#      already carries one, so the check builds a COPY of one outside the
#      repository and leaves the working tree alone.
#   2. `app-logic.jar` is the app's Haxe compiled to the JVM, and the Kotlin
#      references its `ViewNodeBridge`. A stale jar fails with dozens of
#      "unresolved reference" that look like Kotlin errors and are not.
#   3. So `haxe build.hxml` runs FIRST. It also installs `runtime/*.kt` into
#      the project itself -- `AuiFonts.kt` among them, which is generated per
#      application and which `DynamicComposable.kt` references. Copying the
#      runtime files by hand instead gets duplicate declarations in one
#      package and a missing font table.
#   4. `--offline`, so a check does not depend on a network.
#
# It compiles; it does not run, and nothing here has been seen on a screen.

set -u
cd "$(dirname "$0")/.."
repo="$(pwd)"

if ! command -v gradle >/dev/null 2>&1 && [ ! -x examples/todo-app/android/gradlew ]; then
	echo "skip no Gradle wrapper"
	exit 0
fi
if [ ! -d "$HOME/Library/Android/sdk" ]; then
	echo "skip no Android SDK"
	exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -R examples/todo-app/. "$work/" || exit 1

# The example's build.hxml reaches the library by a relative path that the
# copy has moved away from.
sed -i '' "s|-cp ../../src|-cp $repo/src|" "$work/build.hxml"
grep -q -- "-lib kui" "$work/build.hxml" || sed -i '' "s|-lib nui|-lib nui\\
-lib kui|" "$work/build.hxml"

(cd "$work" && haxe build.hxml) >/dev/null 2>&1 || { echo "FAIL the example's Haxe did not build"; exit 1; }

out=$(cd "$work/android" && ./gradlew :app:compileDebugKotlin --offline 2>&1)
if echo "$out" | grep -q "BUILD SUCCESSFUL"; then
	echo "ok   the Kotlin runtime compiles against Compose"
	echo ""
	echo "all good"
	exit 0
fi

echo "$out" | grep -E "^e: " | sed 's|.*/kotlin/||' | head -20
echo ""
echo "failed"
exit 1
