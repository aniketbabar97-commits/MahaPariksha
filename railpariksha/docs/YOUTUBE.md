# YouTube Shorts automation

`pipeline/shorts.py` and the workflow **RailPariksha Shorts** make one vertical video (about 20 s) six times a day
(07:00, 10:00, 13:00, 16:00, 19:00 and 22:00 IST) from a previous-year question: question and options, a 5-second
countdown, then the answer, a short explanation, and the app, website and Telegram links (also in every video
description). The language alternates between Hindi and English through the day and flips every day, so a
given clock time is Hindi one day and English the next. Each subject walks its own fixed shuffle, so nothing
repeats within a language for months.

Why six and not hourly: YouTube's default API quota is 10,000 units a day and one upload costs 1,600, so six
uploads (9,600) is the most that fits. More needs a quota-extension request in the same compliance audit form.
A brand-new channel may also be limited to a handful of uploads a day until it is verified by phone (Studio,
Settings, Channel, Feature eligibility).

## What works with no setup
Run the workflow (Actions, RailPariksha Shorts, Run workflow; pick a slot 1 to 6 and a language). It builds the video and keeps it as a downloadable
file for 7 days, so you can upload it to YouTube Studio by hand in a minute. The title and description are in the
log.

## Turning on automatic upload (owner, once, about 20 minutes)
1. Create a YouTube channel for the app (name, logo, website and Telegram link in the About section).
2. In Google Cloud Console create a project, enable **YouTube Data API v3**, and configure the OAuth consent screen
   (External; add the scope `https://www.googleapis.com/auth/youtube.upload`; add your own Google account as a test user).
   Then **Publish app** so the status is **In production**. If it stays on **Testing**, Google expires the refresh
   token after 7 days and uploads silently stop. The "Google hasn't verified this app" screen is normal for your own app.
3. Create an **OAuth client ID** of type **Web application** with the authorised redirect URI
   `https://developers.google.com/oauthplayground`. Copy the client ID and client secret.
4. Get a **refresh token**: open developers.google.com/oauthplayground, click the gear, tick "Use your own OAuth
   credentials", paste the client ID and secret, authorise the scope `https://www.googleapis.com/auth/youtube.upload`
   with the channel's account, click "Exchange authorization code for tokens" and copy the refresh token.
5. Add three repository **secrets** (never variables, never in chat): `YT_CLIENT_ID`, `YT_CLIENT_SECRET`,
   `YT_REFRESH_TOKEN`. Run the workflow once by hand (Actions, RailPariksha Shorts, Run workflow) and check the log
   says `uploaded: https://youtube.com/shorts/...`.
6. If uploads stop later with `invalid_grant`, the token was revoked or expired (consent screen back in Testing, or the
   password changed): repeat step 4 and replace `YT_REFRESH_TOKEN`.

## Wording of the videos
Title = exam + subject + year (what students search), no hashtags in it. Description = a keyword line, the four links,
then five hashtags. Tags are set per exam and subject. See `docs/store/youtube/channel_text.md` for the channel
keywords to paste into Studio.

## Limits to know
- **Unverified API projects upload as private.** Google locks videos uploaded through the API from an
  unaudited project to private. Until the project passes the YouTube API compliance audit (a form on the API
  documentation site), the automatic uploads will sit as private videos in Studio and you must switch them to
  public by hand, or keep uploading the downloaded file manually.
- Quota: one upload costs 1,600 of the default 10,000 daily units, so two a day is fine.
- A new channel gets almost no reach on day one whatever the automation does. Consistency over weeks matters.
