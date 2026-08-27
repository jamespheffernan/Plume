#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_ID="com.turfterrace.plume.ios"
TEAM_ID="7W38KL8969"
SCHEME="BreatheClock"
PROJECT="BreatheClock.xcodeproj"
IDENTITY="iPhone Distribution: Turf Terrace Ltd (7W38KL8969)"

API_KEY_ID="${APPSTORE_CONNECT_API_KEY_ID:-V6Z64QFY9P}"
API_ISSUER_ID="${APPSTORE_CONNECT_API_ISSUER_ID:-6344e0a2-d5a0-42f2-be15-bca31eeb9a13}"
API_KEY_PATH="${APPSTORE_CONNECT_API_PRIVATE_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8}"

XCODE_DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ -z "$XCODE_DEVELOPER_DIR" || ! -x "$XCODE_DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "No usable Xcode developer directory found. Set DEVELOPER_DIR to an Xcode.app Contents/Developer path." >&2
  exit 2
fi

export DEVELOPER_DIR="$XCODE_DEVELOPER_DIR"

PREBUILT_ARCHIVE_PATH="${PLUME_PREBUILT_ARCHIVE_PATH:-}"
if [[ -z "$PREBUILT_ARCHIVE_PATH" ]]; then
  "$ROOT_DIR/scripts/verify_release_toolchain.sh" --developer-dir "$XCODE_DEVELOPER_DIR"
fi

SIGNING_ROOT="$HOME/.appstoreconnect/plume-signing"
if [[ -z "${PLUME_SIGNING_DIR:-}" ]]; then
  PLUME_SIGNING_DIR="$(find "$SIGNING_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1)"
fi

if [[ -z "${PLUME_SIGNING_DIR:-}" || ! -d "$PLUME_SIGNING_DIR" ]]; then
  echo "No signing directory found. Expected PLUME_SIGNING_DIR or a directory under $SIGNING_ROOT." >&2
  exit 2
fi

PROFILE_SRC="$PLUME_SIGNING_DIR/Plume_App_Store.mobileprovision"
PROFILE_PLIST="$PLUME_SIGNING_DIR/Plume_App_Store.plist"

if [[ ! -f "$PROFILE_SRC" ]]; then
  echo "Missing App Store provisioning profile: $PROFILE_SRC" >&2
  exit 2
fi

if [[ ! -f "$API_KEY_PATH" ]]; then
  echo "Missing App Store Connect API key: $API_KEY_PATH" >&2
  exit 2
fi

security cms -D -i "$PROFILE_SRC" > "$PROFILE_PLIST"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print UUID' "$PROFILE_PLIST")"
PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print Name' "$PROFILE_PLIST")"
PROFILE_TEAM="$(/usr/libexec/PlistBuddy -c 'Print TeamIdentifier:0' "$PROFILE_PLIST")"
PROFILE_APP_ID="$(/usr/libexec/PlistBuddy -c 'Print Entitlements:application-identifier' "$PROFILE_PLIST")"

if [[ "$PROFILE_TEAM" != "$TEAM_ID" ]]; then
  echo "Profile team mismatch: got $PROFILE_TEAM, expected $TEAM_ID." >&2
  exit 2
fi

if [[ "$PROFILE_APP_ID" != "$TEAM_ID.$BUNDLE_ID" ]]; then
  echo "Profile app id mismatch: got $PROFILE_APP_ID, expected $TEAM_ID.$BUNDLE_ID." >&2
  exit 2
fi

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$PROFILE_SRC" "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"

KEYCHAIN_PASSWORD="${PLUME_KEYCHAIN_PASSWORD:-}"
if [[ -z "$KEYCHAIN_PASSWORD" && -f "$PLUME_SIGNING_DIR/keychain-password.txt" ]]; then
  KEYCHAIN_PASSWORD="$(<"$PLUME_SIGNING_DIR/keychain-password.txt")"
fi

if [[ -z "$KEYCHAIN_PASSWORD" ]]; then
  echo "Missing Plume build keychain password. Set PLUME_KEYCHAIN_PASSWORD or provide $PLUME_SIGNING_DIR/keychain-password.txt." >&2
  exit 2
fi

