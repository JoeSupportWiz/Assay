#!/usr/bin/env bash
# Render every top-level screen of the app in the iOS Simulator, in light and dark.
# Usage: scripts/screenshots.sh <path/to/Assay.app> <out-dir>
set -euo pipefail
APP="$1"; OUT="$2"
BUNDLE=com.joesupportwiz.assay
mkdir -p "$OUT"

RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x["platform"]=="iOS" and x["isAvailable"]]; print(r[-1]["identifier"])')
TYPE=$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; t=[x["identifier"] for x in json.load(sys.stdin)["devicetypes"] if "iPhone" in x["name"] and "Pro" in x["name"] and "Max" not in x["name"]]; print(t[-1])')
echo "Runtime $RUNTIME · device $TYPE"
UDID=$(xcrun simctl create AssayShots "$TYPE" "$RUNTIME")
trap 'xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true; xcrun simctl delete "$UDID" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
for attempt in 1 2 3 4; do
  if xcrun simctl install "$UDID" "$APP"; then break; fi
  echo "install attempt $attempt failed; rebooting simulator"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true; sleep 8
  xcrun simctl boot "$UDID"; xcrun simctl bootstatus "$UDID" -b; sleep 5
  [ "$attempt" = 4 ] && { echo "install failed 4 times"; exit 1; }
done

shot() { # name, appearance, args...
  local name="$1" look="$2"; shift 2
  xcrun simctl ui "$UDID" appearance "$look"
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null
  sleep 4
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null
  echo "  ✓ $name"
}

for look in light dark; do
  shot "00-onboarding-$look"  "$look" -onboarding
  shot "01-home-$look"        "$look" -uiDemo -tab home
  shot "02-lab-$look"         "$look" -uiDemo -tab lab
  shot "03-diagnose-$look"    "$look" -uiDemo -route diagnose
  shot "04-symptom-$look"     "$look" -uiDemo -route symptom:clock-941
  shot "05-fix-review-$look"  "$look" -uiDemo -route fix:clock-941
  shot "06-history-$look"     "$look" -uiDemo -route history
  shot "07-studio-$look"      "$look" -uiDemo -tab studio
  shot "08-more-$look"        "$look" -uiDemo -tab more
  shot "09-gild-$look"        "$look" -uiDemo -route gild
  shot "10-tweak-$look"       "$look" -uiDemo -route tweak:SBShowStatusBarOverridesForRecording
  shot "11-staged-$look"      "$look" -uiDemo -route gild-staged
  shot "12-bluetooth-$look"   "$look" -uiDemo -route bluetooth
  shot "13-network-$look"     "$look" -uiDemo -route network
  shot "14-signet-$look"      "$look" -uiDemo -route signet
  shot "15-alchemy-$look"     "$look" -uiDemo -route alchemy
  shot "16-minis-$look"       "$look" -uiDemo -route minis-report
  shot "17-minis-review-$look" "$look" -uiDemo -route minis-report -minisReportPreview
done
shot "01-home-millennium" light -uiDemo -tab home -theme millennium
shot "01-home-pinstripe"  light -uiDemo -tab home -theme pinstripe
shot "01-home-wallpaper"  dark  -uiDemo -tab home -theme wallpaper
shot "09-gild-millennium" light -uiDemo -route gild -theme millennium
shot "09-gild-pinstripe"  light -uiDemo -route gild -theme pinstripe
shot "09-gild-wallpaper"  dark  -uiDemo -route gild -theme wallpaper

# Contact sheet for quick review
python3 - "$OUT" <<'PY'
import sys, pathlib
out = pathlib.Path(sys.argv[1])
imgs = sorted(p.name for p in out.glob("*.png"))
rows = "\n".join(f'<td align="center"><img src="{n}" width="200"><br><sub>{n[:-4]}</sub></td>' + ("</tr><tr>" if (i+1) % 4 == 0 else "") for i, n in enumerate(imgs))
(out / "README.md").write_text(f"# App screenshots\n\nRendered by CI in the iOS Simulator (demo engine, 9:41 status bar).\n\n<table><tr>{rows}</tr></table>\n")
PY
echo "Done: $(ls "$OUT"/*.png | wc -l) screenshots"
