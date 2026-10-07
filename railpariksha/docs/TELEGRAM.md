# Telegram channel: how it runs itself

Everything the channel posts is generated from content already in this repo and sent by GitHub Actions. The
owner creates the channel once; after that nothing needs a human.

## One-time setup (about 10 minutes)
1. Telegram → New Channel → public, e.g. `@RailPariksha`.
2. Telegram → @BotFather → `/newbot` → copy the token.
3. Channel → Administrators → add the bot with: **Post messages**, **Pin messages**, **Change channel info**.
4. GitHub → repo Settings → Secrets and variables → Actions:
   - Secrets: `TELEGRAM_BOT_TOKEN` (the token) and `TELEGRAM_CHAT_ID` (`@RailPariksha`).
   - Variable (optional, adds a "Join our Telegram" tile to the app at the next release build):
     `TELEGRAM_URL` = `https://t.me/RailPariksha`.
5. Actions → "RailPariksha Telegram" → Run workflow → slot `setup`. This sets the channel description and posts +
   pins the welcome message (it also happens by itself on the first scheduled post if nothing is pinned).

## Daily schedule (India time)
| Time | Post | Source |
|---|---|---|
| ~06:50 | Picture card with the day's stories, then a current-affairs quiz poll | `content/ca_feed.json` (built by the daily job) |
| 08:00 | Quiz poll: a real PYQ (maths / reasoning) | `content/pyq` with its worked explanation |
| 11:00 | Flashcard with the answer hidden under a spoiler, or a cheat-sheet card | `content/flashcards`, `content/cheat_sheets` |
| 13:30 | Quiz poll: science / railway GK / computer / reasoning | PYQ |
| 17:00 | Study tip or quote, today's special day (if any), and the app link | `content/motivation`, `content/gk_booster.json` |
| 20:00 | Quiz poll: general knowledge / railway GK / current affairs | PYQ |
| Sunday 19:00 | The week's current affairs in one post | `content/ca_feed.json` |

Every quiz poll shows the right answer and a Hindi explanation after a vote. Selection rotates by date from a fixed
shuffle, so no state is kept and nothing repeats for months. Polls use only text questions with a real explanation;
anything that needs a picture or seating diagram is skipped, and answer keys that were corrected keep their
corrected answer.

## Your own notices
Actions → "RailPariksha Telegram" → Run workflow → slot `announce`, type the text, run. Use it for exam
notifications (CEN dates, admit cards, results): those are the posts that spike installs, and a human should
confirm them first.

## What it will not do
- It does not scrape RRB websites or news for "breaking" notices (the sources block GitHub's servers and an
  unverified notice would hurt trust). Use `announce` for those.
- It cannot read replies or poll results (a channel bot gets neither without a server running all day).

## Checks
- `python pipeline/telegram_bot.py --slot poll_morning --dry-run` prints exactly what would be sent, no token needed.
- `python pipeline/test_telegram_bot.py` runs offline tests (poll limits, rotation, HTML validity); CI runs it.
- Each real run writes the channel's member count to the workflow summary, a free growth number.
