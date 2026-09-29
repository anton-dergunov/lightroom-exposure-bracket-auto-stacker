#!/bin/sh
# Print the CHANGELOG.md section for VERSION, after checking that Info.lua has that version and that the section is
# not marked unreleased. Used by the release workflow; also handy to preview the notes before tagging.
# Usage: release-notes.sh 1.0.0
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
version="$1"

plugin=$(sed -n 's/.*VERSION *= *{ *major *= *\([0-9]*\), *minor *= *\([0-9]*\), *revision *= *\([0-9]*\).*/\1.\2.\3/p' \
    "$root/bracket-stacker.lrdevplugin/Info.lua")
if [ "$plugin" != "$version" ]; then
    echo "Info.lua has version $plugin, not $version" >&2
    exit 1
fi

heading=$(grep -E "^## $version( |$)" "$root/CHANGELOG.md" || true)
if [ -z "$heading" ]; then
    echo "CHANGELOG.md has no section for $version" >&2
    exit 1
fi
case "$heading" in
    *unreleased*) echo "CHANGELOG.md still marks $version as unreleased: add the release date" >&2; exit 1 ;;
esac

awk -v heading="$heading" '$0 == heading { found = 1; next } found && /^## / { exit } found { print }' "$root/CHANGELOG.md"
