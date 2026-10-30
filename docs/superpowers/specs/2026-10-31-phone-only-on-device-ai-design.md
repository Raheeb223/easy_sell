# Phone-only EasySell with on-device AI — Design

**Date:** 2026-10-31
**Status:** **Proposed, awaiting the user's approval.** Nothing is built yet.
**Supersedes:**
- [[2026-10-13-offline-selling-sync-design]], which rejected phone-only storage.
  The user has now chosen phone-only storage, knowing the risk in §4.
- The CLAUDE.md §2 stack: Supabase backend, and Gemini behind Edge Functions.

**Related:** [[2026-07-27-scan-gemini-migration-design]], [[2026-07-27-voice-brain-gemini-migration-design]], [[2026-10-20-ai-daily-limit-design]]

## 1. What the user asked for

> "replace both of them and use the phone storage and an internal AI that searches in the phone — I don't need to host this"

The answers to the 2026-10-31 questions were:

| Question | Answer |
|---|---|
| Which AI features leave Gemini? | **Scan and voice, both.** |
| Where does shop data live? | **Phone only; drop Supabase.** |
| Which on-phone AI? | **Google ML Kit, working from the photo. No barcodes.** |

The goal is that nothing is hosted: no Supabase, no Gemini key, no server bill, and no internet needed for anything.

## 2. What changes

| Today | After |
|---|---|
| Supabase Postgres: 24 migrations, ~4,000 lines of SQL, 29 functions | **SQLite file on the phone** (`sqflite`). The SQL functions are rewritten as Dart services that run inside one SQLite transaction each. |
| Supabase Auth: email login, `shops` row | **No login.** First run asks for the shop name and saves it locally. An optional app PIN is possible later. |
| `recognize-product`: photo plus the whole catalog sent to Gemini | **ML Kit Text Recognition (on-device)** reads the words on the pack. A **local fuzzy search** then ranks the shop's products (§5). |
| `parse-sale`: audio sent to Gemini, which transcribes and extracts items | **Android on-device speech recognition** (`speech_to_text`) turns speech into text. A **Dart sale parser** then reads quantities and units and fuzzy-matches products (§6). |
| `money-tips`: facts sent to Gemini for advice text | **Rule-based tips** written from the same facts `money_tips_facts.dart` already computes. |
| RLS, AI daily limit, anon-key hardening | **Removed.** There is no server, no other shop and no quota to protect. |

**Unchanged:** all screens, Riverpod, go_router, localization, local notifications, and the cart and discount maths.

The repositories keep their public method signatures, so most presentation code does not change. Scan and voice keep returning the same `RecognitionResult` and `VoiceParseResult` shapes, so the scan tray, picker and voice review sheets work as they do today.

## 3. Money correctness rules carried over

These rules are kept exactly. Each one gets a Dart test that mirrors the SQL behaviour it replaces.

- A sale writes its transaction rows and the stock decrement in **one SQLite transaction**, or nothing at all. This replaces `record_sale_cart`.
- Prices are **frozen on each transaction row**. History never re-reads the product price.
- The discount split matches `discount_math.dart`, which already mirrors the SQL.
- A retry is safe: a resent sale with the same id is ignored. This replaces the idempotency from 0010 and 0020.
- Batch and expiry stock is picked oldest-first (FIFO), including partial removal and undated stock (0011–0016).
- Every khata (credit) movement is a ledger row. The balance is a sum of ledger rows and is never stored on its own.
- Days are cut at **local** midnight, as decided in 0020.

## 4. Risks the user accepted, and their mitigations

1. **Lost, stolen, broken or reset phone means every sale and every khata record is gone.** Android backup is off (2026-10-19 review).
   - **Mitigation (recommended, needs no hosting):** Settings → **Backup** writes one file. The shopkeeper saves it wherever they choose: Google Drive, WhatsApp to themselves, or a PC. **Restore** reads the file back. A reminder can nag them if they haven't backed up in 7 days.
2. **Uninstalling the app deletes the data.** This includes reinstalling a build signed with another key. That already happened on 2026-10-31 and cost only settings, because the data was in the cloud. After this change the same mistake **deletes the shop**. Releases must always be signed with one fixed key. Today `build.gradle.kts` signs release builds with the debug key, so a real release keystore is a **prerequisite**.
3. **One phone per shop.** An owner and a helper can no longer share data.
4. **The business plan's financing and lending funnel** needs records a lender can trust, and phone-only data can be edited by the owner. The user is choosing simplicity over this for now.
5. **The existing cloud data** for the current shop is moved once (§7). After that, Supabase can be deleted.

## 5a. The app's own on-device model, "EasySell Vision" (user request, 2026-10-31)

The user said: *"I won't use Gemini — also build an internal AI model for this."*

**Why not train a model from scratch:** a model that recognizes one shop's products would need thousands of labelled photos per product, plus a GPU training server. That is hosting the user rejected. It would also have to be retrained every time the shop adds a product.

**Instead, few-shot learning on the phone:**

1. **Bundled backbone.** A small pretrained image-feature model ships inside the APK: MobileNetV3 or EfficientNet-Lite, TFLite, about 3–5 MB, Apache-2.0. It runs through `tflite_flutter`. It turns any photo into a 1024-number "fingerprint" (an embedding) in about 30–80 ms on a mid-range phone.
2. **Enrollment teaches it the shop's products.**
   - On the product form, the shopkeeper takes 2–3 photos of the item.
   - Each photo's fingerprint is stored in SQLite (`product_embeddings`), together with a thumbnail.
   - There is no training step and no server.
