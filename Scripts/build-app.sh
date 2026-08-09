#!/bin/bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/.." && pwd)
build_root="$project_root/.build-abigent"
dist_root="$project_root/dist"
app_path="$dist_root/Abigent.app"
sdk_path=${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}
cache_root="${TMPDIR:-/tmp}/abigent-build-cache"

mkdir -p "$cache_root/clang" "$cache_root/swiftpm" "$dist_root"
SDKROOT="$sdk_path" \
CLANG_MODULE_CACHE_PATH="$cache_root/clang" \
SWIFTPM_MODULECACHE_OVERRIDE="$cache_root/swiftpm" \
swift build --disable-sandbox --scratch-path "$build_root" -c release --product Abigent
SDKROOT="$sdk_path" \
CLANG_MODULE_CACHE_PATH="$cache_root/clang" \
SWIFTPM_MODULECACHE_OVERRIDE="$cache_root/swiftpm" \
swift build --disable-sandbox --scratch-path "$build_root" -c release --product abigent-hook

binary_path=$(find "$build_root" -path '*/release/Abigent' -type f -perm -111 | head -n 1)
bundle_path=$(find "$build_root" -path '*/release/Abigent_AbigentApp.bundle' -type d | head -n 1)
hook_path=$(find "$build_root" -path '*/release/abigent-hook' -type f -perm -111 | head -n 1)
test -n "$binary_path"
test -n "$bundle_path"
test -n "$hook_path"

if [[ "$app_path" != "$project_root/dist/Abigent.app" ]]; then
  echo "Refusing unexpected app path" >&2
  exit 2
fi
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$app_path/Contents/Helpers"
cp "$binary_path" "$app_path/Contents/MacOS/Abigent"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
if [[ -n "${ABIGENT_VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $ABIGENT_VERSION" "$app_path/Contents/Info.plist"
fi
if [[ -n "${ABIGENT_BUILD:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $ABIGENT_BUILD" "$app_path/Contents/Info.plist"
fi
cp -R "$bundle_path" "$app_path/Contents/Resources/Abigent_AbigentApp.bundle"
cp "$hook_path" "$app_path/Contents/Helpers/abigent-hook"
chmod 755 "$app_path/Contents/Helpers/abigent-hook"

iconset="$cache_root/Abigent.iconset"
rm -rf "$iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Resources/Pet/abigent-base.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" Resources/Pet/abigent-base.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
if ! iconutil -c icns "$iconset" -o "$app_path/Contents/Resources/Abigent.icns"; then
  cp Resources/Pet/abigent-base.png "$app_path/Contents/Resources/Abigent.png"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile Abigent.png" "$app_path/Contents/Info.plist"
fi

identity=${ABIGENT_SIGNING_IDENTITY:--}
codesign --force --options runtime --sign "$identity" "$app_path/Contents/Helpers/abigent-hook"
codesign --force --options runtime --entitlements Resources/Abigent.entitlements --sign "$identity" "$app_path"
codesign --verify --deep --strict "$app_path"
echo "$app_path"
