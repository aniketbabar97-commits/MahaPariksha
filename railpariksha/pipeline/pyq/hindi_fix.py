"""Repair Hindi words whose reph (र्) was lost in the response sheets' Type3 fonts
("पदाथ" for पदार्थ, "ऊजा" for ऊर्जा).

The map is learned from the corpus itself: a rare word is repaired only when inserting
"र्" somewhere gives a word that is at least 15x more frequent. A short word seen once,
or a word that is genuine Hindi in its own right (शत, गम, पाक, भजन ...), is left alone.
"""
import re
from collections import Counter

WORD = re.compile(r"[ऀ-ॿ]+")
CONS = {chr(c) for c in range(0x0915, 0x093A)}
GENUINE = {"शत", "गम", "पाक", "भजन", "अध", "वक", "हाड", "कतन", "आद्र", "वड", "दज", "सॉट"}
MIN_RATIO, MAX_BAD = 15, 15


def build_map(texts):
    cnt = Counter()
    for t in texts:
        cnt.update(WORD.findall(t))
    fixes = {}
    for w, n in cnt.items():
        if n > MAX_BAD or w in GENUINE or (len(w) < 4 and n < 2):
            continue
        best = max(((cnt[c], c) for c in
                    (w[:k] + "र्" + w[k:] for k in range(1, len(w)) if w[k] in CONS and w[k - 1] != "्")
                    if cnt[c] >= max(5, n * MIN_RATIO)), default=None)
        if best:
            fixes[w] = best[1]
    return fixes


def fix(text, fixes):
    return WORD.sub(lambda m: fixes.get(m.group(0), m.group(0)), text) if fixes else text
