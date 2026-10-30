---
tags: [moc, index]
---

# 📍 Project Map — start here

This is the front door to the design/planning history in this repo. Read **this
file first** when a task needs background on a past feature — it's one short
file instead of grepping through 30+ plan/spec docs.

Each feature below has up to two docs:
- **Design** — the *why*: problem statement, options considered, tradeoffs.
- **Plan** — the *what/how*: the task-by-task build log, checkbox-tracked.

Newest first within each area. A missing Plan means the Design was exploratory
or superseded before a build plan was written — the Design alone still has the
reasoning.

> Nothing below is auto-loaded. [[CLAUDE.md]] is read every session; open a
> link here only when the current task actually touches that area.

## Core project docs
- [[CLAUDE.md]] — ownership, DB schema, `record_sale` RPC contract, RLS, working agreements
- [[README]] — the public front page: pitch, APK download, features in click-to-open sections, Mermaid architecture, evidence, setup, roadmap. [[2026-10-20-public-readme-design|Why it is built that way]] (2026-10-20): **no demo password in the public README; every number copied from the evidence pack; diagrams test-rendered before pushing**
- [[RUN]] — run the app against Supabase (`dart_defines.json`, build commands)
- [[hackathon/easysell-project-brief|Hackathon project brief]] (2026-10-18) — everything the 10-slide Topic E deck needs, pitched **internationally** (Bangladesh = first market); the business plan restated in US$ at ৳123 = $1, with sourced global market figures
- [[hackathon/easysell-project-overview|Hackathon project overview]] + [[hackathon/easysell-demo-video-script|5-min demo video script]] (2026-10-18) — feature-by-feature overview to hand to Claude Chat, and a 10-scene timed script (problem → voice/camera selling → analysis → Money health → AI advice → financing → tools). **Record with `supabase/seed/demo_data.sql` loaded; its 5 weeks of sales make every loan "Not yet" (supplier credit needs 3 months), so the script says so on purpose**
- [[2026-10-19-execution-evidence-design|Execution evidence]] (2026-10-19) — the optional hackathon deliverable: live AI benchmark (voice 19/20, Bangla 10/10; camera 12/13), money-safety races, outside security probe, fresh test run and deployment checks, all re-runnable from `docs/hackathon/evidence/`. **Records why throwaway test accounts were used (demo shop untouched; 2 test logins remain in Auth), that cost is estimated (the AI functions return no token counts), and the TTS/Commons gotchas** (Google `translate_tts` is the only Bangla voice that worked)
- [[2026-10-20-security-self-assessment-design|Security self-assessment]] (2026-10-20) — the optional hackathon deliverable: 26 live attacks (23 blocked), secrets/APK/OSV scans, 17 findings (6 fixed, 0 high open). **New finding L1 (a row could name another shop's product or customer, blocking deletion of that shop) fixed by migration `0021_same_shop_links.sql`: five links now reference `(id, shop_id)`, delete behaviour unchanged**
- [[2026-10-20-money-rows-rpc-only-design|Sales and credit rows: functions only]] (2026-10-20) — fixes finding M2 with migration `0022`: a guard trigger refuses direct writes to `transactions`/`customer_ledger` by API users unless one of the 8 writer functions set `easysell.via_rpc`. **Any later `create or replace` of those functions must keep the `set_config` line; `ALTER FUNCTION … SET` was rejected (non-superusers can't set placeholders)**
- [[2026-10-20-ai-daily-limit-design|Daily AI limit]] (2026-10-20) — fixes finding M1 with migration `0023`: `claim_ai_call()` counts each AI call (50 per user per day, 500 for the app, changeable in `ai_limits`) and the three AI functions answer 429 before Gemini. **Fails closed; `ai_limit.ts` is copied into each function folder because dashboard deploys can't import across folders; email confirmation stays off until judging ends**
- [[2026-10-20-new-account-ai-limit-design|New-account AI limit + subscription plan]] (2026-10-20) — migration `0024`: accounts under 24 hours old get 10 AI calls a day (not 50), so mass sign-ups can't drain the app's 500; plus Supabase Auth's per-IP sign-up/sign-in rate limit. **Future plan (user's call): AI only for paying monthly subscribers, gated in `claim_ai_call()`**
- [[2026-10-31-phone-only-on-device-ai-design|Phone-only + on-device AI]] (2026-10-31, **proposed**) — drop Supabase and Gemini: SQLite on the phone; **"EasySell Vision", the app's own model (a bundled MobileNet/EfficientNet-Lite embedder that learns each shop's products from 2–3 photos, few-shot, on the phone, and keeps learning from confirmed scans; §5a records why training from scratch was rejected)**, fused with ML Kit text + local fuzzy search for scan; on-device speech + Dart parser for voice, rule-based money tips. **Supersedes the 2026-10-13 rejection of phone-only storage (user's choice); records the data-loss risk, the backup-file mitigation, ML Kit's lack of Bangla script, and that a fixed release key is now a prerequisite**
- [[claude_code_kickoff_prompt]] — the original project-kickoff prompt (historical, rarely needed)
- Supabase
  - [[supabase/README|Supabase project setup]] — hosted project + applying `migrations/0001_init.sql`
  - [[supabase/functions/parse-sale/README|parse-sale Edge Function]] — voice sentence → sale line items (Gemini)
  - [[supabase/functions/recognize-product/README|recognize-product Edge Function]] — item photo → matched product (Gemini vision)

## Voice sale
- [[2026-08-05-voice-wait-ux-design|Design]] (no separate plan — built straight from the brief) — shorten the post-speech wait and let the parse finish in the background; **records why chunked upload was rejected**, plus two follow-up fixes to the background banner (§8 the dead zone where a parsing sale was invisible and the mic silently ate it; §9 why a widget mounted above `MaterialApp.router` cannot push a route — and why the test suite stayed green through both)
- [[2026-07-27-voice-noise-latency-design|Design]] / [[2026-07-27-voice-noise-latency|Plan]] — fix ~30s timeout hang in noisy environments
- [[2026-07-27-voice-brain-gemini-migration-design|Design]] (no separate plan — folded into the scan/voice migration below) — merge transcribe+parse into one Gemini 3.6 Flash call
- [[2026-07-22-voice-sale-assistant-design|Design]] / [[2026-07-22-voice-sale-assistant|Plan]] — "speak a sale → cart" voice assistant, on-device speech-to-text pivot

## Vision scan
- [[2026-08-10-fast-scan-session-design|Design]] / [[2026-08-10-fast-scan-session|Plan]] — live viewfinder + background recognition + one review tray, replacing the serial camera→wait→sheet loop (~40 taps/75s → ~11 taps/20s for ten items); **records why the per-item confirmation sheet was a safety mechanism and what its removal costs** (§8), why one-photo-many-items and barcodes were rejected (§2), that the prompt re-sends the whole catalog every scan and ~90% of spend is that list not the photo (§6), and that the Edge Functions must deploy BEFORE the app or scans silently degrade to "no match" (§6.1). Final whole-branch review fix wave: `.superpowers/sdd/2026-08-10-fast-scan-session/final-fix-report.md` — an overlapping shutter tap silently swallowed (uncaught throw + no in-flight guard), a scrim tap on the leave-confirm dialog discarding the tray and exiting (`barrierDismissible` true + null mapped to Discard), a non-permission camera fault leaving a dead spinner forever, a concurrent `initialize()` race leaking a bound `CameraController` (generation-counter fix, reasoned through by hand — the file has no test seam), a sub-threshold single match silently auto-resolving instead of asking (the §8 auto-resolve confidence lever moving from 0.80 to 0.50 unnoticed), and "Open settings" not opening settings (relabelled to "Try again" — a recorded downgrade from spec §7, not wired to `permission_handler`/`app_settings`)
- [[2026-07-27-scan-gemini-migration-design|Design]] / [[2026-07-27-scan-gemini-migration|Plan]] — migrate `recognize-product` off Frog/OpenAI to Gemini 3.6 Flash direct
- [[2026-07-27-scan-quantity-confirmation-design|Design]] / [[2026-07-27-scan-quantity-confirmation|Plan]] — confirm sheet for scanned quantity before committing
- [[2026-07-04-vision-product-scan-design|Design]] / [[2026-07-04-vision-product-scan|Plan]] — original camera → Gemini/OpenAI closed-set product match

## Scan + voice (cross-cutting)
- [[2026-07-27-qol-scan-voice-batch1-design|Design]] / [[2026-07-27-qol-scan-voice-batch1|Plan]] — show AI read-back on scan, edit misheard transcript + re-parse, undo last cart add

## App-wide look
- [[2026-10-15-easysell-app-icon-design|Design]] (no plan, bounded) — app renamed **EasySell** (label/display name/recents/login heading; app ID kept `ai_shopkeeper` so it updates in place) and the launcher icon made from the logo mark. **The source JPG's transparency is a painted checkerboard**, so the icon PNGs were cut out by brightness. **`flutter_launcher_icons` corrupts `project.pbxproj`** (YES → AppIcon), so check the diff after every regenerate
- [[2026-10-15-easysell-ui-design|Design]] (no separate plan — build order is in §4) — **EasySell reskin** (light "Pastel glass" / dark "Neon glass") from `EasySell Ui/`. **User chose "keep features, new look"**: where a mockup is older than the app, the app's content wins. Records the 5 picks where mockups disagree (pills not underline tabs, per-product tile colour…), why the page backdrop is wrapped *inside* each page (transparent scaffolds behind the navigator would show pages through each other mid-transition), and the gradient-on-every-FilledButton trick via `ButtonStyle.backgroundBuilder`. **Built 2026-10-15; §5 build notes** carry the traps: that gradient covers any call-site `backgroundColor` (use `destructiveButtonStyle`), letter-spacing breaks Bangla conjuncts (`Eyebrow`/`hasBangla`), ten widget tests pump without `AppTheme` (read `AppColors` nullable there), and a colour↔gradient `ShapeDecoration` tween asserts

## Dashboard / Home
- [[2026-07-02-dashboard-day-drilldown-design|Design]] / [[2026-07-02-dashboard-day-drilldown|Plan]] — tap a day on the trend chart to drill into that day's sales
- [[2026-06-26-dashboard-redesign-design|Design]] (no separate plan) — Home tab redesign
- [[2026-06-23-kalo-dark-ui-redesign-design|Design]] / [[2026-06-23-kalo-dark-ui-redesign|Plan]] — the "Kalo-dark" visual theme rebuild

## Reports / Analytics
- [[2026-06-27-reports-tab-redesign-design|Design]] (no separate plan) — Analytics tab redesign

## History (transactions)
- [[2026-10-18-cramped-lists-layout-design|Design]] (no plan, bounded) — History table and Items rows cramped on a ~320 dp screen: time over AM/PM + gap, wider Qty, stock under the name on Items. **The app ignores phone font size (pinned to 1.0 in `app.dart`); Screen zoom (density) is what shrinks the layout** — a "cap text at 1.3×" fix was proposed and withdrawn for that reason
- [[2026-07-21-history-sale-detail-design|Design]] / [[2026-07-21-history-sale-detail|Plan]] — tap a past sale to see its line-item detail
- [[2026-07-03-history-calendar-day-filter-design|Design]] / [[2026-07-03-history-calendar-day-filter|Plan]] — calendar day filter + shop-lifetime floor date
- [[2026-10-15-sale-detail-expiry-design|Design]] (no plan) — sale detail shows the expiry date of the delivery the sale came from, via a PostgREST embed on the History queries; hidden (not "—") when the sale named no delivery

## Restock planner
- [[2026-10-15-restock-planner-design|Design]] / [[2026-10-15-restock-planner|Plan]] (built 2026-10-15, migration 0017) — "what to restock and how much" from a 4-week weighted sales speed (0.4/0.3/0.2/0.1) that skips out-of-stock days, so one spike week doesn't drive the buy; why not Gemini or a threshold-only alert; speed in Postgres, days-left/suggestion in Dart. §10: Home "Low stock" card merged into "Restock soon" (reorder level now feeds the planner) after the two contradicted each other.

## Inventory
- [[2026-10-15-home-inventory-header-cleanup-design|Design]] (no plan) — Home bell removed (every alert is already a Home card); Inventory header: Restock (with a Buy-now count badge) + Add, title one line via FittedBox. **§2a (same day) moved scan/voice back out of the search bar** (they looked like search tools but they SELL) into a tinted pill beside Restock/Add, all 40 dp; records that §2's "smaller buttons don't help" was wrong: `tapTargetSize: shrinkWrap` removes the 48 dp padding.
- [[2026-10-14-product-expiry-design|Design]] / [[2026-10-14-product-expiry|Plan]] (built 2026-10-14; migrations 0011–0015) — expiry date per delivery, in-app alerts + a daily phone reminder, expired stock never sold by default. **Records why one date per product and exact lot tracking were rejected**, the shelf-life warning rule (bread warned the day before, not on arrival), why the expired count must be locked once (or sales silently eat it), that dates must be the phone's local date (server UTC is "yesterday" before 6 AM in Bangladesh), and that adjustment rows must be positive (0009's discount check). Phone reminder built here by the user's choice despite Member C owning notifications. **§11 is a 24-item edge-case review** — notably sold-out deliveries must auto-close (or an undated restock revives them as a false alarm), checkout must wait for expired-count locks, a batch needs a composite `(product_id, shop_id)` key because RLS only checks `shop_id`, and restock is made retry-safe in the same migration. Reconcile reads deliveries BEFORE stock, because the two streams refresh independently and a restock's delivery arriving first would close the old delivery as sold out. **§12 records the final review: the new cart block had undone 0010 (an unanswered identical retry must always get past any check in front of `record_sale_cart`)**, plus offline start cancelling reminders and the 1000-row cap. **§13 (2026-10-15): pick the batch at checkout** — a per-delivery `picked_qty` counted inside `record_sale_cart` (not lot tracking; why the two alternatives were rejected), the cart defaulting to soonest-expiry-first with every part naming its delivery, why an unanswered retry must re-send its old split rather than re-split (else a double sale), and why reconcile now reads deliveries + stock in ONE joined request (a picked sale between two reads would close an old delivery that still has stock). **§14: "None left" removed** — it closed a delivery without lowering stock, so items thrown away a day early stayed sellable; every unexpired delivery now has "Remove from stock" (`remove_batch_stock`, 0013, needs 0012). **§15: remove part of a delivery** — "How many?" on Remove; a partial removal counts as a pick so the right batch loses the units (hand-editing stock takes them from the oldest batch), and it needed a phone-minted removal id because an open delivery can no longer use "already closed" to catch a retry (0014). **§16: stock moves only through sales, Restock and Remove** — Edit product lost its stock box (`toUpdateRow` never writes stock), Edit delivery shows its amount read-only, and undated stock (all of a soap's) got its own "No expiry date" row with Remove (0015); records the accepted gap of an over-dated batch. **§17: the seller must choose the batch** — several batches means "Choose" and checkout waits, one batch is shown with no tap; "several batches, soonest expiry first" survives only when no single batch holds the line (why not one cart line per batch). **§18: "Thrown away: N pcs · ৳X lost"** replaces the Closed list — summed from removal `adjustment` rows at their frozen buying price; closed rows stay in the DB. **§19: identical deliveries merge** (0016) — same expiry, date added and buying price join one row via a `BEFORE INSERT` trigger (why a trigger, why price must match); existing duplicates merged once.

## Sale cart
- [[2026-10-15-payment-method-design|Design]] (no plan, bounded) — **Cash · Digital · Credit** toggle at checkout, shown in History (list row + sale detail) and nowhere else. `transactions.payment_method` per row (migration `0018`); credit derived server-side from `p_customer_id`; the app sends `p_payment_method` **only for digital**, so cash/credit still work if 0018 is missing; **old sales are not backfilled** (no-customer ≠ cash), so they show no label
- [[2026-10-14-sale-cart-idempotent-design|Design]] (no separate plan — bounded fix) — a retry after a lost reply could record a sale twice; the phone now mints the sale id and `record_sale_cart` records an id once (migration `0010`). **Records why the replay check must run before the stock check**, why an advisory lock (not a unique column), why a changed cart gets a new id, and that **0010 must be applied before the app ships or every checkout fails**. `0010` is applied (2026-10-14)
- [[2026-08-06-cart-discount-design|Design]] / [[2026-08-06-cart-discount|Plan]] — flat-amount discount before cashout, split across the transaction rows. **Records why a separate `sale_discounts` table was rejected** (grain mismatch double-counts a multi-line receipt), why the split floors rather than rounds, and — in §12 — what review caught afterwards. Two rounds of it: five defects in the migration (including that **PL/pgSQL rounds on assignment to a declared typmod**, which silently undid the flooring the whole design rests on), then two Criticals that nine per-task reviews had each passed — a **gross** total in the success snackbar, misstating every discounted sale and every khata debt, and `numeric(10,3)` quantity rounding that let Dart and Postgres disagree on the bill. Also records why the cap is `sum(floor(line))` and not `floor(sum(line))`. Migration `0009` is applied (verified 2026-10-14: the live function body matches the repo).
- [[2026-07-07-sale-cart-design|Design]] / [[2026-07-07-sale-cart|Plan]] — multi-line cart before committing to `record_sale_cart`

## Money health / financing (hackathon Topic E)
- [[2026-10-18-money-health-financing-design|Design]] (no separate plan; migration 0019) — weekly cash in/out/net + 4 cash-flow alerts and 4 **illustrative** financing types matched from the shop's own numbers. Aggregates in `get_finance_health`, rules in pure Dart. **Records why overdue debt is aged FIFO, not "since last payment"** (a settled-then-reborrowed customer looked 60 days late), why pre-0018 unlabelled sales count as cash for cash flow, why every threshold is relative (no currency amounts), and why the catalogue is code, not a table. **§9: "Get advice from EasySell AI"** (Edge Function `money-tips`): Gemini only words the numbers the app already calculated, called on tap only, cached per day + language + numbers; the chat version was rejected for the deadline
- [[2026-10-19-data-export-design|Design]] (**parked — not built, no plan**) — export sales, stock and customer credit as CSV plus a one-page monthly PDF report for lenders, through Android's share menu. Deferred until after the hackathon (user's choice). **Records the Bangla traps** (CSV needs a UTF-8 BOM; the `pdf` package has no Bengali glyphs, so a font must be bundled) and that a lender can't trust the report while owners can still edit their own sale rows. Resume at its "Open questions"

