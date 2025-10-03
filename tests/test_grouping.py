import os
import sys
import io
import importlib
import tempfile
import stat
import builtins
import pytest

import group_sony_bracketed_photos as grouping

# Fake ExifToolHelper similar to cleanup tests
class FakeExifToolHelper:
    def __init__(self, mapping):
        self._mapping = mapping

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def get_metadata(self, files):
        out = []
        for f in files:
            md = dict(self._mapping.get(f, {}))
            if "SourceFile" not in md:
                md["SourceFile"] = f
            out.append(md)
        return out


def create_files(tmp_path, filenames):
    paths = []
    for name in filenames:
        p = tmp_path / name
        p.write_bytes(b"")
        p.chmod(p.stat().st_mode | stat.S_IWUSR | stat.S_IRUSR)
        paths.append(str(p))
    return paths


def test_grouping_main_creates_groups_file(tmp_path, monkeypatch, capsys):
    # Prepare files: make a bracket sequence of 3 which will be detected
    files = create_files(tmp_path, ["DSC1001.ARW", "DSC1002.ARW", "DSC1003.ARW"])
    # Build metadata mapping expected by grouping script
    mapping = {}
    # All files must include required attributes (EXIF:Make etc.)
    for i, f in enumerate(files, start=1):
        mapping[f] = {
            "SourceFile": f,
            "EXIF:Make": "SONY",
            "EXIF:DateTimeOriginal": "2025:10:02 12:00:0{}".format(i),
            "EXIF:ExposureMode": 2,
            "EXIF:ExposureCompensation": (i - 2),  # -1, 0, 1
            "MakerNotes:ReleaseMode": 5,
            "MakerNotes:SequenceImageNumber": i,
            "MakerNotes:SequenceLength": 3,
        }

    # Monkeypatch ExifToolHelper used in grouping module
    monkeypatch.setattr(grouping, "ExifToolHelper", lambda: FakeExifToolHelper(mapping))

    out_file = tmp_path / "groups.txt"
    # Call main with args (simulate CLI)
    argv = ["prog", "--input", str(tmp_path), "--output", str(out_file)]
    monkeypatch.setattr("sys.argv", argv)
    # Just call grouping.main to emulate command line run
    grouping.main()

    # Validate the groups file exists and contains the expected lines
    assert out_file.exists()
    content = out_file.read_text(encoding="utf-8").splitlines()
    # Expect first line "#group", then three source files
    assert content[0] == "#group"
    # The three files should be present (order preserved)
    assert any("DSC1001.ARW" in l for l in content)
    assert any("DSC1002.ARW" in l for l in content)
    assert any("DSC1003.ARW" in l for l in content)

def test_grouping_skips_non_sony(tmp_path, monkeypatch, capsys):
    # Create a file but mark it as non-SONY in metadata
    files = create_files(tmp_path, ["X1.ARW"])
    mapping = {
        files[0]: {
            "SourceFile": files[0],
            "EXIF:Make": "CANON",
            "EXIF:DateTimeOriginal": "2025:10:02 12:00:00",
            "EXIF:ExposureMode": 2,
            "EXIF:ExposureCompensation": 0,
            "MakerNotes:ReleaseMode": 5,
            "MakerNotes:SequenceImageNumber": 1,
            "MakerNotes:SequenceLength": 1,
        }
    }
    monkeypatch.setattr(grouping, "ExifToolHelper", lambda: FakeExifToolHelper(mapping))
    out_file = tmp_path / "outgroups.txt"
    monkeypatch.setattr("sys.argv", ["prog", "--input", str(tmp_path), "--output", str(out_file)])
    # Because the script calls exit(1) on non-SONY, capture SystemExit
    with pytest.raises(SystemExit):
        grouping.main()
