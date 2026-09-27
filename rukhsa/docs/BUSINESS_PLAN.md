# RUKHSA — Business Plan (Draft v1)

Status: working draft for decision-making, not a funded forecast. Numbers marked
"estimate" are directional and need live market validation (App Store/Play
Store keyword research, real CAC tests) before being used to commit spend.

---

## 1. Market & Positioning

### Who buys this

UAE RTA theory-test prep is bought almost entirely by expat residents applying
for a UAE driving licence (Emiratis largely learn to drive young and skew less
toward app-based prep, though some overlap exists). The UAE's resident
population is roughly 90% expat, and by nationality the largest cohorts are:

- **India** — largest single expat group (~3.5M+), spans blue-collar
  (construction, transport, retail) and large white-collar/professional
  segments. Hindi, Urdu, and English/Malayalam/Tamil-adjacent needs.
- **Pakistan** — second-largest South Asian cohort, heavy blue-collar and
  transport-sector representation, strong demand for Urdu-language content.
- **Philippines** — large, English-literate but often more comfortable in
  Tagalog/Filipino; concentrated in services, hospitality, healthcare.
- **Bangladesh** — large blue-collar cohort, Bengali-first, often the
  segment worst served by English-only competitor sites.
- Secondary: Egypt, other Arab expats (Arabic), and a long tail (Nepal, Sri
  Lanka, African nations) that the "12 languages" strategy also captures.

The buyer profile skews toward people for whom (a) English is not a first
language, (b) a driving licence is directly tied to income (delivery,
transport, logistics jobs) or to family logistics, and (c) price sensitivity
is real — many are remitting income home. This shapes both pricing and the
free-tier requirement below.

### Competitive landscape

Three identified incumbents, all free, ad-supported, and web-only:

| Competitor | Model | Platform | Languages | Gaps |
|---|---|---|---|---|
| theorytestrta.com | Free, ads | Web only | Limited/English-first | No native app, no offline, no flashcards/mind maps |
| yallapass.ae | Free, ads | Web only | Limited | Same — web UX, no app-store presence |
| theorytestuae.com | Free, ads | Web only | Limited | Same |

None of the three has a confirmed native app-store listing. That is RUKHSA's
opening: a real installed app (works offline, feels premium, is discoverable
via App Store/Play Store search rather than only Google web search) with
flashcards, mind maps, and RTA-format mock-exam simulation in the user's own
language, done properly in 12 languages rather than bolted-on machine
translation.

**Be honest about the threat**: these are *free* and already rank on Google
for the obvious search terms. A UAE resident price-shopping for exam prep can
solve their problem for AED 0 today. RUKHSA cannot out-free them, so it must
win on experience (native app feel, offline reliability, structured study —
mock exam realism, flashcards, mind maps) and on languages the competitors
serve poorly (Bengali, Urdu, Tagalog, Tamil, Malayalam, Farsi) rather than
compete purely on price or on being "the only option."

### Differentiation summary

1. Real native app (App Store + Play Store discoverability, offline use — no
   data plan needed, which matters for cost-sensitive blue-collar users).
2. 12 languages done as first-class content, not machine-translated overlay.
3. Flashcards + mind maps as study aids beyond flat Q&A — nothing found in
   competitor products.
