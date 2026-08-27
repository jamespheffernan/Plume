#!/usr/bin/env bash
set -euo pipefail

EXPECTED_XCODE_BUILD="${PLUME_EXPECTED_XCODE_BUILD:-17F113}"
EXPECTED_SDK_NAME="${PLUME_EXPECTED_SDK_NAME:-iphoneos26.5}"
EXPECTED_SDK_BUILD="${PLUME_EXPECTED_SDK_BUILD:-23F81a}"
SUPPORTED_HOST_BUILD_REGEX="${PLUME_SUPPORTED_HOST_BUILD_REGEX:-^25[A-Z][0-9]+$}"

usage() {
  cat <<'MSG'
Usage:
  verify_release_toolchain.sh --developer-dir PATH
  verify_release_toolchain.sh --archive PATH

Checks the exact Xcode, iOS SDK, and macOS host stamps used for a Plume release.
MSG
}

fail() {
  echo "Release toolchain check failed: $*" >&2
  exit 1
}

check_values() {
  local source="$1"
  local xcode_build="$2"
  local sdk_name="$3"
  local sdk_build="$4"
  local host_build="$5"

  echo "Toolchain source: $source"
  echo "DTXcodeBuild=$xcode_build"
  echo "DTSDKName=$sdk_name"
  echo "DTSDKBuild=$sdk_build"
  echo "BuildMachineOSBuild=$host_build"

  [[ "$xcode_build" == "$EXPECTED_XCODE_BUILD" ]] || \
    fail "DTXcodeBuild is $xcode_build; expected $EXPECTED_XCODE_BUILD."
  [[ "$sdk_name" == "$EXPECTED_SDK_NAME" ]] || \
    fail "DTSDKName is $sdk_name; expected $EXPECTED_SDK_NAME."
  [[ "$sdk_build" == "$EXPECTED_SDK_BUILD" ]] || \
    fail "DTSDKBuild is $sdk_build; expected $EXPECTED_SDK_BUILD."
  [[ "$host_build" =~ $SUPPORTED_HOST_BUILD_REGEX ]] || \
    fail "BuildMachineOSBuild is $host_build; expected a released macOS 26 build that matches $SUPPORTED_HOST_BUILD_REGEX."

  echo "Release toolchain check passed."
}

[[ "$#" == 2 ]] || {
  usage >&2
  exit 2
}

case "$1" in
  --developer-dir)
    developer_dir="$2"
    [[ -x "$developer_dir/usr/bin/xcodebuild" ]] || \
      fail "No xcodebuild exists under $developer_dir."

    xcode_contents="$(cd "$developer_dir/.." && pwd)"
    xcode_build="$(/usr/libexec/PlistBuddy -c 'Print ProductBuildVersion' "$xcode_contents/version.plist")"
    sdk_path="$(DEVELOPER_DIR="$developer_dir" /usr/bin/xcrun --sdk iphoneos --show-sdk-path)"
    sdk_name="$(/usr/libexec/PlistBuddy -c 'Print CanonicalName' "$sdk_path/SDKSettings.plist")"
    sdk_build="$(DEVELOPER_DIR="$developer_dir" /usr/bin/xcrun --sdk iphoneos --show-sdk-build-version)"
    host_build="$(sw_vers -buildVersion)"
    check_values "$developer_dir" "$xcode_build" "$sdk_name" "$sdk_build" "$host_build"
    ;;
  --archive)
    archive="$2"
    archive_info="$archive/Info.plist"
    [[ -f "$archive_info" ]] || fail "Archive Info.plist is missing: $archive_info"
    app_rel="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:ApplicationPath' "$archive_info")"
    app_info="$archive/Products/$app_rel/Info.plist"
    [[ -f "$app_info" ]] || fail "App Info.plist is missing: $app_info"

    xcode_build="$(/usr/libexec/PlistBuddy -c 'Print DTXcodeBuild' "$app_info")"
    sdk_name="$(/usr/libexec/PlistBuddy -c 'Print DTSDKName' "$app_info")"
    sdk_build="$(/usr/libexec/PlistBuddy -c 'Print DTSDKBuild' "$app_info")"
    host_build="$(/usr/libexec/PlistBuddy -c 'Print BuildMachineOSBuild' "$app_info")"
    check_values "$archive" "$xcode_build" "$sdk_name" "$sdk_build" "$host_build"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
