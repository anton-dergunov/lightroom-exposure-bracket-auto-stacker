#!/bin/sh
# Build the plugin zip for a release: dist/auto-stacker-<version>.zip, holding auto-stacker.lrplugin/ with exiftool.
# Downloads exiftool first if the plugin folder does not have it yet.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
plugin="$root/auto-stacker.lrdevplugin"

[ -f "$plugin/exiftool/VERSION" ] || sh "$root/tools/fetch-exiftool.sh"

version=$(sed -n 's/.*VERSION *= *{ *major *= *\([0-9]*\), *minor *= *\([0-9]*\), *revision *= *\([0-9]*\).*/\1.\2.\3/p' "$plugin/Info.lua")
work=$(mktemp -d)
trap 'chmod -R u+w "$work"; rm -rf "$work"' EXIT

mkdir "$work/auto-stacker.lrplugin"
cp "$plugin"/*.lua "$plugin/tags.args" "$work/auto-stacker.lrplugin/"
cp -R "$plugin/exiftool" "$work/auto-stacker.lrplugin/"
cp "$root/LICENSE" "$work/auto-stacker.lrplugin/LICENSE.txt"

mkdir -p "$root/dist"
zip="$root/dist/auto-stacker-$version.zip"
rm -f "$zip"
(cd "$work" && zip -qr "$zip" auto-stacker.lrplugin -x '*.DS_Store')
echo "Built $zip"
