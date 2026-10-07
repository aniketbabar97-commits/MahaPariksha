# Web verification of previous-year GK / current-affairs questions

Each item is a real previous-year railway exam question (many are 2025-2026 current affairs) with the OFFICIAL answer key. An earlier
solver could not confirm the fact from memory. Your job: check the fact on the web, and if it is confirmed, write a short explanation.

Read `<DIR>/<batch>.json` (replace <DIR> with the folder you were given and <batch> with your batch name, e.g. wv-003) (list of `{"k","subject","q","o":[options],"key":<0-based index of the official answer>}`) and write
`<DIR>/<batch>.out.json` (same batch name, never a generic name): a JSON list, one object per input, same `k`:

```
{"k":"...", "verdict":"confirmed"|"contradicted"|"unconfirmed", "source":"<site or article you relied on, e.g. pib.gov.in / thehindu.com>",
 "found":"<one line: what the source says>", "e_en":"...", "e_hi":"..."}
```

## Method
1. Use WebSearch (and WebFetch when needed) for EVERY item. Prefer official or major sources (PIB, government sites, ISRO/DRDO/RBI/UN sites, The Hindu, Indian Express, Hindustan Times, Wikipedia for settled facts). A search snippet that states the fact is enough; do not open pages you do not need.
2. `confirmed` only if a source states that the keyed option (`o[key]`) is correct. Say which source. Do not "confirm" from memory, from an inference, or because the key says so.
3. `contradicted` if a reliable source clearly supports a different option (name it in `found`). `unconfirmed` if you cannot find a reliable statement either way. When not `confirmed`, e_en and e_hi are empty strings.
4. If several options could be right, or the question as printed is flawed, use `unconfirmed` and say why in `found`.
5. Searching is cheap, guessing is expensive: a wrong "confirmed" puts a false explanation in front of students.

## Explanation (only when confirmed)
- 1 to 3 short sentences, at most 600 characters English and 700 Hindi: state the fact and give the context a student can remember (who, where, when, why it matters). Use only what the source supports; do not add figures or dates you did not see.
- e_en: English, no Devanagari. e_hi: natural Devanagari Hindi (English proper nouns may stay in Latin script), same content.
- Never write "official answer key" or only "Correct answer: X". No markdown or bullets.

## Housekeeping
Helper scripts only in `<DIR>/scratch_<your first batch>/`. No git. Do every item in your batches. Finish with one line per batch: confirmed / contradicted / unconfirmed counts and an estimate of the web searches you used.
