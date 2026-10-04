"""Subject/topic classifier for imported PYQs, trained on the app's own labelled bank.

Multinomial Naive Bayes over word unigrams + bigrams (English and Hindi text both),
pure Python. Used only where a response sheet's section header doesn't already
name the subject, and always for the topic within a subject.
"""
import json
import math
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TOKEN = re.compile(r"[a-z]+|[ऀ-ॿ]+|\d+")


def tokens(text):
    w = TOKEN.findall(text.lower())
    w = [t if not t.isdigit() else "<num>" for t in w]
    return w + [a + "_" + b for a, b in zip(w, w[1:])]


def text_of(q):
    parts = [q.get("q_en") or "", q.get("q_hi") or ""]
    parts += q.get("o_en") or []
    parts += q.get("o_hi") or []
    return " ".join(parts)


class NB:
    def __init__(self, alpha=0.5):
        self.alpha = alpha
        self.counts = defaultdict(Counter)
        self.totals = Counter()
        self.docs = Counter()
        self.vocab = set()

    def add(self, label, toks):
        self.counts[label].update(toks)
        self.totals[label] += len(toks)
        self.docs[label] += 1
        self.vocab.update(toks)

    def scores(self, toks, labels=None):
        labels = [l for l in (labels or self.docs) if l in self.docs]
        n = sum(self.docs[l] for l in labels)
        v = len(self.vocab)
        out = {}
        for l in labels:
            c, tot = self.counts[l], self.totals[l] + self.alpha * v
            s = math.log(self.docs[l] / n)
            for t in toks:
                if t in self.vocab:
                    s += math.log((c[t] + self.alpha) / tot)
            out[l] = s
        return out

    def predict(self, toks, labels=None):
        sc = self.scores(toks, labels)
        return max(sc, key=sc.get) if sc else None


class Classifier:
    def __init__(self, items):
        self.subject = NB()
        self.topic = defaultdict(NB)
        for q in items:
            t = tokens(text_of(q))
            self.subject.add(q["s"], t)
            self.topic[q["s"]].add(q["t"], t)

    @classmethod
    def from_bank(cls, exclude_prefix="pyq"):  # never learn from imported PYQs (pyq-/pyqb-)
        items = []
        for p in sorted((ROOT / "content/bank").glob("*.json")):
            items += [q for q in json.loads(p.read_text(encoding="utf-8")) if not q["id"].startswith(exclude_prefix)]
        return cls(items)

    def classify(self, q, subjects=None, subject=None, with_margin=False):
        t = tokens(text_of(q))
        s = subject or self.subject.predict(t, subjects)
        sc = self.topic[s].scores(t)
        top = sorted(sc.values(), reverse=True)
        best = max(sc, key=sc.get)
        if not with_margin:
            return s, best
        # Log-likelihood gap between the best and second-best topic (per token):
        # a small gap means the topic guess is a coin-flip.
        margin = (top[0] - top[1]) / max(1, len(t)) if len(top) > 1 else 99.0
        return s, best, margin


if __name__ == "__main__":
    # Hold-out check: train on 90% of the bank, report accuracy on the rest.
    import random
    items = []
    for p in sorted((ROOT / "content/bank").glob("*.json")):
        items += json.loads(p.read_text(encoding="utf-8"))
    random.Random(1).shuffle(items)
    cut = len(items) // 10
    test, train = items[:cut], items[cut:]
    clf = Classifier(train)
    s_ok = t_ok = t_given_s = 0
    for q in test:
        s, t = clf.classify(q)
        s_ok += s == q["s"]
        t_ok += (s, t) == (q["s"], q["t"])
        t_given_s += clf.classify(q, subject=q["s"])[1] == q["t"]
    n = len(test)
    print(f"held-out {n}: subject {s_ok / n:.1%}, subject+topic {t_ok / n:.1%}, topic given subject {t_given_s / n:.1%}")
