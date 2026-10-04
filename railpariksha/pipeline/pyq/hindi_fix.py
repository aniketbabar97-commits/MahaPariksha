"""Repair Hindi text damaged by the response sheets' Type3 fonts.

(1) Words that lost their reph, (2) words split by a stray space.

Original note on (1): repair Hindi words whose reph (र्) was lost in the response sheets' Type3 fonts
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


# ---- (2) words split by a stray space: "क् या" -> "क्या", "प्राप् त" -> "प्राप्त", "प्रक्रि या" -> "प्रक्रिया"
DEV_TOKEN = re.compile(r"([\u0900-\u097F]+)")
MATRAS = "\u093e-\u094c"
REPEATED_MATRA = re.compile(f"([{MATRAS}][\u0901-\u0903]?)\\1+")  # "क्षेत्रोंों" -> "क्षेत्रों"


def build_joins(native_texts, clean_texts=()):
    """Adjacent token pairs (a, b) that are one word cut by a stray space.

    A pair joins when the merged word is established (seen >= 3 times) and the first half is
    rare next to it (<= 1/4 as common). That keeps real two-word sequences apart ("का रण" is not
    "कारण": का is far commoner than कारण) and real words that end in a halant ("विद्युत् अपघटनी":
    विद्युत् is common on its own, "विद्युत्अपघटनी" does not exist). [clean_texts] (text we wrote,
    not extracted) add trusted vocabulary."""
    vocab = Counter()
    for t in [*native_texts, *clean_texts]:
        vocab.update(WORD.findall(t))
    pairs = set()
    for t in native_texts:
        parts = DEV_TOKEN.split(t)
        for i in range(1, len(parts) - 2, 2):
            if parts[i + 1] == " ":
                pairs.add((parts[i], parts[i + 2]))
    return {(a, b) for a, b in pairs if vocab[a + b] >= 3 and vocab[a] * 4 <= vocab[a + b]}


def fix_spaces(text, joins):
    parts = DEV_TOKEN.split(text)  # [non-dev, dev, non-dev, dev, ...]
    if len(parts) < 4:
        return text
    out = [parts[0], parts[1]]
    for i in range(2, len(parts), 2):
        sep, tok = parts[i], parts[i + 1] if i + 1 < len(parts) else None
        if tok is not None and sep == " " and (out[-1], tok) in joins:
            out[-1] += tok
        else:
            out.append(sep)
            if tok is not None:
                out.append(tok)
    return "".join(out)


def fix_matras(text):
    return REPEATED_MATRA.sub(r"\1", text)