4. RTA-format mock exams (structured to mirror the real test's shape) vs.
   competitors' generic question dumps.

---

## 2. Business Model Options

| Model | Description | Pros | Cons |
|---|---|---|---|
| (a) One-time paid app | Pay upfront to install/use at all | Simple, no ongoing billing infra | Free competitors make this a hard sell for price-sensitive buyers; kills discovery via free search traffic; App Store paid-app installs are structurally lower than free |
| (b) Freemium | Free tier (real, usable practice) + paid unlock (full bank, mock exams, offline PDF cheat sheets, ad-free) | Matches how users already behave (they expect free); paid tier funded by the minority who value speed/certainty; builds trust before asking for money | Needs enough free value to be worth installing over a free website; conversion rates are typically low (see P&L assumptions) |
| (c) Free + ads | Ad-supported, no paywall | Matches competitor model directly, lowest friction to install | Ad revenue at low install volumes (thousands, not millions, in year 1) is close to negligible; UAE CPMs for this audience are modest; ads degrade the "premium native app" positioning that is the differentiation |
| (d) B2B2C (driving-school partnerships) | Licence the app to typing centers/driving institutes who bundle it with enrollment, revenue share or flat licensing fee per school | Direct line to the highest-intent audience (people who've already paid for lessons); low CAC per user (schools already have foot traffic); potential recurring B2B revenue independent of consumer conversion | Requires in-person sales effort and relationship-building (slow for a solo operator); schools may want white-label or exclusivity, which conflicts with a single consumer app; revenue share cuts unit economics |

### Recommendation: Freemium (b), with B2B2C (d) as the highest-leverage
### secondary channel, not a separate business model

Given that free, web-based competitors already exist and rank on Google,
launching a purely paid app is fighting the market. Freemium lets RUKHSA
compete on the same "free to start" terms while monetizing the users who
value more than the competitors offer: full question bank, offline PDF
cheat-sheets, ad-free mock exams, and (a genuinely differentiated hook)
unlimited mock-exam attempts formatted like the real test.

B2B2C should not be treated as a fourth, separate revenue line to build in
parallel — for a solo operator, it is better used as a **distribution and
trust channel that feeds the freemium funnel**: a QR code at a driving
school that says "free RTA practice app" gets someone to install, and the
freemium mechanics do the monetizing from there. A modest flat referral fee
or discount-code arrangement with schools is realistic; a full revenue-share
integration is likely too much operational overhead for a solo/AI-driven
build in year one.

Free + ads (c) is not recommended as the primary model because at realistic
year-one install volumes (low thousands), ad revenue is unlikely to be
meaningful, and ads work against the differentiation from competitor sites
that already stuff pages with ads.

---

## 3. Pricing (needs live market validation)

Comparable exam-prep app categories (driving theory, DMV practice tests,
professional certification prep) commonly cluster around these price bands on
the App Store / Play Store, based on general familiarity with the category —
**this must be checked against current live listings before committing**,
since pricing in this category shifts and regional (UAE) pricing tiers differ
from US/UK list prices:

- One-time unlock: **$2.99–$6.99** (commonly $4.99) is the typical band for a
  single "remove limits / unlock full content" purchase in exam-prep apps.
- Subscription: **$1.99–$4.99/month**, often with a discounted annual option
  (e.g., $9.99–$14.99/year) — subscriptions fit exam apps poorly because most
  users only need the app for 4–8 weeks (the study period before their test),
  so monthly recurring billing works against retention/goodwill unless framed
  as a short "exam pass" period.

**Recommended starting price points for RUKHSA** (to validate before launch):

1. **Free tier**: limited question bank (e.g., 2–3 categories, ~20–30
   questions), basic flashcards, one mock exam attempt.
2. **"Full Access" one-time unlock — AED 14.99 (~$4.08)**: full question
   bank across all 12 languages, unlimited mock exams, all flashcards/mind
   maps, ad-free.
3. **"Exam Week" short-term pass — AED 9.99 (~$2.72) for 14 days**: cheaper
   entry point aimed at users close to their test date who want full access
   but balk at a "forever" price; also useful as a low-commitment upsell
   from the free tier.

Anchor UAE pricing in AED (local psychological pricing, e.g., ending in .99
AED) rather than converting a USD price literally — round-number AED pricing
reads as more native to the market.

---

## 4. Distribution & Marketing Channels

Ranked by cost vs. expected reach for a bootstrapped solo operator (lowest
cost / highest leverage first):

| Rank | Channel | Cost | Expected reach/effort | Notes |
|---|---|---|---|---|
| 1 | **ASO (App Store Optimization)** | $0 (time only) | High, compounding, passive | Keyword strategy per language is the single highest-leverage lever — see below |
| 2 | **Driving-school partnerships (flyers/QR at physical institutes)** | Low (printing cost, ~AED 100–300 for an initial flyer run) | Medium-high, very high intent | Best CAC in the plan: people at a driving school are actively preparing for this exact exam |
| 3 | **Expat community Facebook/WhatsApp groups** | $0–low (time; occasional small boost spend) | Medium, high intent, but requires ongoing manual posting and community trust-building | Target specific nationality groups (e.g., "Indians in Dubai," "Pinoy in UAE," "Pakistanis in Dubai") — must add value (free tips), not just post links, or risk being seen as spam/removed |
| 4 | **TikTok/Instagram short-form content** | $0 (organic) or low (boosted) | Potentially high but unpredictable; requires consistent content production | "3 RTA signs you'll definitely be tested on" style content; slow to build following without an existing audience |
| 5 | **Referral mechanic (invite-a-friend for free premium)** | $0 (feature cost only — engineering time) | Low-medium initially (needs an existing user base to refer from) | Best used once there's baseline installed base (month 2–3+), not a launch-day channel |
| 6 | **Paid ads (Meta/Google/TikTok ads)** | Variable, real cash spend | Scalable but requires budget and testing | Not recommended in month 1–2 given uncertain CAC; revisit once organic channels validate a conversion funnel |

### ASO keyword strategy by language (illustrative, needs live keyword-tool validation)

- English: "RTA theory test", "Dubai driving test practice", "UAE driving
  theory"
- Arabic: "امتحان نظري مرور دبي", "اختبار نظري قيادة الامارات"
- Urdu: "RTA theory test Urdu", "ڈرائیونگ تھیوری ٹیسٹ اردو"
- Hindi: "RTA theory test Hindi", "दुबई ड्राइविंग टेस्ट हिंदी"
- Tagalog/Filipino: "RTA theory test Tagalog", "Dubai driving exam Filipino"
- Bengali: "RTA theory test Bengali", "দুবাই ড্রাইভিং থিওরি টেস্ট"

Each language's store listing (title, subtitle/short description, keyword
field on iOS, long description on Play) should be localized natively, not
machine-translated verbatim, since App Store search matching is
language/locale-specific.

---

## 5. Simple 12-Month P&L Model (directional, not a forecast)

### Stated assumptions

- App store fee: 15% (Apple/Google Small Business Program rate, assumed
  eligible at this revenue scale; standard rate is 30% for larger developers
  — flag this as something to confirm once revenue is real).
- Free-to-paid conversion: **3%** base case (conservative for exam-prep
  freemium; range 2–5% quoted in the brief is used as low/high bounds).
- Average revenue per paying user (blended one-time unlock + exam-week
  pass): **~AED 13 (~$3.55)**.
- No salary/payroll cost assumed (solo/AI-assisted build).
- Modest paid ad spend only from month 4 onward in base case, testing
  budget only.
- MAU growth curve: slow start (ASO + school partnerships ramping),
  accelerating months 4–8 as content/localization completes and word-of-
  mouth/referral kicks in, plateauing months 9–12 pending re-investment.

### Monthly Active Users (MAU) and revenue — Base Case

| Month | New Installs | Cumulative MAU | Paying Users (3% conv.) | Revenue (AED) | Revenue (USD est.) |
|---|---|---|---|---|---|
| 1 | 300 | 300 | 9 | 117 | 32 |
| 2 | 500 | 750 | 23 | 299 | 81 |
| 3 | 800 | 1,400 | 42 | 546 | 149 |
| 4 | 1,200 | 2,300 | 69 | 897 | 244 |
| 5 | 1,600 | 3,500 | 105 | 1,365 | 372 |
| 6 | 2,000 | 5,000 | 150 | 1,950 | 531 |
| 7 | 2,200 | 6,500 | 195 | 2,535 | 690 |
| 8 | 2,400 | 8,000 | 240 | 3,120 | 850 |
| 9 | 2,200 | 9,300 | 279 | 3,627 | 988 |
| 10 | 2,000 | 10,500 | 315 | 4,095 | 1,115 |
| 11 | 1,800 | 11,500 | 345 | 4,485 | 1,222 |
| 12 | 1,600 | 12,300 | 369 | 4,797 | 1,307 |
| **Total (yr 1)** | | **12,300 cumulative installs** | | **~AED 28,000** | **~$7,600** |

*(MAU here is treated simply as cumulative installs net of a rough churn
assumption baked into the conversion rate; a real cohort/retention model
should replace this once there's actual usage data.)*

### Low / High case (same install curve, conversion rate varied)

| Case | Conversion rate | Year-1 revenue (AED) | Year-1 revenue (USD est.) |
|---|---|---|---|
| Low | 2% | ~18,700 | ~5,100 |
| Base | 3% | ~28,000 | ~7,600 |
| High | 5% | ~46,700 | ~12,700 |

### Rough cost lines (Year 1)

| Cost | Amount | Notes |
|---|---|---|
| Apple Developer Program | $99/yr | Required, one-time annual |
| Google Play Developer | $25 one-time | Required |
| App store transaction fees (15%) | ~AED 4,200 (base case) | Deducted from gross revenue above |
| Flyer printing (driving-school outreach) | ~AED 500–1,000 | One-off + occasional reprints |
| Paid ad testing budget (months 4–12, optional) | AED 3,000–6,000 total (~$800–1,600) | Only if base-case organic traction looks weak by month 3–4; entirely discretionary |
| Misc. (domain, minor tooling) | ~AED 500 | |
| **No salary/payroll assumed** | $0 | Solo/AI-assisted build |

**Headline base case**: ~AED 28,000 (~$7,600) gross revenue in year 1, against
maybe AED 5,000–10,000 (~$1,400–2,700) in real cash costs depending on
whether paid ads are used — meaning this is a small-but-real side-income
outcome in year 1, not a business that replaces a salary. The realistic case
for de-risking this is to treat months 1–3 as a live experiment: if actual
install/conversion numbers track meaningfully below the low case, the
freemium assumption itself (or the free tier's generosity) needs revisiting
before spending anything on ads.

**Honesty note**: every number above is a planning assumption, not a
measurement. The single most valuable next step to de-risk this model is
getting real install and conversion data from the first 4–6 weeks live, then
rebuilding this table from actuals.

---

## 6. Legal / Compliance

### Non-affiliation — required, and must appear in Terms & Privacy documents

RUKHSA's in-app UI must never claim or imply official RTA affiliation,
endorsement, or partnership. This is both a legal-liability protection and
very likely a hard App Store/Play Store review requirement for any app that
references a government body, exam, or regulatory brand in its name,
description, or content (both platforms routinely reject or pull apps that
imply unauthorized government affiliation).

Ready-to-use disclaimer paragraph (already included in the drafted
`PRIVACY_POLICY.md` and `TERMS_AND_CONDITIONS.md`):

> RUKHSA is an independent, privately developed educational study aid. It is
> **not affiliated with, endorsed by, sponsored by, or in any way officially
> connected to the UAE Roads and Transport Authority (RTA), Dubai Police, any
> other UAE traffic or licensing authority, or any UAE government entity.**
> All trademarks, service marks, and trade names referenced (including "RTA")
> are the property of their respective owners and are used solely for
> descriptive, nominative reference to identify the subject matter this app
> helps users study for. Use of this app does not guarantee success in any
> official driving theory examination.

This paragraph should also be considered for a short, non-intrusive mention
in the app's store listing description (not the in-app UI itself) if store
policy requires it — this is worth confirming directly against current Apple
App Store Review Guidelines and Google Play policy at submission time, since
policy specifics change.

### Open legal question — flagged, not resolved here

Whether selling a paid digital product (in-app purchases/subscriptions) to
UAE-resident consumers requires the developer to hold a UAE business licence
(mainland or free-zone), register for VAT, or otherwise formally establish a
business presence is **a real open question this plan does not have
certainty on**, and the answer has genuine legal/tax consequences. It also
interacts with which App Store/Play Store "merchant of record" arrangement is
used (Apple and Google typically act as merchant of record for in-app
purchases globally, which may or may not change the UAE licensing analysis).
**Recommend the user verify this directly** — e.g., via a UAE free-zone
company formation consultant, the UAE Federal Tax Authority's guidance on
digital services, or a local business/legal advisor — before scaling paid
revenue meaningfully. This should not block a soft launch under the
app-store-as-merchant-of-record model, but should be resolved before treating
this as a registered ongoing business.

---

## 7. 90-Day Roadmap

### Days 1–30: Finish the product, prepare for launch
- [ ] Complete content expansion (question bank growth beyond current
  61–250+, all `needsVerification` flags resolved against official RTA
  sources) — content-team work, in progress in parallel.
- [ ] Finalize free vs. paid tier split (which categories/features are
  free vs. gated) — **user decision**: exact free-tier generosity directly
  trades off install-to-trust vs. monetization, and is a judgment call only
  the founder should make.
- [ ] Build in-app purchase / paywall flow (one-time unlock + exam-week
  pass SKUs).
- [ ] Write and finalize App Store / Play Store listing copy per language
  (start with English, Arabic, Urdu, Hindi — largest cohorts — then extend).
- [ ] **User action required**: create Apple Developer Program account
  ($99/yr, requires payment) and Google Play Developer account ($25
  one-time, requires payment) if not already done — Claude/AI agents cannot
  create or pay for these on the user's behalf.
- [ ] **User action required (flagged in Section 6)**: begin checking UAE
  business licensing / VAT requirements for selling a paid app to UAE
  residents, in parallel with the above (does not need to block submission
  but should be resolved before meaningful revenue scale).
- [ ] Design and print initial driving-school flyer/QR-code materials.

### Days 31–60: Launch and initial distribution
- [ ] Submit to both stores; handle review feedback (non-affiliation
  disclaimer language should reduce risk of rejection here).
- [ ] Launch ASO-optimized listings in priority languages.
- [ ] Begin in-person or phone outreach to 5–10 driving schools/typing
  centers in Dubai/Abu Dhabi/Sharjah for flyer placement — **best done as
  direct founder outreach**, since a solo relationship-building channel is
  hard to delegate or automate.
- [ ] Post in 5–10 nationality-specific expat Facebook/WhatsApp groups with
  genuinely useful free content (not just a link drop) to start building
  organic word-of-mouth.
- [ ] Instrument basic install/usage analytics (respecting the offline-
  first, privacy-first positioning — see `PRIVACY_POLICY.md` for what data,
  if any, should be collected) to start validating the P&L assumptions in
  Section 5 against real numbers.

### Days 61–90: Measure, adjust, decide on paid spend
- [ ] Review actual install/conversion data against the low/base/high cases
  in Section 5; rebuild the model from actuals.
- [ ] **User decision required**: whether to approve any paid ad spend
  (Meta/Google/TikTok) based on months 1–2 organic performance — this is a
  real-cash-outlay decision that should stay with the founder, not be
  assumed.
- [ ] Launch referral mechanic once there is a meaningful installed base to
  refer from.
- [ ] Expand driving-school partnerships based on which, if any, showed
  measurable referral traffic.
- [ ] Revisit pricing (Section 3) if conversion data suggests the price
  points are meaningfully mismatched to willingness-to-pay.

---

## Summary of open questions genuinely requiring the founder's decision

1. Exact free-tier vs. paid-tier content split (trust-building vs.
   monetization trade-off).
2. UAE business licensing / VAT status for selling a paid app to UAE
   residents — needs direct verification, not assumed here.
3. Whether and when to approve paid ad spend, and how much.
4. Apple/Google developer account creation and payment (cannot be done by
   an AI agent).
5. How much manual, in-person effort to commit to driving-school
   partnership outreach, given it is the highest-intent channel but the
   least automatable.
