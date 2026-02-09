# CLAUDE.md - RadicleBotany iOS

## Project Overview

RadicleBotany is a native iOS botanical learning and plant identification app. Users can identify plants through trait-based keying (Observe mode), AI camera identification via PlantNet API (Capture mode), or a hybrid approach (Both mode). The app includes a curated database of 179 species, 183 families, and 464 botanical terms with full cross-referencing. A freemium model gates content behind Lifetime ($24.99) and Pro ($2.99/mo or $19.99/yr) tiers.

**Repo:** https://github.com/RadicleApps/RadicleBotanyIOS

## Tech Stack

- **Platform:** iOS 17+, SwiftUI
- **Language:** Swift
- **Architecture:** MVVM
- **Persistence:** SwiftData (6 models)
- **In-App Purchases:** StoreKit 2
- **UI Framework:** SwiftUI (UIKit bridging for camera/photo picker)
- **Networking:** URLSession with async/await
- **External API:** PlantNet v2 (`my-api.plantnet.org/v2/identify/all`)
- **Dependencies:** None — all native Apple frameworks
- **Color Scheme:** Dark mode enforced via `.preferredColorScheme(.dark)`

## Project Structure

```
RadicleBotanyIOS/
├── CLAUDE.md
├── .gitignore
├── Families.json                          # Source data (183 families)
├── RadicleBotany_Plants.json              # Source data (179 species)
├── RadicleBotany_Botany.json              # Source data (464 terms)
└── RadicleBotany/
    ├── RadicleBotanyApp.swift             # @main entry, SwiftData container, onboarding gate
    ├── Config.plist                       # API keys (gitignored)
    ├── Info.plist                         # Camera, photo library, location permissions
    ├── Assets.xcassets/
    ├── Plants.json                        # Bundle copy for DataLoader
    ├── Families.json                      # Bundle copy for DataLoader
    ├── Botany.json                        # Bundle copy for DataLoader
    ├── Models/
    │   ├── Plant.swift                    # @Model + PlantJSON Codable
    │   ├── Family.swift                   # @Model + FamilyJSON Codable
    │   ├── BotanyTerm.swift               # @Model + BotanyTermJSON Codable
    │   ├── Observation.swift              # @Model (user observations)
    │   ├── Achievement.swift              # @Model (gamification)
    │   ├── UserSettings.swift             # @Model + UserTier enum + Feature enum
    │   └── PlantIdentificationResult.swift # PlantNet API response models
    ├── Services/
    │   ├── DataLoader.swift               # JSON → SwiftData on first launch
    │   ├── StoreManager.swift             # StoreKit 2 (ObservableObject)
    │   ├── PlantNetService.swift          # PlantNet API client
    │   └── PlantIdentificationViewModel.swift
    ├── Utilities/
    │   └── DesignSystem.swift             # Colors, typography, button styles, reusable components
    └── Views/
        ├── MainTabView.swift              # 3-tab navigation (Journey/Botanize/Learn)
        ├── ContentView.swift              # Legacy (unused, kept for reference)
        ├── CameraView.swift               # UIImagePickerController wrapper
        ├── PhotoPickerView.swift          # PHPickerViewController wrapper
        ├── PlantResultView.swift          # PlantNet result card (legacy)
        ├── Onboarding/
        │   └── OnboardingView.swift       # 5-page TabView onboarding
        ├── Botanize/
        │   ├── BotanizeView.swift         # Mode selector (Observe/Capture/Both)
        │   ├── ObserveView.swift          # Trait-based keying with organ selector
        │   ├── CaptureView.swift          # Camera + PlantNet AI identification
        │   └── BothModeView.swift         # Capture + trait verification hybrid
        ├── Learn/
        │   ├── LearnView.swift            # Browse hub (categories, species, families, terms)
        │   ├── SpeciesGridView.swift      # 2-column grid, paywall gating
        │   ├── FamiliesListView.swift     # Alphabetical grouped list
        │   └── TermsListView.swift        # Grouped by category
        ├── Detail/
        │   ├── PlantDetailView.swift      # Full plant profile with trait DisclosureGroups
        │   ├── FamilyDetailView.swift     # Family profile with related species
        │   └── TermDetailView.swift       # Term definition with related species/terms
        ├── Journey/
        │   ├── JourneyView.swift          # Streak, observations, collections
        │   ├── ObservationDetailView.swift
        │   └── ObservationsListView.swift
        ├── Paywall/
        │   └── PaywallView.swift          # Lifetime + Pro tier cards
        ├── Search/
        │   └── SearchView.swift           # Cross-content search with scope filters
        ├── Profile/
        │   └── ProfileView.swift          # Stats, achievements, plan badge
        └── Settings/
            └── SettingsView.swift         # Account, preferences, data, about
```

