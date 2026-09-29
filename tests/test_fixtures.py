import json
from pathlib import Path

import pytest

FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE_FILES = sorted(FIXTURES.glob("*/*.json"))
ALLOWED_TAGS = {
    line.strip()[1:]
    for line in (FIXTURES / "tags.args").read_text(encoding="utf-8").splitlines()
    if line.strip().startswith("-")
}


def test_fixtures_exist():
    assert FIXTURE_FILES


@pytest.mark.parametrize("path", FIXTURE_FILES, ids=lambda p: p.stem)
def test_fixture_is_well_formed(path):
    fixture = json.loads(path.read_text(encoding="utf-8"))

    assert fixture["id"] == path.stem
    assert fixture["kind"] in {"exposure", "focus", "none"}
    assert isinstance(fixture["complete"], bool)
    assert isinstance(fixture.get("derived", ""), str)
    assert all(fixture["source"].get(k) for k in ("url", "license", "author"))

    names = [frame["System:FileName"] for frame in fixture["frames"]]
    assert len(names) == len(set(names)), "duplicate file names"

    grouped = [name for group in fixture["groups"] for name in group]
    assert all(len(group) >= 2 for group in fixture["groups"])
    assert len(grouped) == len(set(grouped)), "a frame is in two groups"
    assert set(grouped) <= set(names), "group lists a frame that is not in frames"
    assert set(fixture["source"].get("files", {})) <= set(names)
    if fixture["kind"] == "none":
        assert not fixture["groups"]
    for group in fixture.get("expected", []):
        assert len(group) >= 2 and set(group) <= set(names), "expected lists a frame that is not in frames"


@pytest.mark.parametrize("path", FIXTURE_FILES, ids=lambda p: p.stem)
def test_fixture_keeps_only_listed_tags(path):
    # The tag list is what keeps serial numbers, names, GPS and paths out of the repo.
    fixture = json.loads(path.read_text(encoding="utf-8"))
    for frame in fixture["frames"]:
        for key in frame:
            group, _, tag = key.partition(":")
            assert group and tag in ALLOWED_TAGS, f"{frame['System:FileName']}: {key} is not in tags.args"
