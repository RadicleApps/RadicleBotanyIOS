# RadicleBotany — VENTURE-CONTEXT.md
**Provincial Khipu | Ceque Line: RadicleBotany (#6a9e5a)**
**Last Updated:** 2026-04-02
**Status:** Active — V2.0+ in progress, 108 uncommitted changes blocking deployment
**Keeper:** Chris Radicle

---

## Venture Identity

**Mission:** RadicleBotany is a native iOS botanical learning and plant identification app. Users identify plants via trait-based keying (Observe), photo ID via PlantNet API (Capture), or hybrid (Both), backed by a curated database of 2,327 species, 183 families, and 461 botanical terms. Serves gardeners, foragers, botany students, and plant enthusiasts.

**Accent color:** `#6a9e5a`
**Revenue model:** Freemium iOS — RadicleBotany annual ($33.99/yr) with 7-day trial. Single product. Botanical content + identification + spaced repetition learning locked behind subscription.
**Platform:** iOS 17+ (SwiftUI + SwiftData). Zero external packages — Apple frameworks only.

---

## App Architecture

### Current Codebase (V2.0+)
- **Models (10):** Plant, Family, BotanyTerm, PlantObservation, Achievement, UserSettings, FlashcardProgress, JournalNote, BotanizingScenario, PlantIdentificationResult
- **Services (18):** DataLoader, StoreManager, PlantNetService, PlantNetGeoService, ChatbotService, StudySessionManager, RateLimitManager, AchievementService, LocationManager, WikipediaImageService, GBIFOccurrenceService
- **Views (25+):** MainTabView (3 tabs: Journal/Botanize/Learn), Onboarding, Paywall, Search, Profile, Settings, Chatbot, Maps, Detail views, Flashcards, BotanizingListView, QuizView
- **Bundled Data:** Plants.json (5MB, 2,327 species), Families.json (183 families), Botany.json (461 terms), Botanizing.json, botany_faq.json
- **Images:** ~2,269 plant images + ~2,252 thumbnails pre-bundled
- **Fonts:** Inter (tracked) + Cormorant Garamond (staged, needs registration verification)
- **StoreKit:** `Configuration.storekit` — single annual product

### Last Committed State
- V2.0: commit `61f12e6`
- UI hitch fix: commit `0d14b76`
- **108 changes since last commit** — constitutes V2.0+ unreleased work

### V2.0+ Changes (uncommitted)
1. **Botanizing Scenarios** — New interactive learning mode (BotanizingScenario model + views + Botanizing.json)
2. **Typography overhaul** — Cormorant Garamond added alongside Inter
3. **UI polish** — Extensive changes across nearly all views
4. **Quiz system** — QuizView.swift (new, untracked)
5. **New components** — CollectionPagerView, FullscreenImageViewer updates
6. **Data updates** — Plants.json, Families.json, Botany.json enriched

---

## Current State

**Critical gap: 108 uncommitted changes.** No safety net. Entire V2.0+ feature set is unprotected.

| Component | Status |
|---|---|
| 108 file changes | Uncommitted — P1 task open |
| Botanizing Scenarios | Built but untested end-to-end |
| Font registration | Cormorant Garamond newly added — needs runtime verification |
| Quiz flow | QuizView.swift untracked/new — needs testing |
| StoreKit changes | Configuration.storekit modified — review before App Store |
| App Store V2.0 | Unclear if submitted — likely pending |

---

## Dependencies

| Dependency | Detail |
|---|---|
| PlantNet API | Photo ID (key in Config.plist, gitignored) |
| GBIF API | Species occurrence data (GBIFOccurrenceService) |
| Wikipedia API | Plant image fallback |
| App Store Connect | StoreKit product registration + submission |
| Python 3 | scripts/requirements.txt — data enrichment pipeline |

---

## Next Actions (ordered by dependency)

1. **Commit 108 changes and tag V2.0+** (P1 — do first, blocks everything)
2. **Test Botanizing Scenarios** end-to-end
3. **Verify Cormorant Garamond rendering** at runtime
4. **Test Quiz flow** (QuizView.swift)
5. **Review StoreKit changes** before App Store submission
6. **Push to GitHub** and trigger Cloudflare Pages deployment
7. **App Store submission** for V2.0+

---

## Relationship to RadicleHerbal

RadicleBotany is the sibling and template codebase for RadicleHerbal. All architectural patterns (SwiftData, DataLoader, StoreKit paywall, SpacedRepetitionEngine, three-tab nav) carry over unchanged. The two apps cross-link: `radiclebotany://plant/{botanicalName}` deep links from herb profiles in RadicleHerbal to botanical profiles here.

## System Connections

| System | Key | Notes |
|---|---|---|
| Commands | /content-ideas, /youtube-scrape, /autolearn | Content pipeline |
| Claude Project | RadicleBotany | Architecture reference (if exists) |
| GitHub | RadicleApps/RadOS or dedicated repo | Target for Swift codebase |
| Cloudflare Pages | Website deployment | Astro-based site, V2.0 rebuild pending commit |

---

*Provincial khipu written 2026-04-02. Based on CONTEXT.md (last updated 2026-03-13) + Snapshot data. Next update target: after 108-file commit and V2.0+ tag.*
