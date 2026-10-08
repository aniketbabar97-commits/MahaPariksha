# YouTube Shorts automation

`pipeline/shorts.py` and the workflow **RailPariksha Shorts** make one vertical video (about 20 s) twice a day
(09:00 and 19:00 IST) from a previous-year question: question and options, a 5-second countdown, then the answer,
a short explanation, and the Telegram and app links. Questions rotate by date; nothing repeats for months.

## What works with no setup
Run the workflow (Actions, RailPariksha Shorts, Run workflow). It builds the video and keeps it as a downloadable
file for 7 days, so you can upload it to YouTube Studio by hand in a minute. The title and description are in the
log.

## Turning on automatic upload (owner, once, about 20 minutes)
1. Create a YouTube channel for the app.
2. In Google Cloud Console create a project, enable **YouTube Data API v3**, and create an **OAuth client ID**
   (type: Desktop app). Add your own Google account as a test user on the consent screen.
3. Get a **refresh token** for the scope `https://www.googleapis.com/auth/youtube.upload` by signing in once with
   that client (the OAuth Playground at developers.google.com/oauthplayground works: tick "Use your own OAuth
   credentials", authorise the scope, exchange the code, copy the refresh token).
4. Add three repository secrets: `YT_CLIENT_ID`, `YT_CLIENT_SECRET`, `YT_REFRESH_TOKEN`.

## Limits to know
- **Unverified API projects upload as private.** Google locks videos uploaded through the API from an
  unaudited project to private. Until the project passes the YouTube API compliance audit (a form on the API
  documentation site), the automatic uploads will sit as private videos in Studio and you must switch them to
  public by hand, or keep uploading the downloaded file manually.
- Quota: one upload costs 1,600 of the default 10,000 daily units, so two a day is fine.
- A new channel gets almost no reach on day one whatever the automation does. Consistency over weeks matters.
