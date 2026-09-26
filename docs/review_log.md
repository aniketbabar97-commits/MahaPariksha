
## Marathi & English review
- marathi-048: option 'सख्खा' had disputed spelling (distractor); replaced with 'स्वतःचा' in o_mr/o_en.
- fc-marathi-015: awkward phrasing 'कोणाप्रमाणेच बदलत नाही' (meaning inverted-sounding); rewritten to 'कर्ता किंवा कर्म यांपैकी कोणाप्रमाणेही बदलत नाही'.
All other items (66 Marathi MCQs, 30 English MCQs, 48 flashcards) verified: keys, classifications, idioms, literature facts correct.

## Geography, Economy, Science, Computer, Traffic & Pedagogy review

Reviewed 171 MCQs + 69 flashcards (240 items). All answer keys verified correct; no key changes needed.

- fc-geography-005: deleted (district count "36" is time-sensitive; new districts under discussion).
- economy-027: explanation removed disputed colour-revolution pairings (Silver=eggs, Sweet=honey, Golden=fruits); kept undisputed facts.
- science-021: q_mr said "कोणत्या पेशी" though platelets/plasma are not cells; now "कोणते घटक" (matches "components").
- science-031: o_mr[1] "रक्तदाब" did not match "Hypertension"; now "उच्च रक्तदाब".
- traffic-020: removed "transport vehicles need 20 years" claim (affected by 2019 MV amendment, uncertain).
- pedagogy-022: o_mr[3] "लेखन हस्ताक्षर" made natural: "लेखन (हस्ताक्षर)".

## Maths & Reasoning review

Scope: bank/maths.json (66), bank/reasoning.json (54), flashcards/maths.json (33), flashcards/reasoning.json (27). All items solved independently; numeric answers, calendar/clock items and hooks re-checked. No deletions.

- maths-001: all four options (en & mr) had hook text fused into them ("6Remember 1001 = …"). Options restored to 6 / 1 / 2 / 3.
- reasoning-053: answer key wrong (keyed "Both I and II follow"); set to "Either I or II follows", matching the explanation.
- reasoning-031: 11 was also odd one out (only two-digit number). Replaced with 7 (3, 5, 7, 9).
- reasoning-032: 25 was also odd one out (only odd number). Replaced with 64 (16, 64, 48, 36).
- reasoning-036: 64 was arguably odd (square as well as cube; even). Replaced with 343 (27, 343, 150, 125).
- reasoning-034: Pune was a defensible second answer (only non-capital among Mumbai, Nagpur, Bhopal). Options now Pune, Nashik, Kolhapur, Indore.
- reasoning-050/051/052: Marathi "Neither" option was ungrammatical ("I किंवा II दोन्हीपैकी एकही…"); now "I व II पैकी एकही अनुसरत नाही".
- reasoning-014: Marathi grammar "D हा C चा वडील" → honorific "D हे C चे वडील".
- fc-maths-004: BODMAS card implied addition before subtraction; now ÷/× and +/− each left to right.
- fc-reasoning-026: said Some + No gives no conclusion; corrected to "Some A are not C".

## History, Polity, GK & Motivation review

Reviewed 140 MCQs (history 42, polity 49, gk 49), 60 flashcards, 120 motivation items. All answer keys verified correct; no deletions.

- polity-039: explanation listed only three Bombay HC benches; added the Kolhapur circuit bench (from 18 Aug 2025). Answer (Pune) unchanged.
- fc-polity-018: same bench list updated with the Kolhapur circuit bench.
- fc-history-018: "Vidarbha joins Maharashtra" in 1953 was inaccurate (the pact was an agreement; the merger came in 1956/1960); reworded.
- gk-045: Ahmednagar district renamed Ahilyanagar (2024); explanation updated.
- mot-008: English order "Educate, agitate, organise" did not match the Marathi; aligned to "Educate, organise, agitate".
- mot-011: Tukaram abhang misquoted ("तुकाराम म्हणे"); restored the original "तुका म्हणे".
- mot-056: "lost his family in Partition" overstated; changed to "lost several family members".

## Second-wave review

Independent review of bank/{gs_adv,reasoning_adv,maths_adv,english_rc,marathi_utara}.json and flashcards/{gs_adv,maths_adv}.json (148 bank items + 39 flashcards). All numeric items re-solved; puzzles re-derived; option order EN/MR checked.
- gs2-024: Tadoba-Andhari tiger reserve year corrected 1995 -> 1993 (e_en, e_mr).
- english2-010: DELETED — blank (1) ambiguous ("valuable/famous for far more than honey" also correct).
- No other errors found. validate.py: 0 errors.