3. **Recognition.**
   - The scan photo becomes a fingerprint.
   - It is compared, by cosine similarity, with every enrolled fingerprint. That is a few thousand dot products, under 10 ms.
   - The closest products become the candidates.
4. **It keeps learning.** Every scan that the shopkeeper confirms or corrects is saved as a new fingerprint for the chosen product. Accuracy improves with use. The store is capped at about 20 per product, dropping the oldest first.
5. **Fusion with text.** The photo score is combined with the ML Kit text score from §5.
   - Photo similarity identifies Bangla-only packs and loose items, which ML Kit can't read.
   - Label text separates look-alike sizes (Pepsi 1L vs 500ml), which photos mix up.
6. **Not enrolled yet.** Products with no photos are still found through text alone. A "teach this product" prompt appears after a manual pick.

**Voice uses the same idea:** a correction teaches it. When the shopkeeper fixes a voice line (said "coke", picked "Coca-Cola 250ml"), the spoken words are saved as an **alias** for that product. The parser checks aliases first, so the shop's own words, nicknames and Bangla names get recognized from then on.

## 5. Scan: ML Kit text recognition plus local search

1. The camera photo goes to `google_mlkit_text_recognition`. It runs fully on-device: Latin script, a ~4 MB bundled model, under a second on a Pixel 7.
2. Normalize the recognized text:
   - Lower-case it and split it into tokens.
   - Join sizes into one form: `1 L`, `1ltr` and `1000ml` all become `1000ml`; also `500 g` and `kg`.
   - Drop marketing words ("new", "fresh", "net wt").
3. Score every active product. Each product's text is its name, brand and variant, compared against the tokens:
   - Token overlap, plus character-trigram similarity, which tolerates OCR typos such as `Pepsl`.
   - A strong bonus when the size matches, and a penalty when the size conflicts. This is how `Pepsi 1L` and `Pepsi 500ml` are told apart.
4. Turn the scores into the existing statuses:
   - `match`: one product clearly ahead.
   - `multiple`: several close, and the picker opens. It already shows the "read label" line.
   - `none`: nothing above the threshold.

   `read_brand`, `read_name` and `read_size` are filled from the OCR text.

**Known limits:**
- ML Kit has **no Bengali-script recognizer**. Packs printed only in Bangla won't read, and those fall back to the manual picker. Most packaged goods also carry Latin brand names.
- Loose items with no label (vegetables, rice) can't be recognized from text.
- Gemini could "see" a product. This design only reads its label.

These limits are why §5a exists. The on-device photo model covers both of the cases above.

## 6. Voice: on-device speech plus a Dart sale parser

1. `speech_to_text` uses Android's recognizer and prefers on-device recognition. Languages are `bn-BD` and `en-US`, following the app locale.
   - Offline Bangla needs the phone's Google speech language pack. The app checks for it and explains how to download it once.
   - This **replaces the `record` plus upload flow**. The words appear live while the shopkeeper speaks, which is better than today's wait.
2. The Dart parser splits the sentence into items ("2 pepsi and 3 chips", "দুইটা পেপসি আর তিনটা চিপস").
   - It reads quantities in digits, English number words and Bangla number words. It ports `parse-sale/quantity_words.ts`, which already has tests.
   - It reads units: kg, g, litre, piece, packet, dozen, হালি.
   - It matches each item's product words with the same fuzzy scorer as scan.
3. The review sheet is unchanged. The shopkeeper confirms or fixes each line, as today. Editing the transcript re-runs the parser locally, instantly.

**Known limit:** messy or mixed sentences parse worse than with Gemini. The review sheet catches the errors, but there will be more taps.

## 7. One-time move of the current cloud data

Before Supabase is removed, one build includes **"Move my shop to this phone"**. It signs in once, then copies the following into SQLite:
- products, categories and batches;
- transactions;
- customers and the ledger;
- settings.

It then checks row counts and totals against the server before declaring success. Supabase can be shut down once the user confirms that everything is there. The demo shop and test accounts are the user's call.

## 8. Build order

Each stage leaves a working app that can be installed and tested on the Pixel 7.

1. **Local database and data move.** This stage covers:
   - the SQLite schema;
   - Dart ports of every repository and SQL function, with tests on the money rules in §3;
   - the backup and restore file;
   - the one-time cloud move;
   - a release signing key.

   The app then runs fully offline. Scan and voice still call Gemini until stages 2 and 3.
2. **Scan on-device** (§5 and §5a):
   - EasySell Vision embeddings and photo enrollment on the product form;
   - ML Kit text, fused with the photo score;
   - learning from confirmed scans.

   The Gemini scan path is deleted.
3. **Voice on-device** (§6, plus the alias learning in §5a). The Gemini voice path and `record` are deleted.
4. **Cleanup:**
   - rule-based money tips;
   - remove `supabase_flutter`, the login screens, `dart_defines.json` and the `supabase/` functions;
   - rewrite CLAUDE.md §2–§8 for the phone-only stack;
   - update the README and the map.

## 9. Open points for the user

- Approve the backup file (§4.1) and the one-time cloud move (§7). Both are recommended.
- Should the hackathon security and AI-limit docs be marked historical? They describe a server that will no longer exist.
