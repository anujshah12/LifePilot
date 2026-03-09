# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
xcodebuild -project LifePilot.xcodeproj -scheme LifePilot \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build

open LifePilot.xcodeproj
```

- **Deployment target:** iOS 18.0
- **Swift version:** 5.0
- **No external dependencies** — Apple frameworks only (SwiftUI, SwiftData, Charts, AVFoundation)
- **Bundle ID:** `com.anuj.LifePilot`

## Architecture

Simple SwiftUI + SwiftData habit tracker. 11 Swift files total.

### Data model

```
Habit ──1:Many(cascade)──► HabitCompletion
```

- `Habit`: name, icon (SF Symbol), colorHex, frequency (daily/weekdays/weekends/custom), customDays
- `HabitCompletion`: date (start-of-day normalized), completedAt timestamp
- Streak computation is done via computed properties on `Habit` (currentStreak, bestStreak)

### File organization

- `Models/` — `Habit.swift`, `HabitCompletion.swift`
- `Views/` — `TodayView.swift` (daily checklist), `HabitListView.swift` (CRUD), `HabitEditorSheet.swift` (add/edit), `StatsView.swift` (streaks + charts)
- `Utilities/` — `QuoteService.swift` (ZenQuotes API), `SoundManager.swift` (system sounds), `Color+Hex.swift`

### Key features

- **API**: Motivational quotes from ZenQuotes (`async/await` + `URLSession`)
- **Media playback**: System sounds on check/uncheck/all-complete (`AVFoundation`)
- **Fun feature**: Celebration overlay animation when all daily habits are completed; streak milestone badges
- **Charts**: Weekly completion bar chart using Swift Charts
