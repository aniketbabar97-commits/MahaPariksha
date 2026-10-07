# Owner to-do (things only you can do)

Kept in the repo so it travels with the project. Tick items off as you go.

## Shipping checklist (in order)
1. **Firestore rules:** paste `railpariksha/firestore.rules` into Firebase Console → Firestore → Rules → Publish
   (the backup rule was tightened after the first version, so re-publish even if you did it before).
2. **Install the latest release build** from the Actions run (artifact `railpariksha-release-build`) and check:
   a Hindi PYQ paper reads cleanly, an RPF question shows a real explanation, Me → Text size changes the
   size, Google sign-in offers a restore on a reinstall, and search finds Hinglish ("railway" typed in Latin
   for a Hindi question).
3. **Play Console:** privacy policy URL, Data safety, Ads declaration and the new listing text (items above).
4. **Store screenshots:** upload the seven files in `docs/store/play_console_assets/screenshots/`
   (they are already framed with Hindi headlines; regenerate with `docs/store/tools/` after UI changes).
5. **Release track:** promote the build the way you prefer; builds are dispatched to the *internal* track and
   nothing is uploaded to Alpha automatically.

Questions that still show the plain "Correct answer (official answer key)" line are the ones where an
independent solve disagreed with the key or could not confirm a fact. They deliberately keep the official
key; the list is in `pipeline/pyq/explanations/*.flags.jsonl` if you ever want to review them.

## Reading student error reports
"Report an error" in the quiz now writes one small record per report to Firestore (Firebase
Console → Firestore Database → `reports`: question id, reason, language, whether it is a PYQ). It works
once the updated `firestore.rules` are published. See `docs/PYQ_KEY_REVIEW.md` for how to fix a key.

## Before the next Play Store release
- [ ] **Publish the updated privacy policy.** Source: `docs/store/PRIVACY_POLICY_for_google_doc.md`
      (new "Usage analytics" paragraph in English and Hindi). It must be live before the release
      that ships analytics.
- [ ] **Play Console → App content → Data safety.** Declare:
  - *Device or other IDs* (advertising ID, used by AdMob)
  - *App activity → App interactions* (Firebase Analytics; anonymous, not linked to identity)
  - *App info and performance → Crash logs and Diagnostics* (Firebase Crashlytics; not linked to identity)
  - And the **Ads** declaration: "Yes, my app contains ads".
- [ ] **Resubmit the store listing** with the new description (disclaimer at the top, Official
      Sources section) to clear the Misleading Claims rejection. Text: `docs/store/play_desc_en.txt`
      and `docs/store/play_desc_hi.txt`.

## Daily current-affairs job
- [x] **Add the API key as a GitHub secret** (done: `GEMINI_API_KEY` added): repo → Settings → Secrets and variables → Actions →
      *New repository secret* → `GEMINI_API_KEY` (optionally also `GROK_API_KEY`,
      `ANTHROPIC_API_KEY` for the extra Claude check). Then Actions → "RailPariksha daily current
      affairs" → *Run workflow* to test it. Until a key exists the job skips quietly (no failure
      emails). Two news feeds (PIB, Indian Express) return 403 to GitHub's servers; the job runs
      on the other feeds.

## After launch (needs about 2 weeks of Firebase Analytics data)
- [ ] **Watch day-1 and day-7 retention.** If either falls compared with the first week, cut ads in
      this order: 1) native ads, 2) the results-screen banner, 3) only then relax the interstitial
      beyond every 10th quiz (`AdPacing.every` in `app/lib/core/ads.dart`). Keep the per-paper PYQ
      rewarded ad; it is opt-in and the main earner.
- [ ] **Replace the model's guesses with real numbers.** Compare real eCPMs and ads per user from
      AdMob against `docs/UX_ADS_GROWTH_AUDIT.md` section 4 and re-run the 10 lakh / 180-day
      estimate.

## Telegram channel (fully automatic once set up)
Create the channel and the bot, add the bot as an admin (post, pin, change info), and set the GitHub secrets
`TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`. Optional variable `TELEGRAM_URL` adds a join tile to the app.
From then on the channel posts a picture card + quiz at about 06:50, three PYQ quiz polls, a flashcard or cheat
sheet, a study tip and a Sunday recap by itself. Steps, schedule and the `announce` slot for your own notices:
`docs/TELEGRAM.md`.

## Firestore rules (needed for progress backup/restore)
Paste the whole of `railpariksha/firestore.rules` into Firebase Console → Firestore Database → Rules → Publish.
Until the `users/{uid}/backup/progress` block is published, the app's "Back up now" and the restore
offer after Google sign-in quietly do nothing (they fail closed).
