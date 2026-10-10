# Scheduler (Cloudflare Worker)

## Why
GitHub's own `schedule:` is best effort. In this repository it ran 3 to 7 hours late and dropped runs (the Telegram post
due at 02:30 UTC ran at 09:21 UTC), so it cannot carry an hourly Telegram quiz and six Shorts a day. A Cloudflare Worker
with a cron trigger fires on the minute and starts the same workflows through GitHub's API (`workflow_dispatch`).
Everything else (what is posted, the language, the question) is still decided by the workflows.

## What it starts (IST)
- **Telegram**, every hour 06:00 to 23:00: a PYQ quiz poll (Hindi and English alternating), except 11:00 the fact or
  cheat sheet, 17:00 the study tip, and Sunday 19:00 the weekly recap.
- **YouTube Shorts**, 07:00, 10:00, 13:00, 16:00, 19:00, 22:00: slots 1 to 6, language `auto`.

One cron trigger does all of it: `30 0-17 * * *` (UTC). `plan()` in `ops/scheduler_worker.js` decides what is due;
`node railpariksha/ops/test_scheduler.mjs` checks it.

## Setup (owner, about 5 minutes, once)
1. **GitHub token** (GitHub, Settings, Developer settings, Personal access tokens, Fine-grained tokens, Generate new):
   name `railpariksha-scheduler`, expiry 1 year, Repository access **Only select repositories** and pick `MahaPariksha`,
   Repository permissions **Actions: Read and write**. Generate and copy it. It is shown once; never paste it in chat.
2. **Worker** (Cloudflare dashboard, Workers & Pages, Create, Create Worker): name `railpariksha-scheduler`, Deploy,
   then **Edit code**, replace everything with the contents of `railpariksha/ops/scheduler_worker.js`, Deploy.
3. **Secrets** (the Worker, Settings, Variables and Secrets, Add): type **Secret**, name `GH_TOKEN`, value the token.
   Add a second secret `RUN_KEY` with any random text (used only to test).
4. **Cron** (the Worker, Settings, Triggers, Cron Triggers, Add): `30 0-17 * * *`.
5. **Test**: open `https://railpariksha-scheduler.<your-subdomain>.workers.dev/?run=<RUN_KEY>`. It answers with one
   line per workflow started ("started"), and the runs appear in GitHub Actions within seconds.
6. Tell Claude it works; the workflows' own `schedule:` entries are then removed so nothing runs twice.

## Renewing
The token expires after a year. When runs stop, the Worker's logs (Workers, Logs) show `FAILED 401`; make a new token
and replace the `GH_TOKEN` secret.

## If the default branch changes
Set the Worker variable `REF` to the new default branch name (it is `aniketai/relaxed-albattani-6kjmc7` now).