## Motivation quote attribution audit

Audited all attributed ("by" is a real named person) items in `content/motivation/motivation.json` (30 items) and `content/motivation/motivation_batch2.json` (40 items). `motivation_batch1.json` and `motivation_batch3.json` do not exist in the directory and were skipped.

### motivation.json (120 items) — no changes
All 15 quote items (mot-001..mot-015: Vivekananda, Kalam, Ambedkar, Gandhi, Tukaram, Samarth Ramdas, Tilak, Bhagavad Gita 2.47) and the 10 spot-checked story items about real people (mot-051..mot-065: Savitribai Phule, Ambedkar, Shivaji Maharaj, Kalam, Mary Kom, Milkha Singh, Kalpana Chawla, Arunima Sinha, Dhyan Chand, Anandibai Joshi, Sachin Tendulkar, Jotirao Phule, Visvesvaraya, Lal Bahadur Shastri, Karnam Malleswari) were verified via WebSearch/knowledge as genuine, well-documented quotes/facts (e.g., Tukaram's "असाध्य ते साध्य करिता सायास" and "रात्रंदिन आम्हा युद्धाचा प्रसंग" are authentic abhangs; Samarth Ramdas's "सामर्थ्य आहे चळवळीचे" is from the Dasbodh; Tendulkar's 1989 Sialkot Test debut / Waqar Younis nose injury and Arunima Sinha's 2011 train incident are well-documented facts). No downgrades needed here.

### motivation_batch2.json (300 items) — 36 items downgraded to "by":"Bharari"
Checked all 40 attributed quote items. WebSearch (BrainyQuote, AZQuotes, Wikiquote, Goodreads, news archives) found **no verifiable source** for 36 of them — they read as plausible-sounding paraphrases invented for the app rather than real documented quotes. Per rule 2/3, changed `"by"` from the named person to `"Bharari"` for these ids (text left as-is since none of it explicitly claims to be a direct quotation by name):

mot3-001 (Milkha Singh), mot3-002, mot3-003, mot3-036 (Mary Kom), mot3-004, mot3-005, mot3-033 (Sachin Tendulkar), mot3-006, mot3-035 (Kapil Dev), mot3-007, mot3-008 (P. V. Sindhu), mot3-009, mot3-010 (Vishwanathan Anand), mot3-011, mot3-012 (Abhinav Bindra), mot3-013, mot3-014, mot3-038 (Field Marshal Sam Manekshaw), mot3-015, mot3-016, mot3-041 (Dr. Vikram Sarabhai), mot3-017 (Dr. Homi Bhabha), mot3-018, mot3-019 (Sir C. V. Raman), mot3-020, mot3-021 (Indira Gandhi), mot3-022, mot3-023 (Atal Bihari Vajpayee), mot3-024, mot3-025, mot3-039 (Chanakya/Arthashastra), mot3-027 (Bruce Lee's "Fear is natural..." — not the genuine kicks quote), mot3-029 (Steve Jobs), mot3-030 (Marie Curie's "opportunity" line — not the genuine "nothing is to be feared" quote), mot3-034, mot3-037 (Milkha Singh), mot3-040 (Sir M. Visvesvaraya).

Examples of specific checks: Kapil Dev's "Playing under pressure is an art" — not found in any quote database or interview archive. Manekshaw's "If an officer says the situation is impossible..." — absent from Wikiquote's sourced Manekshaw page despite it being thorough. Vajpayee's "Nation first, party after, and I come last" — only a paraphrase found ("Nation First, Party Next, Self Last"), not a direct sourced quote. Sachin Tendulkar's "cricket is my religion" — confirmed to be a fan/popular saying about him, not something he himself said.

Left unchanged (verified genuine, well-documented quotes): mot3-026 (Nelson Mandela, "Education is the most powerful weapon which you can use to change the world" — from his verified 2003 Mindset Network speech), mot3-028 (Bruce Lee, "I fear not the man who has practiced ten thousand kicks once..." — genuine, widely sourced), mot3-031 (Marie Curie, "Nothing in life is to be feared, it is only to be understood" — genuine, from her writings).

No changes were needed to any Marathi/English text bodies — none of the audited items phrase the text itself as an explicit first-person claim tied to the name beyond the "by" field, so changing "by" to "Bharari" alone is sufficient to stop the false attribution.
