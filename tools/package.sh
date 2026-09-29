#!/bin/sh
# Build the plugin zip for a release: dist/bracket-stacker.zip, holding bracket-stacker.lrplugin/ with exiftool.
# The name has no version, so .../releases/latest/download/bracket-stacker.zip always gets the newest release.
# Downloads exiftool first if the plugin folder does not have it yet.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
plugin="$root/bracket-stacker.lrdevplugin"

[ -f "$plugin/exiftool/VERSION" ] || sh "$root/tools/fetch-exiftool.sh"

version=$(sed -n 's/.*VERSION *= *{ *major *= *\([0-9]*\), *minor *= *\([0-9]*\), *revision *= *\([0-9]*\).*/\1.\2.\3/p' "$plugin/Info.lua")
work=$(mktemp -d)
trap 'chmod -R u+w "$work"; rm -rf "$work"' EXIT

mkdir "$work/bracket-stacker.lrplugin"
cp "$plugin"/*.lua "$plugin/tags.args" "$work/bracket-stacker.lrplugin/"
cp -R "$plugin/exiftool" "$work/bracket-stacker.lrplugin/"
cp "$root/LICENSE" "$work/bracket-stacker.lrplugin/LICENSE.txt"

mkdir -p "$root/dist"
zip="$root/dist/bracket-stacker.zip"
rm -f "$zip"
(cd "$work" && zip -qr "$zip" bracket-stacker.lrplugin -x '*.DS_Store')
echo "Built $zip (version $version)"
