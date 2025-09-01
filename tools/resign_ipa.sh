#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 5 ]]; then
  echo "Usage: $0 <IPA_PATH> <PROVISION_PATH> <SIGN_ID> <TEAMID> <BUNDLEID> [ENTITLEMENTS_PLIST]" >&2
  exit 1
fi
IPA="$1"; PROV="$2"; SIGN_ID="$3"; TEAMID="$4"; BUNDLEID="$5"; ENT="${6:-tools/entitlements.plist}"
WORKDIR="$(mktemp -d -t resign-XXXX)"; trap 'rm -rf "$WORKDIR"' EXIT
unzip -q "$IPA" -d "$WORKDIR"
APPDIR="$(/usr/bin/find "$WORKDIR/Payload" -maxdepth 1 -name "*.app" -type d | head -n1)"
cp "$PROV" "$APPDIR/embedded.mobileprovision"
INFO_PLIST="$APPDIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLEID" "$INFO_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLEID" "$INFO_PLIST"
ENT_FIXED="$WORKDIR/entitlements.fixed.plist"; /usr/bin/sed -e "s/TEAMID/$TEAMID/g" -e "s/BUNDLEID/$BUNDLEID/g" "$ENT" > "$ENT_FIXED"
if [[ -d "$APPDIR/Frameworks" ]]; then
  find "$APPDIR/Frameworks" -type f \( -name "*.framework" -o -name "*.dylib" -o -name "*.so" \) -print0 | while IFS= read -r -d '' FW; do
    codesign -f -s "$SIGN_ID" --timestamp=none "$FW"
  done
fi
if [[ -d "$APPDIR/PlugIns" ]]; then
  find "$APPDIR/PlugIns" -type d -name "*.appex" -print0 | while IFS= read -r -d '' APPEX; do
    codesign -f -s "$SIGN_ID" --timestamp=none "$APPEX"
  done
fi
codesign -f -s "$SIGN_ID" --entitlements "$ENT_FIXED" --timestamp=none "$APPDIR"
codesign --verify --deep --strict "$APPDIR"
( cd "$WORKDIR" && zip -qry "$(pwd)/$(basename "${IPA%.ipa}")-resigned.ipa" Payload )
