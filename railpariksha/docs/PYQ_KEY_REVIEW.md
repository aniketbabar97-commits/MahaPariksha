# PYQ answer-key review

Every PYQ that the explanation solver disagreed with the published key on (402 questions) was
re-solved blind (the verifier was not shown the key) by a fresh verifier, and the likely errors were
re-checked by two more.

| Outcome | Questions |
|---|---|
| Key corrected (solver, first verifier and two more all agree; arithmetic, counting, logic, physics) | 58 listed, 29 still present in the current packs and applied |
| Key kept, a verifier agreed with the published key | 16 |
| Key kept, open facts the verifiers could only partly confirm | about 250 |
| Key kept, seating, direction and blood-relation puzzles (left/right conventions) | 23 |
| Key kept, question ambiguous or printed incorrectly (no option is right as printed) | 17 |

Rules: a key changes only for objectively derivable items with unanimous, high-confidence
agreement. Open facts, convention-dependent puzzles and ambiguous items keep the official key, as
before. A corrected question shows the working and a note that the published key lists a different
option, so a student who solved it correctly is not told they were wrong.

- Corrections: `pipeline/pyq/explanations/key_fixes.jsonl`, applied by `python3 pipeline/pyq/key_fixes.py`
  (idempotent; run it again after any pack rebuild from the PDFs).
- Everything the solver flagged: `pipeline/pyq/explanations/*.flags.jsonl`.
- Students can also tell us: "Report an error" on any question writes a small record to the Firestore
  `reports` collection (Firebase Console, Firestore Database, `reports`). Fix real ones by adding a
  line to `key_fixes.jsonl`.
