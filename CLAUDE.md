# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
xcodebuild -project LifePilot.xcodeproj -scheme LifePilot \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build

# Run tests
xcodebuild -project LifePilot.xcodeproj -scheme LifePilot \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test

open LifePilot.xcodeproj
```

- **Deployment target:** iOS 18.0
- **Swift version:** 5.0
- **No external dependencies** — Apple frameworks only (SwiftUI, SwiftData, Charts, AVFoundation)
- **Bundle ID:** `com.anuj.LifePilot`

## Architecture

MVVM SwiftUI + SwiftData habit tracker. Follows Apple's recommended MV-style architecture where ViewModels live inside the Model layer.

### Data model

```
Habit ──1:Many(cascade)──► HabitCompletion
```

- `Habit`: name, icon (SF Symbol), colorHex, frequency (daily/weekdays/weekends/custom), customDays
  - All mutating logic (streak computation, scheduling, completion checks) lives on the Model
- `HabitCompletion`: date (start-of-day normalized), completedAt timestamp

### MVVM separation of concerns

- **Models** own data and business logic (streak computation, scheduling, completion checks)
- **ViewModels** act as gatekeepers — they mediate between Views and Models, handle UI state, and perform mutations through the model context
- **Views** are purely declarative SwiftUI — they observe ViewModels and render UI
- **Services** encapsulate networking (QuoteService) and media playback (SoundManager)

### File organization

```
LifePilot/
├── LifePilotApp.swift              # App entry point
├── ContentView.swift               # Tab container
├── Models/
│   ├── Habit.swift                 # @Model — data + business logic
│   ├── HabitCompletion.swift       # @Model — completion records
│   ├── ViewModels/
│   │   ├── TodayViewModel.swift    # Toggle logic, celebration state, filtering
│   │   ├── HabitListViewModel.swift# CRUD operations, sheet state
│   │   └── StatsViewModel.swift    # Stats computation, chart data
│   └── Services/
│       ├── QuoteService.swift      # ZenQuotes API networking
│       └── SoundManager.swift      # AVFoundation system sounds
├── Views/
│   ├── TodayView.swift             # Daily checklist (delegates to TodayViewModel)
│   ├── HabitListView.swift         # Habit management (delegates to HabitListViewModel)
│   ├── HabitEditorSheet.swift      # Add/edit form
│   └── StatsView.swift             # Streaks + charts (delegates to StatsViewModel)
└── Extensions/
    └── Color+Hex.swift             # Hex color parsing
```

### Key features

- **API**: Motivational quotes from ZenQuotes (`async/await` + `URLSession`) — contained in `QuoteService`
- **Media playback**: System sounds on check/uncheck/all-complete — contained in `SoundManager`
- **Fun feature**: Celebration overlay animation when all daily habits are completed; streak milestone badges
- **Charts**: Weekly completion bar chart using Swift Charts
- **Tests**: Swift Testing suite covering streak computation, scheduling logic, and ViewModel behavior