if [[ -n "${PLUME_KEYCHAIN_PATH:-}" ]]; then
  KEYCHAIN="$PLUME_KEYCHAIN_PATH"
  if [[ ! -f "$KEYCHAIN" ]]; then
    echo "Missing build keychain: $KEYCHAIN" >&2
    exit 2
  fi

  if ! security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"; then
    echo "The Plume keychain password could not unlock $KEYCHAIN." >&2
    exit 2
  fi
else
  KEYCHAIN=""
  KEYCHAIN_CANDIDATES=("$PLUME_SIGNING_DIR/plume-build.keychain-db")
  while IFS= read -r CANDIDATE; do
    KEYCHAIN_CANDIDATES+=("$CANDIDATE")
  done < <(find "$PLUME_SIGNING_DIR" -maxdepth 1 -type f -name 'plume-build.keychain-db.*' -print | sort -r)

  for CANDIDATE in "${KEYCHAIN_CANDIDATES[@]}"; do
    if [[ -f "$CANDIDATE" ]] \
      && security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$CANDIDATE" >/dev/null 2>&1 \
      && security find-identity -v -p codesigning "$CANDIDATE" | grep -Fq "$IDENTITY"; then
      KEYCHAIN="$CANDIDATE"
      break
    fi
  done

  if [[ -z "$KEYCHAIN" ]]; then
    echo "No build keychain in $PLUME_SIGNING_DIR could be unlocked with the saved Plume password and provide $IDENTITY." >&2
    exit 2
  fi
fi

echo "Using signing keychain: $KEYCHAIN"

USER_KEYCHAINS=()
while IFS= read -r USER_KEYCHAIN; do
  USER_KEYCHAINS+=("$USER_KEYCHAIN")
done < <(security list-keychains -d user | sed 's/^ *"//;s/"$//')
KEYCHAIN_LISTED=0
for USER_KEYCHAIN in "${USER_KEYCHAINS[@]}"; do
  if [[ "$USER_KEYCHAIN" == "$KEYCHAIN" ]]; then
    KEYCHAIN_LISTED=1
    break
  fi
done

if [[ "$KEYCHAIN_LISTED" == "0" ]]; then
  security list-keychains -d user -s "$KEYCHAIN" "${USER_KEYCHAINS[@]}"
fi

if ! security find-identity -v -p codesigning "$KEYCHAIN" | grep -Fq "$IDENTITY"; then
  echo "Signing identity not found in $KEYCHAIN: $IDENTITY" >&2
  exit 2
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${PLUME_OUTPUT_DIR:-$ROOT_DIR/build/testflight/$STAMP}"
BUILD_NUMBER="${PLUME_BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
ARCHIVE_PATH="${PREBUILT_ARCHIVE_PATH:-$OUT_DIR/Plume.xcarchive}"
EXPORT_DIR="$OUT_DIR/export"
EXPORT_OPTIONS="$OUT_DIR/ExportOptions.plist"

mkdir -p "$OUT_DIR"

cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>app-store-connect</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>$BUNDLE_ID</key>
    <string>$PROFILE_NAME</string>
  </dict>
  <key>signingCertificate</key>
  <string>$IDENTITY</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF

rm -rf "$EXPORT_DIR"

if [[ -z "$PREBUILT_ARCHIVE_PATH" ]]; then
  rm -rf "$ARCHIVE_PATH"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_IDENTITY="$IDENTITY" \
    PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" \
    PROVISIONING_PROFILE="$PROFILE_UUID" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN" \
    | tee "$OUT_DIR/archive.log"
else
  [[ -d "$ARCHIVE_PATH" ]] || {
    echo "Prebuilt archive is missing: $ARCHIVE_PATH" >&2
    exit 2
  }
  echo "Using prebuilt archive: $ARCHIVE_PATH"
fi

"$ROOT_DIR/scripts/verify_release_toolchain.sh" --archive "$ARCHIVE_PATH" \
  | tee "$OUT_DIR/toolchain.log"

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  | tee "$OUT_DIR/export.log"

IPA="$EXPORT_DIR/Plume.ipa"
xcrun altool \
  --validate-app \
  --type ios \
  --file "$IPA" \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER_ID" \
  | tee "$OUT_DIR/validation.log"

if [[ "${PLUME_SKIP_UPLOAD:-}" == "1" ]]; then
  echo "Built and validated IPA without upload: $IPA"
  exit 0
fi

xcrun altool \
  --upload-app \
  --type ios \
  --file "$IPA" \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER_ID" \
  | tee "$OUT_DIR/upload.log"

echo "Uploaded IPA: $IPA"
