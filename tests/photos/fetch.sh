#!/bin/sh
# Download the test photos (the test-photos-v1 release) into this folder, for testing the plugin in Lightroom.
# Each subfolder matches the fixture of the same name in tests/fixtures/sony/.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
url=https://github.com/anton-dergunov/lightroom-exposure-bracket-auto-stacker/releases/download/test-photos-v1/test-photos-v1.zip

curl -fL --progress-bar -o "$here/test-photos-v1.zip" "$url"
unzip -oq "$here/test-photos-v1.zip" -d "$here"
rm "$here/test-photos-v1.zip"
echo "Photos are in $here/test-photos-v1"