## Customer credit
- [[2026-07-17-customer-credit-khata-design|Design]] / [[2026-07-17-customer-credit-khata|Plan]] — "khata" running-credit ledger per customer

## Onboarding
- [[2026-07-11-onboarding-redesign-design|Design]] / [[2026-07-11-onboarding-redesign|Plan]] — first-time setup flow redesign

## Localization
- [[2026-07-11-bengali-localization-design|Design]] / [[2026-07-11-bengali-localization|Plan]] — Bengali translation + in-app language switcher

## Settings
- [[2026-10-20-dark-mode-default-design|Design]] (no plan) — a fresh install opens in **dark** mode; only an explicit stored `light` gives Light, so existing Light users keep it. **The Android launch screen was white and is now dark navy `#07112E`**, otherwise every cold start flashed white
- [[2026-10-20-remove-insights-trends-design|Design]] (no plan) — the Settings "Assistant" section ("AI Insights", "Trends") and both screens removed: their `insights` / `trend_data` tables never existed, so the screens were always empty. **Records why not to hide them behind a flag instead**, and that `CLAUDE.md` still mentions them on purpose

## Reliability
- [[2026-10-13-offline-selling-sync-design|Design]] (**parked — not built, no plan**) — offline selling with Supabase as backup/sync. **Records why phone-only storage was rejected** (a lost phone wipes the khata; AI pins a server anyway), that stage 1 = selling only (user's choice), and three server-side traps found in `record_sale_cart`: it mints the sale id itself (**retries can double-record a sale even today**), rejects low stock (wrong for a sale that already happened offline), and reads prices at sync time instead of sale time. Phone storage measured at ~10 MB/year. Resume at its "Open questions"
- [[2026-07-12-offline-banner-design|Design]] / [[2026-07-12-offline-banner|Plan]] — app-wide "no internet" banner
- [[2026-10-19-codebase-review-fixes-design|Full codebase review]] (2026-10-19, migration 0020) — bugs + security pass before the hackathon tech docs. **Lists what was checked and found sound** (RLS on every table, only 2 definer functions, the retry-safe money RPCs, no secrets in git). Fixed: **the AI functions took the APK's public anon key** (now signed-in, non-guest users only, plus size caps; why the claims check beat `auth.getUser()`, and never deploy with `--no-verify-jwt`); **dashboard/chart days cut at UTC midnight** while History used local (now `p_utc_offset_minutes`); **khata payments not retry-safe** (`p_payment_id`); a failed payment wiped the ledger view and hid its error; Android backup off. **Noted, not fixed:** debug-key signing, owners can edit their own transaction/ledger rows directly (matters once lenders rely on them), email confirmation off. **Paste 0020 before installing the new build.** **Second pass** probed the LIVE project with only the anon key: all tables return 0 rows, AI functions 401, but **anonymous sign-ins are ON server-side** (turn off in the dashboard); `insights`/`trend_data` tables never shipped (screens show empty states).

## Business
- [[2026-10-18-easysell-international-business-plan|International business plan]] (in `docs/business/`) — **replaces the Bangladesh-only FutureMakers plan (deleted 2026-10-18 at the user's request; it is in git history before that date)**. Targets 21–26M neighbourhood shops in six sized markets (sourced), entry order Bangladesh → Philippines + Kenya → Nigeria, Indonesia, Mexico → India via partner. **Key research finding: bookkeeping-only apps failed abroad (Kippa app offline 2024, BukuKas/Lummo collapsed); survivors (Khatabook ~₹103 cr FY24, BukuWarung) earn from lending/payments** — so records, alerts and financing matching are FREE (the lending funnel) and only the per-use AI is paid (US$2.99 list, US$2.50 avg). Unit economics US$1.48/shop/month (59%), 15% store fee included; forecast 500 → 5,000 → 25,000 paying shops, monthly profit by end of Y3; US$100k pre-seed. Unverified assumptions are labelled in the doc: 2% lender fee on a US$500 loan, US$5 CAC, 5% free→paid. The old plan's lesson still stands: without the AI product-shortlist fix, big shops cost more than they pay
- [[2026-10-13-futuremakers-business-impact-report|FutureMakers report]] (in `docs/business/`) — market research, social impact and business model for GP FutureMakers 2026 ("AI for Social Good"). **Records the AI cost per voice/camera sale** (~৳0.27–2.13 today depending on shop size, because the WHOLE product catalog is re-sent on every call; ~৳0.20 flat once a ~60-product shortlist + Flash-Lite for scan land), that `gemini-3.6-flash` doubles in price on 2027-01-01, break-even at ~150 paying shops on a ৳299 plan, and that offline manual sales + the shortlist are the two fixes needed before charging. Also notes the AI Insights/Trends screens have no backing tables (never built by Member B) and the DB region is Tokyo (a data-protection-law question)

---

### Keeping this map useful
Design and plan docs live in `docs/superpowers/specs/` and
`docs/superpowers/plans/` as `YYYY-MM-DD-feature-slug[-design].md` — that
convention is what makes the `[[wikilink]]`s above resolve without a folder
path. **Add one line to the right section above whenever a new doc lands**, so
this file stays the single place both you and I look first instead of
re-scanning the whole `docs/` tree.

This holds for work built straight from a conversation, not only for work
driven by a `superpowers` skill — see the rule in
[[CLAUDE.md]] §10. Skill-less work is the case most likely to leave this map
quietly incomplete, because nothing automatic prompts the entry. A doc is
worth writing for anything a future session would want the *reasoning* for,
including approaches that were investigated and **rejected**; the map notes
which entries carry a rejection record, since those are the ones that stop the
same analysis being redone.
