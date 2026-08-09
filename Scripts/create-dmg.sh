#!/bin/bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/.." && pwd)
app_path=${1:-"$project_root/dist/Abigent.app"}
dmg_path=${2:-"$project_root/dist/Abigent.dmg"}

if [[ ! -d "$app_path" || "$(basename "$app_path")" != "Abigent.app" || "$(dirname "$dmg_path")" != "$project_root/dist" ]]; then
  echo "Expected an existing Abigent.app" >&2
  exit 2
fi

stage=$(mktemp -d "${TMPDIR:-/tmp}/abigent-dmg.XXXXXX")
cleanup() { rm -rf "$stage"; }
trap cleanup EXIT
guide_path="$project_root/Resources/Distribution/首次打开说明.txt"
test -f "$guide_path"
cp -R "$app_path" "$stage/Abigent.app"
ln -s /Applications "$stage/Applications"
cp "$guide_path" "$stage/首次打开说明.txt"
rm -f "$dmg_path"
hdiutil create -volname "Abigent" -srcfolder "$stage" -ov -format UDZO "$dmg_path" >/dev/null
hdiutil verify "$dmg_path" >/dev/null
echo "$dmg_path"
