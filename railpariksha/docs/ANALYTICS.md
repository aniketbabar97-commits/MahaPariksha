# Analytics events (Firebase)

All events are fire-and-forget (`Analytics.log`), carry no personal data, and are no-ops without Firebase.
Build these in Firebase → Analytics → Funnels / Explore; they feed the launch decisions in docs/UX_ADS_GROWTH_AUDIT.md.

| Event | Params | Fired when |
|---|---|---|
| `onboarding_complete` | exam, goal, placement | last onboarding step saved |
| `quiz_start` / `quiz_complete` | mode, count… | any quiz / mock / paper |
| `pyq_open` / `pyq_set_open` / `pyq_topic_open` | set / topic | PYQ screens |
| `pyq_paper_start` / `pyq_topic_test_start` | paper / topic | timed PYQ attempts |
| `pyq_gate_shown` / `pyq_unlocked` / `pyq_ad_not_ready` | kind, via | the rewarded unlock flow |
| `interstitial_shown` | — | AdPacing fired an interstitial |
| `double_xp_claimed` | — | rewarded ad on results |
| `ad_free_hour_claimed` | — | rewarded ad on Me |
| `question_reported` | id, pyq | "report wrong answer" — fix the key in content/ and ship |
| `ca_digest_open` | — | Current Affairs digest opened |
| `flashcards_done` | known, cards | a flashcard session finished |
| `mission_complete` | streak | all three Today-mission items done (once a day) |

## Funnels worth building first
1. **Activation**: `first_open` → `onboarding_complete` → `quiz_complete` (same day). Target ≥ 60% of installs reach `quiz_complete` on day 0.
2. **Daily loop**: `session_start` → `ca_digest_open` / `mission_complete`. Mission completion among day-7 retained users is the retention health number.
3. **Ads**: `quiz_complete` → `interstitial_shown`; `pyq_gate_shown` → `pyq_unlocked` (rewarded completion; target ≥ 60%); `ad_free_hour_claimed` per DAU.
4. **Quality**: `question_reported` by id — review weekly; any id reported 3+ times gets its key re-checked.

Retention (day-1/7/30) is under Firebase → Retention; link AdMob to Firebase for ad revenue per screen/user (ARPDAU).
