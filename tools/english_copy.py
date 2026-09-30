"""Apply reviewed English copy without changing any puzzle or save identifiers."""
import hashlib
import json
from pathlib import Path

COPY = json.loads((Path(__file__).parent / "english-level-copy.json").read_text())

def structure_signature(level):
    value = {key: level[key] for key in (
        "id", "chapterID", "number", "schemaVersion", "contentRevision", "rules", "cards", "falseTestimonyCount"
    )}
    for key in ("facts", "testimonies"):
        value[key] = [{field: evidence[field] for field in ("id", "constraint")} for evidence in level[key]]
    value["hints"] = [{key: hint[key] for key in ("evidenceIDs", "conclusion")} for hint in level["hints"]]
    value["solution"] = {key: level["authorSolution"][key] for key in ("plays", "falseTestimonyIDs")}
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()

def apply_english_copy(level):
    copy = COPY[level["id"]]
    if structure_signature(level) != copy["structureSHA256"]:
        raise ValueError(f"Review English copy after changing puzzle structure: {level['id']}")
    for key in ("title", "subtitle", "story"):
        level[key] = copy[key]
    for key in ("facts", "testimonies"):
        for item, text in zip(level[key], copy[key]):
            item["text"] = text
    for hint, text in zip(level["hints"], copy["hints"]):
        hint.update(text)
    level["authorSolution"]["explanation"] = copy["explanation"]
    return level
