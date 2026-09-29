#!/bin/sh
# Download the exiftool version the plugin is tested with into auto-stacker.lrdevplugin/exiftool/:
#   mac/  the Perl distribution (macOS runs it with its own /usr/bin/perl)
#   win/  the standalone Windows build, which includes Perl
# Run it once after cloning, and again when the pinned version changes. Requires curl, tar and unzip.
set -eu
VERSION=13.59
MAC_SHA256=668ea3acececb7235fbd0f4900e72d5f12c9b07e5c778fd36cb1e9b5828fd65a
WIN_SHA256=44b512b25af500724ba579d0a53c8fc5851628b692dd5e5d94ae4a15c2cba9ec

root=$(cd "$(dirname "$0")/.." && pwd)
dest="$root/auto-stacker.lrdevplugin/exiftool"
work=$(mktemp -d)
# The Windows zip unpacks read-only files, so make everything writable before deleting it.
trap 'chmod -R u+w "$work"; rm -rf "$work"' EXIT

# exiftool.org keeps only the newest release; SourceForge keeps every version.
fetch() {
    curl -fsSL -o "$work/$1" "https://sourceforge.net/projects/exiftool/files/$1/download"
    actual=$( (sha256sum "$work/$1" 2>/dev/null || shasum -a 256 "$work/$1") | cut -d' ' -f1)
    if [ "$actual" != "$2" ]; then
        echo "Checksum mismatch for $1: expected $2, got $actual" >&2
        exit 1
    fi
}

fetch "Image-ExifTool-$VERSION.tar.gz" "$MAC_SHA256"
fetch "exiftool-${VERSION}_64.zip" "$WIN_SHA256"

tar -xzf "$work/Image-ExifTool-$VERSION.tar.gz" -C "$work"
unzip -q "$work/exiftool-${VERSION}_64.zip" -d "$work"

[ -d "$dest" ] && chmod -R u+w "$dest"
rm -rf "$dest"
mkdir -p "$dest/mac" "$dest/win"
cp "$work/Image-ExifTool-$VERSION/exiftool" "$dest/mac/"
cp -R "$work/Image-ExifTool-$VERSION/lib" "$dest/mac/"
cp "$work/exiftool-${VERSION}_64/exiftool(-k).exe" "$dest/win/exiftool.exe"
cp -R "$work/exiftool-${VERSION}_64/exiftool_files" "$dest/win/"
cp "$work/Image-ExifTool-$VERSION/README" "$dest/README"
chmod -R u+w "$dest"
echo "$VERSION" > "$dest/VERSION"
cat > "$dest/LICENSE.txt" <<EOF
ExifTool $VERSION by Phil Harvey, https://exiftool.org/
Copyright 2003-2026, Phil Harvey

This is free software; you can redistribute it and/or modify it under the same terms as Perl itself
(either the Perl Artistic License or GPL). The Windows build also includes Strawberry Perl; its licenses
are in win/exiftool_files/.
EOF

echo "exiftool $VERSION installed in $dest"
