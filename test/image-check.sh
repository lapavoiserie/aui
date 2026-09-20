#!/usr/bin/env bash
#
# The app RUNS, and here is the picture.
#
#   ./test/image-check.sh [out.png]
#
# `test/kotlin-check.sh` proves the runtime compiles. Compiling is not
# drawing: three defects this month were things that compiled, crossed the
# wire, and reached no pixel. This one builds an example, installs it on an
# Android emulator and takes a screenshot.
#
# It needs an emulator. If none is running it does NOT start one -- booting
# one takes minutes and RAM on somebody's machine, and a check should not
# decide that by itself. Start one first:
#
#   ~/Library/Android/sdk/emulator/emulator -avd <name> -no-window -no-audio &
#
# `-no-window` matters: the picture comes from `adb exec-out screencap`, which
# works headless, so nobody's screen is taken over for a test.

set -u
cd "$(dirname "$0")/.."
repo="$(pwd)"
out="${1:-$(pwd)/aui-screen.png}"

SDK="$HOME/Library/Android/sdk"
ADB="$SDK/platform-tools/adb"
[ -x "$ADB" ] || { echo "skip no adb"; exit 0; }

if ! "$ADB" devices | grep -q "device$"; then
	echo "skip no emulator running -- see the header for how to start one"
	exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -R examples/todo-app/. "$work/" || exit 1
sed -i '' "s|-cp ../../src|-cp $repo/src|" "$work/build.hxml"
grep -q -- "-lib kui" "$work/build.hxml" || sed -i '' "s|-lib nui|-lib nui\\
-lib kui|" "$work/build.hxml"

(cd "$work" && haxe build.hxml) >/dev/null 2>&1 || { echo "FAIL the example's Haxe did not build"; exit 1; }
(cd "$work/android" && ./gradlew :app:assembleDebug --offline -q) >/dev/null 2>&1 \
	|| { echo "FAIL the APK did not build"; exit 1; }

apk="$work/android/app/build/outputs/apk/debug/app-debug.apk"
"$ADB" install -r "$apk" >/dev/null 2>&1 || { echo "FAIL install"; exit 1; }
"$ADB" shell monkey -p com.aui.todo -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

# Compose has to lay out and draw before there is anything to photograph.
# Screenshotting immediately gets a white rectangle, which is exactly the
# false green this check exists to avoid.
sleep 6
"$ADB" exec-out screencap -p > "$out" 2>/dev/null

size=$(wc -c < "$out" | tr -d ' ')
if [ "$size" -lt 20000 ]; then
	echo "FAIL the screenshot is $size bytes -- too small to be a drawn screen"
	exit 1
fi

echo "ok   the app runs, and drew $size bytes: $out"
echo ""
echo "all good"
