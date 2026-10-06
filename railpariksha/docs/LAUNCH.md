# Launch checklist: steps only the account owner can do

Everything else (app, content, pipelines, CI) is in this repo. These steps need your identity, money or accounts.
RailPariksha is a separate app from Bharari in this same repo — use its own domain, Play listing, keystore and secrets;
never reuse Bharari's `ANDROID_KEYSTORE_*` secrets or `app.bharari` package.

## 1. Accounts and identity (day 1)
- [ ] Buy a domain (e.g. `railpariksha.app`) and create the mailbox `support@railpariksha.app`.
      With a different email, build with `--dart-define=SUPPORT_EMAIL=you@x.com` and set `SUPPORT_EMAIL` for the site.
- [ ] Create (or reuse) a Google Play developer account ($25 one-time). A new personal account must run a
      **closed test with at least 12 testers for 14 continuous days** before production.
- [ ] Get API keys for the current-affairs pipeline: `GEMINI_API_KEY` (Google AI Studio), `GROK_API_KEY` (x.ai),
      and optionally `ANTHROPIC_API_KEY` for the Claude quality gate.

## 2. Signing key (keep it safe — losing it means you can't update the app)
```bash
keytool -genkey -v -keystore railpariksha-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias railpariksha-upload
base64 -w0 railpariksha-upload.jks > railpariksha-upload.jks.b64
```
Add GitHub repo secrets (these are shared by name with Bharari's release workflow, so if Bharari already uses
`ANDROID_KEYSTORE_BASE64` etc., create a **second** keystore for RailPariksha under different secret names and update
`railpariksha_release.yml` to reference them — do not sign both apps with the same key):
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (=railpariksha-upload), `ANDROID_KEY_PASSWORD`.

## 3. First release (manual, one time)
- [ ] In Play Console, create the app: name "RailPariksha", package `app.railpariksha`, default language en-IN,
      then add the hi-IN translation from `docs/store/listing.md`.
- [ ] Tag `railpariksha-vX.Y.Z` to trigger **RailPariksha release** (Actions), or run it manually via workflow_dispatch.
      Download `app-release.aab` from the run or release.
- [ ] Upload that AAB manually to **Closed testing**. Google requires the first upload through the Console.
- [ ] Fill in: privacy policy URL (step 4), Data safety ("no data collected / shared"), Content rating (Everyone),
      Target audience (18+), Ads (No), Government-affiliation declaration (**not affiliated** with Indian Railways/RRB/RPF;
      the app shows this disclaimer).
- [ ] Recruit 12+ testers: RRB/RPF aspirants from Telegram groups or coaching circles, plus a paid testing service as a floor.
      Keep them opted in for 14 days, then apply for production.

## 4. Website, privacy policy and live content updates
- [ ] The `railpariksha_content_pack.yml` workflow builds the site + `content.json` as a downloadable artifact only —
      it does **not** deploy to GitHub Pages, because Pages already serves Bharari's site from this repo (a repo has
      one Pages deployment target). Either host this artifact yourself and point `CONTENT_URL` at it, or once both
      apps are stable, merge `build_site.py` outputs into one combined Pages deploy under separate subpaths.
- [ ] Set the repo variable `RAILPARIKSHA_CONTENT_URL` once you have a hosting URL for `content.json`, so the release
      workflow bakes it into the app build.

## 5. Automated Play uploads (after the first manual upload)
- [ ] Google Cloud → create a service account → grant it "Release manager" in Play Console → Users & permissions.
- [ ] Add its JSON key as the secret `PLAY_SERVICE_ACCOUNT_JSON` (shared with Bharari's is fine if the same Play
      account manages both apps' releases; the workflow scopes uploads by `packageName: app.railpariksha`).
- [ ] From then on, pushing a tag `railpariksha-vX.Y.Z` builds, signs and uploads to the internal track.
      Promote the release in the Console.

## PYQ packs: what ships in the APK vs. downloads on demand
- The release build bundles only the **newest year of each railway exam** (`build_bundle.py --pyq-full`), so a
  student's own latest paper works offline from first launch. Older years and the topic shards are published as
  assets of the **`pyq-pack` GitHub release** (the release workflow regenerates and re-uploads them with `--clobber`)
  and the app downloads each one once, then caches it (`PyqRepo`). This keeps the Play download ~20 MB smaller.
- The `pyq-pack` release is a prerelease named "PYQ pack (auto-updated)"; never delete it, and never mark it as the
  latest release. If it is missing, the first release run creates it.
- CI's `flutter test` runs against the full pack (plain `build_bundle.py`), so tests never need the network.
