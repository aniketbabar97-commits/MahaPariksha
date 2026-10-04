# UI/UX audit, ad inventory and the ₹10 lakh / 180-day model

Date: 2026-10-04. Based on the compiled app run in Chromium (English and Hindi, light and dark, 360×740
and 412×860), the widget tests, and a read of every ad call site. Not run on a physical phone.

## 1. What the target means

"10 lakh in 180 days" is read here as **₹10,00,000 of AdMob revenue in 180 days** (₹5,556/day on average).
The same model gives the install count, so if you meant 10 lakh installs, read the last column of the
table in section 4.

## 2. Where ads exist today (complete list)

| Placement | Where | How often |
|---|---|---|
| Banner | Progress tab only | Whenever Progress is open |
| Interstitial | After a mock test result | Every 2nd mock, none in the first 2 |
| Rewarded | PYQ unlock (30-minute window) | Once per window |
| Rewarded | Progress: bonus streak freeze | Opt-in |
| Native, App-open, Rewarded-interstitial | IDs exist in `ads_config.dart` | **Never shown** |

Ad-free purchasers see none of the above. The unlock window is in memory only, so it resets when the app
restarts. Two of the three placements sit on screens most students open rarely (Progress, mock results).
The PYQ unlock is the only placement tied to the thing students come for, which is why almost all current
revenue comes from it.

## 3. UI/UX findings

Fixed in this change:
- **PYQ had no front door.** Today had eight cards and none was PYQ; it was the second card on Practice.
  Added a Previous year papers card to Today.
- **PYQ list ignored the student's exam.** An NTPC student saw RPF Constable first. Their own exam now
  comes first.
- **"Est. top 99%"** appeared next to a 0% score. The rank pill now shows only for a respectable rank.
- **Counts had no separators** (6870, 48163). Now 6,870 / 48,163.
- **PYQ tile claimed 55,000+.** After de-duplication the pack holds 52,228; it says 50,000+.
- **Reel Mode overflowed small phones** by up to 681 px. Fixed and covered by a test.
- **Leaderboard crashed in debug builds** (inherited widget read in `initState`). Fixed.
- **Search** now lists the note named by the query first.
- **PYQ ad gate dead end.** If no ad could load, the student could not open PYQs at all. After two failed
  loads the section now opens for 20 minutes, twice per app session. Nobody earns from an ad that cannot
  load, so this costs no revenue.
- **Tiny "papers"** (10-question ALP shifts) were merged into shared "Partial sheets" papers, and
  oversized papers (up to 760 questions) were split into ~110-question parts.

Left as is, for your call:
- No visible lock on individual PYQ papers; the lock appears only in the header and in the dialog.
- Material's built-in labels ("Back", "Dismiss", "Dialog") stay in English when the app is in Hindi
  (affects screen readers only).
- The "→" arrow in buttons is not in the Mukta font; Android falls back to a system font, so it renders on
  phones. Not an issue in practice.
- The app has no analytics (Firebase Analytics is not included). Without it, nothing in section 4 can be
  measured, and every number there is an assumption.

## 4. Revenue model (assumptions, not data)

All inputs below are my assumptions and should be replaced with AdMob data after about two weeks live.

- eCPM in ₹ per 1,000 impressions: banner 8, interstitial 120, rewarded 250, native 40.
- Retention: 35% on day 1, 15% on day 7, 9% on day 30, 4% on day 90.
- Installs ramp up linearly over the 180 days.

| Setup | ₹ per daily user per day | Daily users needed (average) | Installs needed (₹10 lakh) |
|---|---|---|---|
| Current ads, eCPM ×0.5 | 0.08 | 68,000 | 18.2 lakh |
| **Current ads, base eCPM** | **0.16** | **34,000** | **9.1 lakh** |
| Current ads, eCPM ×1.5 | 0.25 | 23,000 | 6.1 lakh |
| Proposed ads, eCPM ×0.5 | 0.25 | 22,000 | 6.0 lakh |
| **Proposed ads, base eCPM** | **0.50** | **11,000** | **3.0 lakh** |
| Proposed ads, eCPM ×1.5 | 0.75 | 7,000 | 2.0 lakh |

Reading it: with today's ad setup the target needs roughly 9 lakh installs. The proposed setup roughly
triples revenue per user, which brings the install need down to about 3 lakh. Whichever way, **users are
the bigger lever**: ad changes move the number about 3×, while acquisition moves it 10×+.

## 5. Ad plan (approved and built; see store/ADS.md for the live rules)

Impressions per daily user per day, current → proposed: banner 0.4 → 3, interstitial 0.1 → 1,
rewarded 0.6 → 1.25, native 0 → 1.

1. **PYQ: unlock per full paper, keep the 30-minute window for practice sets.** A paper is a 90-minute
   sitting; one ad per paper is the norm in Indian exam apps and is the single biggest lever.
2. **Interstitial after every 3rd completed quiz or paper (any mode), not just mocks.** First two sessions
   ad-free, at least 3 minutes between interstitials, never during a question.
3. **Anchored banner on Practice, the PYQ lists and the bottom of results**, not only Progress.
4. **Native ad every ~10 rows in the PYQ list and search results.**
5. **Rewarded "unlock the full solution video/explanation after a paper"** once explanations exist.
6. **Add Firebase Analytics** (sessions, PYQ opens, ad shown/failed, paper completion) so these numbers
   become real.

Guardrails (AdMob and Play policy): rewarded ads stay opt-in; no ad at launch or exit; no ad within a
touch target; keep ads clearly separate from content; don't pay out or gate on clicks. Pushing frequency
too hard costs retention, which costs more than the extra impressions earn, so ship (2) and (3) first and
watch day-1 and day-7 retention before turning anything else up.

## 6. Growth: how PYQ becomes installs

The ad plan only matters if the users arrive. PYQ is the hook: students search for "RRB NTPC previous
year paper" and "Group D 2025 question paper" every day. Suggested order of work:
1. Store listing and screenshots built around PYQs (numbers, exam names, "Hindi + English").
2. Shareable results ("I scored 72/100 in NTPC 2025 Shift 2") through the existing share card, with the
   Play link.
3. One landing page per exam and year (the SEO plan in `SEO_AEO.md` already outlines this).
4. Short videos solving one real PYQ with a "full paper in the app" call to action.
5. Referral (already built) tied to a reward students want, such as an extra unlock.
