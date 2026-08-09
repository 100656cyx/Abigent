#!/bin/bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/.." && pwd)
version=${ABIGENT_VERSION:-1.0.0-beta.3}
build=${ABIGENT_BUILD:-1}
artifact_name="Abigent-${version}-macOS-arm64.dmg"
artifact_path="$project_root/dist/$artifact_name"
checksum_path="$artifact_path.sha256"

case "$version" in
  *[!0-9A-Za-z.-]*) echo "Invalid ABIGENT_VERSION" >&2; exit 2 ;;
esac
case "$build" in
  ''|*[!0-9]*) echo "Invalid ABIGENT_BUILD" >&2; exit 2 ;;
esac

ABIGENT_VERSION="$version" ABIGENT_BUILD="$build" "$project_root/Scripts/build-app.sh"
"$project_root/Scripts/create-dmg.sh" "$project_root/dist/Abigent.app" "$artifact_path"

cd "$project_root/dist"
shasum -a 256 "$artifact_name" > "$(basename "$checksum_path")"
shasum -a 256 -c "$(basename "$checksum_path")"
codesign --verify --deep --strict "$project_root/dist/Abigent.app"
test "$(lipo -archs "$project_root/dist/Abigent.app/Contents/MacOS/Abigent")" = "arm64"

printf '%s\n%s\n' "$artifact_path" "$checksum_path"
