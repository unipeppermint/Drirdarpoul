#!/usr/bin/env python3
"""Check bundled English copy and protect the puzzle data that saves depend on."""
import json
import re
from pathlib import Path
from english_copy import apply_english_copy, structure_signature, COPY

root = Path(__file__).resolve().parents[1]
levels = json.loads((root / 'Drirdarpoul/Data/levels.json').read_text())
assert len(levels) == len(COPY) == 40
for level in levels:
    assert structure_signature(level) == COPY[level['id']]['structureSHA256'], level['id']
    assert apply_english_copy(json.loads(json.dumps(level))) == level, level['id']
    assert not re.search(r'[\u3400-\u9fff]', json.dumps(level, ensure_ascii=False)), level['id']
for path in (root / 'Drirdarpoul').rglob('*'):
    if path.suffix in ('.swift', '.storyboard', '.plist'):
        assert not re.search(r'[\u3400-\u9fff]', path.read_text()), path
print('PASS: 40 English files, reviewed copy matches, gameplay/save structure unchanged, no Chinese in app-owned source text.')
