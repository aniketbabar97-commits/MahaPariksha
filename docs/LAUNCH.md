# Launch checklist: steps only the account owner can do

Everything else (app, content, pipelines, CI) is in this repo. These steps need your identity, money or accounts.

## 1. Accounts and identity (day 1)
- [ ] Buy the domains `bharari.app`, `bharariapp.com` and `bharariapp.in` (~₹3k/yr) and create the mailbox `support@bharari.app`.
      With a different email, build with `--dart-define=SUPPORT_EMAIL=you@x.com` and set the `SUPPORT_EMAIL` env for the site.
- [ ] Create a Google Play developer account ($25). Choose an individual or an organisation account. A new personal account must run a
      **closed test with at least 12 testers for 14 continuous days** before production.
- [ ] (Optional) File the trademark "Bharari / भरारी" in classes 9 and 41 (₹4.5k per class as an individual or MSME).

## 2. Signing key (keep it safe — losing it means you can't update the app)
```bash
keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload.jks > upload.jks.b64
```
Add GitHub repo secrets: `ANDROID_KEYSTORE_BASE64` (contents of upload.jks.b64), `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS` (=upload), `ANDROID_KEY_PASSWORD`. Enrol in **Play App Signing** when you create the app.

## 3. First release (manual, one time)
- [ ] In Play Console, create the app: name "Bharari", default language en-IN, then add the mr-IN translation from `docs/store/listing.md`.
- [ ] Run the **Release** workflow (Actions → Release → Run workflow). Download `app-release.aab` from the run or release.
- [ ] Upload that AAB manually to **Closed testing**. Google requires the first upload through the Console.
- [ ] Fill in: privacy policy URL (step 4), Data safety ("no data collected / shared"), Content rating (Everyone),
      Target audience (18+), Ads (No), Government-affiliation declaration (**not affiliated**; the app shows this disclaimer).
- [ ] Recruit 12+ testers: aspirants from your Telegram group or abhyasika, plus a paid testing service as a floor.
      Keep them opted in for 14 days, then apply for production.

## 4. Website, privacy policy and live content updates
- [ ] Repo Settings → Pages → Source: **GitHub Actions**.
- [ ] Repo variables: `CONTENT_URL` = `https://<user>.github.io/<repo>/content.json` and `SITE_URL` = `https://<user>.github.io/<repo>`.
      (Later, point `bharari.app` at Pages with a custom domain.)
- [ ] Run **Publish content pack**. The privacy policy is then live at `<SITE_URL>/privacy.html`.
      Installed apps then download new question packs automatically, with no Play update needed.

## 5. Automated Play uploads (after the first manual upload)
- [ ] Google Cloud → create a service account → grant it "Release manager" in Play Console → Users & permissions.
- [ ] Add its JSON key as the secret `PLAY_SERVICE_ACCOUNT_JSON`.
- [ ] From then on, pushing a tag `vX.Y.Z` builds, signs and uploads to the internal track. Promote the release in the Console.

## 6. Daily current affairs
- [ ] Add the secret `ANTHROPIC_API_KEY` (set a monthly spend limit in the Anthropic console; expected cost ≈ ₹500/month).
- [ ] Every morning at 06:00 IST a PR with verified questions appears. Review the source links and merge; publishing is automatic.

## 6c. Bulk question generation at lower cost (open-source draft model)
- [ ] `pipeline/generate_questions.py` drafts questions with a cheap/free open-source model and verifies every one with Claude before it ships (two passes: blind-solve + fact/ambiguity critique, same pattern as §6's daily current-affairs job). Only Claude tokens for verification are billed; drafting is free or near-free.
- [ ] Get a free API key at **console.groq.com** (default provider — fast, generous free tier, good enough for first-draft MCQ text that Claude then checks) and add it as the secret `GROQ_API_KEY`. `TOGETHER_API_KEY` / `OPENROUTER_API_KEY` / `DEEPINFRA_API_KEY` also work if you set `DRAFT_PROVIDER` to match (see `pipeline/draft_llm.py`).
- [ ] Without any of those keys set, the script still works — it falls back to drafting with Claude too, just at higher token cost.
- [ ] Run it per subject/topic, e.g.: `python3 pipeline/generate_questions.py --subject marathi --topic sandhi --count 200 --difficulty 2`. Rejected drafts (failed verification) print to stderr with a reason; only verified items are appended to `content/bank/<subject>.json`.
- [ ] After a run: `python3 pipeline/validate.py && python3 pipeline/check_duplicates.py && python3 pipeline/build_bundle.py`, then `flutter analyze && flutter test` in `app/` before committing.

## 6b. Ads (revenue — do this once traction is proven, not before)
- [ ] Create an AdMob account at admob.google.com, link it to the Play app once it's live (needs a real package/store listing first).
- [ ] Create one **rewarded** ad unit and, if you want it, one **native** ad unit for the Reel's placeholder slots (`app/lib/screens/reel_screen.dart`, `_adSlotCard()` — every 8th card in the Reel; Daily 10/mocks/practice stay ad-free by design).
- [ ] Add the AdMob App ID to `app/android/app/src/main/AndroidManifest.xml` (a `<meta-data>` tag — the `google_mobile_ads` package docs show the exact line) and add `google_mobile_ads` to `pubspec.yaml`.
- [ ] Replace the placeholder `_adSlotCard()` widget with the real `NativeAd`/`RewardedAd` widget. Test with Google's test ad unit IDs first — never ship your real ad unit ID in a debug build (Google can suspend the account for invalid traffic).
- [ ] Do this only after Daily-10 usage and retention look healthy. Ads shown to zero real users don't do anything — get the free loop working first.

## 7. Before production launch: human QA (do not skip)
- [ ] Two Marathi-medium aspirants (ideally one who has cleared a recent exam) review a random 100-question sample
      and every current-affairs item, and log any issue in `docs/review_log.md`.
- [ ] Test on a low-end phone (2–3 GB RAM): first launch offline, Daily 10, mock submit, flashcards, dark mode.
- [ ] Test notification reminders (Me tab → toggle on): allow the permission prompt, confirm both the morning
      and evening reminders fire at the chosen time (Android 13+ requires this runtime permission — the app
      requests it only when the user turns reminders on, never on first launch).
- [ ] Capture 8 screenshots for the listing (in-app, from a real device or emulator — not this repo's web preview).
