"""Validate an authorized local course without third-party dependencies."""
import json
import re
import sys
from pathlib import Path


def validate(path):
    course = json.loads(path.read_text(encoding="utf-8"))
    assert course["title"] and course["source"], "Missing title or source"
    lessons = course["lessons"]
    assert lessons, "Course must have lessons"
    assert [lesson["id"] for lesson in lessons] == list(range(1, len(lessons) + 1)), "Lesson IDs must be consecutive"
    word_ids = set()
    for lesson in lessons:
        for field in ["title", "subtitle", "sentence", "translation", "grammar", "exerciseAnswer"]:
            assert isinstance(lesson[field], str) and lesson[field].strip(), (lesson["id"], field)
        assert lesson["exerciseAnswer"] in lesson["sentence"], "Answer must occur in sentence"
        assert 0 <= lesson["startPage"] <= lesson["endPage"], "Invalid source pages"
        tokens = set(re.findall(r"[a-z]+(?:'[a-z]+)?", lesson["sentence"].lower()))
        assert tokens == set(lesson["glosses"]), (lesson["id"], "Glosses must cover all sentence words")
        for gloss in lesson["glosses"].values():
            assert all(isinstance(gloss[k], str) and gloss[k].strip() for k in ["lemma", "meaning", "note"]), "Empty gloss"
        assert any(word["core"] for word in lesson["words"]), "Missing core words"
        for word in lesson["words"]:
            assert word["id"] not in word_ids, "Duplicate word ID"
            word_ids.add(word["id"])
            assert word["word"].strip() and word["meaning"].strip(), "Empty word or meaning"
            assert isinstance(word["core"], bool) and isinstance(word["notes"], list)
            assert isinstance(word["ipa"], str) and word["group"] and word["page"] >= 0
    print(f"Validated {len(lessons)} lessons and {len(word_ids)} unique word IDs.")


if __name__ == "__main__":
    default = Path(__file__).resolve().parents[1] / "IELTS100/Resources/lessons.json"
    validate(Path(sys.argv[1]) if len(sys.argv) > 1 else default)
