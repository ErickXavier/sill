#!/bin/bash
# The iOS app photographed in simulators of its own (created here, deleted after): the real app's
# first screen, then the layout harness (iOSClient/ContentView.swift's contract) in each case.
#   Scripts/screenshots/ios.sh APP OUTDIR
# CI only (.github/workflows/apple-screenshots.yml): it creates and deletes simulators.
set -uo pipefail
app=$1; out=$2; mkdir -p "$out"
bundle=me.saffer.sill
xcrun simctl list runtimes
runtime=$(xcrun simctl list runtimes -j | python3 -c '
import json,sys
rs=[r for r in json.load(sys.stdin)["runtimes"] if r["platform"]=="iOS" and r["isAvailable"]]
rs.sort(key=lambda r:[int(x) for x in r["version"].split(".")])
print(rs[-1]["identifier"])')
echo "runtime: $runtime"
types=$(xcrun simctl list devicetypes -j)
pick() { # the newest device type whose name matches
    python3 -c '
import json,sys,re
ts=[t for t in json.loads(sys.argv[1])["devicetypes"] if re.search(sys.argv[2],t["name"])]
print(ts[-1]["identifier"] if ts else "")' "$types" "$1"
}
made="$out/.made"; : > "$made"
mksim() { # name type → udid, booted
    local t; t=$(pick "$2"); [ -n "$t" ] || { echo "no device type for $2" >&2; return 1; }
    local u; u=$(xcrun simctl create "Sill shots $1" "$t" "$runtime") || return 1
    echo "$u" >> "$made"
    { xcrun simctl boot "$u"; xcrun simctl bootstatus "$u" -b
      xcrun simctl status_bar "$u" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3
      xcrun simctl install "$u" "$app"; } >&2
    echo "$u"
}
shot() { # udid name seconds args…
    local u=$1 name=$2 wait=$3; shift 3
    xcrun simctl terminate "$u" "$bundle" 2>/dev/null
    xcrun simctl launch "$u" "$bundle" "$@" >/dev/null || { echo "launch failed: $name"; return; }
    sleep "$wait"
    xcrun simctl io "$u" screenshot --type=png "$out/$name.png" >/dev/null 2>&1 && echo "shot $name"
}
cleanup() { while read -r u; do xcrun simctl shutdown "$u" 2>/dev/null; xcrun simctl delete "$u" 2>/dev/null; done < "$made"; rm -f "$made"; }
trap cleanup EXIT

if ipad=$(mksim ipad 'iPad Pro.*13'); then
    shot "$ipad" ipad-01-real-app 6
    shot "$ipad" ipad-02-stream          5 -SillLayout 1000x710
    shot "$ipad" ipad-03-drawer          5 -SillLayout 1000x710 -SillDrawer 1
    shot "$ipad" ipad-04-settings        5 -SillLayout 1000x710 -SillSettings 1
    shot "$ipad" ipad-05-settings-gestures 5 -SillLayout 1000x710 -SillSettings 1 -SillSettingsScroll gestures
    shot "$ipad" ipad-06-aa-ruler        5 -SillLayout 1000x710 -SillScaleOpen 1
    shot "$ipad" ipad-07-window-lights   5 -SillLayout 1000x710 -SillWindowMenu 1
    shot "$ipad" ipad-08-menus           6 -SillLayout 1000x710 -SillMenusOpen 1
    shot "$ipad" ipad-09-clipboard-chip  5 -SillLayout 1000x710 -SillClipboardChip 1
    shot "$ipad" ipad-10-tour            6 -SillLayout 1000x710 -SillTourState fresh -SillTour touch
    shot "$ipad" ipad-11-portrait-laptop 5 -SillLayout 710x1000
    shot "$ipad" ipad-12-portrait-keyboard 5 -SillLayout 710x1000 -SillKeyboard 1
    shot "$ipad" ipad-13-connect-methods 5 -SillLayout 1000x710 -SillConnectCase methods
    shot "$ipad" ipad-14-connect-addmac  5 -SillLayout 1000x710 -SillConnectCase addmac
    shot "$ipad" ipad-15-connect-homecard 5 -SillLayout 1000x710 -SillConnectCase homecard
    shot "$ipad" ipad-16-pairing-overlay 5 -SillLayout 1000x710 -SillScanOverlay 1
    shot "$ipad" ipad-17-settings-away   5 -SillLayout 1000x710 -SillSettings 1 -SillSettingsCase away
    shot "$ipad" ipad-18-link-line       5 -SillLayout 1000x710 -SillLinkLine behind
    shot "$ipad" duo-01-book             5 -SillLayout 951x669 -SillHinge half
    shot "$ipad" duo-02-laptop           5 -SillLayout 669x951 -SillHinge half
    shot "$ipad" duo-03-flat-upright     5 -SillLayout 669x951 -SillHinge flat
    shot "$ipad" duo-04-flat-sideways    5 -SillLayout 951x669 -SillHinge flat
    shot "$ipad" duo-05-cover-upright    5 -SillLayout 466x678 -SillHinge closed
    shot "$ipad" duo-06-cover-sideways   5 -SillLayout 678x466 -SillHinge closed
    shot "$ipad" duo-07-book-settings    5 -SillLayout 951x669 -SillHinge half -SillSettings 1
fi
if phone=$(mksim iphone 'iPhone.*Pro Max'); then
    shot "$phone" iphone-01-real-app 6
    shot "$phone" iphone-02-portrait     5 -SillLayout 440x956
    shot "$phone" iphone-03-portrait-keyboard 5 -SillLayout 440x956 -SillKeyboard 1
    shot "$phone" iphone-04-larger-picture 5 -SillLayout 440x956 -Sill.largerPicture 1
    shot "$phone" iphone-05-drawer       5 -SillLayout 440x956 -SillDrawer 1
    shot "$phone" iphone-06-settings     5 -SillLayout 440x956 -SillSettings 1
    shot "$phone" iphone-07-connect      5 -SillLayout 440x956 -SillConnectCase methods
    shot "$phone" iphone-08-tour         6 -SillLayout 440x956 -SillTourState fresh -SillTour bar
fi
if duo=$(mksim duo 'iPhone Duo'); then
    shot "$duo" duodevice-01-real-app 6
    shot "$duo" duodevice-02-stream 5 -SillLayout 951x669 -SillHinge half
fi
ls -la "$out"
