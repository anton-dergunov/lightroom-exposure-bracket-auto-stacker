#!/bin/sh
# Build a fixture skeleton from photos, keeping only the tags in the plugin's tags.args.
#
# Usage:
#   make-fixture.sh ID PHOTO...        read the photos with exiftool
#   make-fixture.sh -d DUMP.json ID    trim an existing `exiftool -j -G1:4 -a -n` dump
#
# Writes the fixture JSON to stdout. Fill in "kind", "source" and "groups" by hand.
# Requires exiftool (override with EXIFTOOL=/path/to/exiftool) and jq.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tags="$here/../../auto-stacker.lrdevplugin/tags.args"
dump=""
if [ "${1:-}" = "-d" ]; then dump="$2"; shift 2; fi
id="$1"; shift

if [ -n "$dump" ]; then
    frames=$(cat "$dump")
else
    frames=$("${EXIFTOOL:-exiftool}" -j -n -G1:4 -a -@ "$tags" -ExifToolVersion "$@")
fi

printf '%s' "$frames" | jq --arg id "$id" --rawfile args "$tags" '
    ($args | split("\n") | map(select(startswith("-")) | ltrimstr("-"))) as $keep
    | {
        id: $id,
        kind: "TODO: exposure | focus | none",
        complete: true,
        exiftool: ((.[0]["ExifTool:ExifToolVersion"] // "unknown") | tostring),
        source: {url: "TODO", license: "TODO", author: "TODO"},
        groups: [],
        notes: "",
        frames: map(with_entries(select(
                    (.key | split(":")) as $k
                    | ($k | length) >= 2 and ($k[-1] | IN($keep[]))))
                | select(length > 0))
                | sort_by(.["System:FileName"])
      }'
