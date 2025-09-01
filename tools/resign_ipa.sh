#!/bin/bash
set -euo pipefail

if [ $# -ne 6 ]; then
  echo "Usage: $0 <ipa_path> <provision_path> <sign_identity> <team_id> <bundle_id> <entitlements_plist>" >&2
  exit 1
fi

IPA_PATH="$1"
PROVISION="$2"
SIGN_ID="$3"
TEAM_ID="$4"
BUNDLE_ID="$5"
ENTITLEMENTS="$6"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "Unzipping IPA..."
unzip -q "$IPA_PATH" -d "$WORKDIR"

APP=$(find "$WORKDIR/Payload" -maxdepth 1 -name "*.app" -type d | head -n1)
if [ -z "$APP" ]; then
  echo "Could not find .app bundle in IPA" >&2
  exit 1
fi

echo "Replacing provisioning profile..."
cp "$PROVISION" "$APP/embedded.mobileprovision"

echo "Updating Info.plist with bundle identifier..."
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Info.plist"
/usr/libexec/PlistBuddy -c "Set :application-identifier $TEAM_ID.$BUNDLE_ID" "$APP/Info.plist" || true

echo "Cleaning old signatures..."
rm -rf "$APP/_CodeSignature"
find "$APP" \( -name "*.framework" -o -name "*.dylib" \) | while IFS= read -r BUNDLE; do
  rm -rf "$BUNDLE/_CodeSignature"
done

echo "Resigning frameworks and dylibs..."
find "$APP" \( -name "*.framework" -o -name "*.dylib" \) | while IFS= read -r BUNDLE; do
  codesign -fs "$SIGN_ID" --entitlements "$ENTITLEMENTS" "$BUNDLE"
done

echo "Resigning app..."
codesign -fs "$SIGN_ID" --entitlements "$ENTITLEMENTS" "$APP"

OUTPUT="${IPA_PATH%.ipa}-resigned.ipa"
echo "Repacking IPA to $OUTPUT..."
(
  cd "$WORKDIR"
  zip -qr "$OUTPUT" Payload
)
mv "$WORKDIR/$OUTPUT" "$(dirname "$IPA_PATH")/"

echo "Done: $(dirname "$IPA_PATH")/${OUTPUT}"