## SwiftData Models

| Model | Key Fields | Notes |
|-------|-----------|-------|
| Plant | scientificName (unique), commonName, familyLatin, 20+ trait fields | isFree: first 30 species |
| Family | familyLatin (unique), familyEnglish, genera, 20+ trait fields | All locked for free users |
| BotanyTerm | term (unique), category, imageURL, showPlantID | isFree: first 50 terms |
| Observation | plantScientificName, photoData, lat/lng, date, verifiedTraits | User-created |
| Achievement | name, category, isUnlocked, unlockedDate | 15 seeded achievements |
| UserSettings | purchasedTier, streakCount, lastActiveDate | Singleton |

## Design System (DesignSystem.swift)

**Colors:**
- Background: `#0a0a0a` / Surface: `#141416` / Elevated: `#1c1c20`
- Text: Primary `#fafafa` / Secondary `#a0a0a8` / Muted `#666670`
- Brand: Orange `#a13d09` / Green `#999d47` / Purple `#4b479d`

**Typography:** AppFont.title(), .sectionHeader(), .body(), .caption(), .italic()
**Button Styles:** PrimaryButtonStyle, SecondaryButtonStyle, GhostButtonStyle
**Reusable:** .cardStyle() modifier, CategoryPill, LockOverlay, AtRiskBadge

## StoreKit 2 Products

| ID | Type | Price |
|----|------|-------|
| com.radicle.radiclebotany.lifetime | Non-consumable | $24.99 |
| com.radicle.radiclebotany.pro.monthly | Auto-renewable | $2.99/mo |
| com.radicle.radiclebotany.pro.yearly | Auto-renewable | $19.99/yr |

## Feature Gating

| Feature | Free | Lifetime | Pro |
|---------|------|----------|-----|
| First 30 species | ✅ | ✅ | ✅ |
| All 179 species | ❌ | ✅ | ✅ |
| All 183 families | ❌ | ✅ | ✅ |
| First 50 terms | ✅ | ✅ | ✅ |
| All 464 terms | ❌ | ✅ | ✅ |
| Observe mode (3/day) | ✅ | ✅ | ✅ |
| Unlimited Observe | ❌ | ✅ | ✅ |
| Journal & Collections | ❌ | ✅ | ✅ |
| Capture mode (AI) | ❌ | ❌ | ✅ |
| Both mode | ❌ | ❌ | ✅ |
| iCloud sync | ❌ | ❌ | ✅ |

## App Flow

1. **First Launch** → OnboardingView (5 pages) → hasCompletedOnboarding = true
2. **Main App** → MainTabView with 3 tabs:
   - **Journey** (left): Streak, observations, collections (Lifetime+ required)
   - **Botanize** (center, elevated): Observe/Capture/Both modes
   - **Learn** (right): Browse species, families, terms
3. **Header**: Profile button → ProfileView, Search bar → SearchView, Notifications
4. **Paywall**: Shown when locked content is tapped

## API Configuration

- API key stored in `Config.plist` (gitignored)
- Required key: `PLANTNET_API_KEY`
- Used by PlantNetService for Capture and Both modes

## Build & Run

1. Open project in Xcode 15+
2. Create `RadicleBotany/Config.plist` with key `PLANTNET_API_KEY` if missing
3. Ensure Plants.json, Families.json, Botany.json are in the bundle (already copied)
4. Add StoreKit Configuration file for testing purchases
5. No package dependencies to resolve
6. Target: iPhone, iOS 17+

## Conventions

- No external packages — zero dependencies
- Dark mode only (enforced at app level)
- SwiftData for all persistence (not Core Data or SwiftData)
- StoreManager is an @EnvironmentObject throughout the app
- UIKit bridging via UIViewControllerRepresentable + Coordinator pattern
- Navigation: Tab-based main, NavigationStack per tab, sheets for modals/paywall
- DataLoader runs once on first launch, version-checked
- Free content gates: first 30 plants, first 50 terms, 3 observe questions/day
