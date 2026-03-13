# RadicleBotany — Context File

**Last Updated:** 2026-03-13
**Location:** /Users/air/Desktop/RadOS/RadicleBotany
**Venture:** RadicleBotany
**Status:** Active / In Progress

---

## What This Is

Native iOS botanical learning and plant identification app built with SwiftUI and SwiftData. Users identify plants via trait-based keying (Observe), photo ID via PlantNet API (Capture), or a hybrid (Both), backed by a curated database of 2,327 species, 183 families, and 461 botanical terms.

## Current State

The app is post-V2.0 with a massive uncommitted working tree (~108 changed/new files). Core app is functional with:

- **Models (10):** Plant, Family, BotanyTerm, PlantObservation, Achievement, UserSettings, FlashcardProgress, JournalNote, BotanizingScenario (new), PlantIdentificationResult
- **Services (18):** DataLoader, StoreManager, PlantNetService, PlantNetGeoService, ChatbotService, StudySessionManager, RateLimitManager, AchievementService, LocationManager, WikipediaImageService, GBIFOccurrenceService, and more
- **Views (25+ files):** MainTabView (3 tabs: Journal/Botanize/Learn), Onboarding, Paywall, Search, Profile, Settings, Chatbot, Maps, Detail views, Flashcards, and new Botanizing scenarios
- **Utilities (6):** DesignSystem, ThemeManager, FontRegistration, CachedPlantImage, ThrottledImageLoader (new), KeychainManager
- **Bundled Data:** Plants.json (5MB), Families.json, Botany.json, Botanizing.json (new), botany_faq.json, Resources.json
- **Pre-baked Images:** ~2,269 plant images + ~2,252 thumbnails bundled in PlantImages/ and PlantThumbnails/
- **Fonts:** Inter (already tracked) + Cormorant Garamond (newly added, staged)
- **Scripts (Python):** Data enrichment, image downloading, species expansion, thumbnail generation in scripts/
- **StoreKit:** Single product — RadicleBotany annual ($33.99/yr) with 7-day trial
- **Config.plist:** Contains PLANTNET_API_KEY (gitignored)

## What Was Being Worked On

The last committed work was **V2.0** (commit `61f12e6`), followed by a fix for UI hitching (`0d14b76`). The large uncommitted diff represents ongoing V2.0+ work including:

1. **Botanizing Scenarios** — New interactive learning mode with BotanizingScenario model, Botanizing.json data, BotanizingListView, and BotanizingScenarioView
2. **Typography Overhaul** — Adding Cormorant Garamond font family alongside Inter, with FontRegistration and ThemeManager updates
3. **UI Polish** — Extensive changes across nearly all views (design system, toolbar, flashcards, maps, detail views, paywall, onboarding, chatbot)
4. **Quiz System** — New QuizView.swift
5. **New Components** — CollectionPagerView, FullscreenImageViewer updates
6. **Data Updates** — Updated Plants.json, Families.json, Botany.json with enriched content
7. **StoreKit Config** — Updated Configuration.storekit

## Next Actions

1. **Commit the working tree** — 108 uncommitted changes need to be reviewed, staged, and committed (likely in logical groups)
2. **Test Botanizing feature** — New BotanizingScenario model + views need end-to-end testing
3. **Verify font registration** — Cormorant Garamond fonts are newly added; confirm they render correctly at runtime
4. **Test Quiz flow** — QuizView.swift is untracked/new
5. **Review StoreKit changes** — Configuration.storekit was modified
6. **Push to GitHub** — Remote is set but local is ahead with uncommitted work
7. **App Store submission prep** — Unclear if V2.0 has been submitted; likely pending

## Dependencies

- **PlantNet API** — Photo identification (key in Config.plist, gitignored)
- **Xcode 15+** — Build tool, iOS 17+ target
- **Apple Frameworks Only** — Zero external packages (SwiftUI, SwiftData, StoreKit 2, MapKit, CoreLocation, PhotosUI, AVFoundation)
- **Python 3** — Scripts for data enrichment (scripts/requirements.txt)
- **App Store Connect** — For StoreKit product registration and submission
- **GBIF API** — Species occurrence data (GBIFOccurrenceService)
- **Wikipedia API** — Plant image fallback (WikipediaImageService)

## GitHub

**Git connected:** Yes
**Remote:** https://github.com/RadicleApps/RadicleBotanyIOS (origin)
**Branch:** master
**Last pushed commit:** `0d14b76` (Fix UI hitching: move background tasks off main modelContext)
**Local state:** 108 uncommitted changes ahead of last commit

## Notes

- The working tree is very large — committing in logical chunks is recommended before any new feature work.
- PlantImages/ and PlantThumbnails/ (~4,500 files total) are untracked and not gitignored. These are pre-baked bundle assets. Consider whether they should be tracked in git or managed via Git LFS given their size.
- Several `.bak` files exist (Botany.json.bak, Plants.json.bak) — these are gitignored but still on disk.
- The CLAUDE.md project structure diagram is slightly out of date relative to the actual file tree (missing newer services, models, and views).
- Config.plist is properly gitignored — API keys are not in the repo.
- There appear to be some backend/intelligence services (IntelligenceBackendService, OwnerBackendConfig, ContextualGuidanceService, NotionService) that are not documented in CLAUDE.md — unclear if these are active or experimental.
