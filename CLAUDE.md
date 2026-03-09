# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build for simulator
xcodebuild -project LifePilot.xcodeproj -scheme LifePilot \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build

# Open in Xcode (then Cmd+R to run)
open LifePilot.xcodeproj
```

- **Deployment target:** iOS 18.0
- **Swift version:** 5.0
- **No external dependencies** — Apple frameworks only (SwiftUI, SwiftData, Charts, UserNotifications, AVFoundation)
- **Bundle ID:** `com.anuj.LifePilot`
- No test suite yet — use SwiftUI Previews (most views include `#Preview` blocks)

## Architecture

**MVVM with SwiftUI + SwiftData.** Single-user, on-device only, no backend.

### Data flow

`LifePilotApp` creates a shared `ModelContainer` for all SwiftData entities → `ContentView` provides a 4-tab interface (Today, Templates, History, Settings) → each tab has its own `@Observable` ViewModel that receives `ModelContext` as a parameter for CRUD operations.

### Key patterns

- **ViewModels are `@Observable` classes** (not `ObservableObject`). Views hold them as `@State private var viewModel`.
- **ModelContext is passed explicitly** to ViewModel methods (e.g., `viewModel.fetchTodayPlan(context: modelContext)`) because `@Observable` classes cannot use `@Environment`.
- **Live timers** use two patterns: `Timer.publish` via Combine (`DayViewModel`) and `Timer.scheduledTimer` (`TaskListViewModel`). Both fire every 1 second and compute elapsed time from stored `Date` timestamps.
- **Sequential task enforcement**: `DayPlan.currentTask` returns the first incomplete task. `DayViewModel.taskState(for:)` classifies tasks as `.completed`, `.current`, or `.locked`.

### Data model relationships

```
DayPlan ──1:Many(cascade)──► DayTask ──Many:1(optional)──► TaskCategory
Template ──1:Many(cascade)──► TemplateTask ──Many:1(optional)──► TaskCategory
```

- `TemplateTask.toDayTask()` converts template tasks into day tasks when loading a template
- `TaskCategory` has inverse relationships to both `DayTask` and `TemplateTask` for querying tasks by category
- Category deletion nullifies references (does not cascade to tasks)
- `TaskItem` is a typealias for `DayTask` (exists for model container registration)

### TodayView state machine

`DayViewModel.state` drives `TodayView` through 4 states:
- `.notPlanned` → no DayPlan exists for today
- `.planned` → DayPlan exists with tasks but `startedAt` is nil
- `.active` → day started, tasks being worked through sequentially
- `.completed` → all tasks done or day manually ended

### View organization

- `Views/StartMyDay/` — Today tab (main daily flow)
- `Views/Templates/` — Template CRUD and editor
- `Views/Dashboard/` — Weekly charts (Swift Charts: BarMark, SectorMark) and day detail
- `Views/TaskList/` — Reusable sequential task list with locked/active/completed row styles
- `Views/Components/` — Category manager, color picker grid, notification settings
- `Views/Components/` also includes `FocusSoundPickerSheet` (ambient sound selection UI)
- `Utilities/` — `TimeFormatter` (time display), `Color+Hex` (hex→Color), `NotificationManager` (local notifications singleton), `QuoteService` (ZenQuotes API client), `FocusSoundManager` (AVAudioEngine-based ambient sound generator)

### Networking

- `QuoteService` fetches motivational quotes from ZenQuotes API (`https://zenquotes.io/api/random`) using `async/await` + `URLSession`
- Caches daily quote to avoid redundant requests; includes fallback quote on failure

### Media Playback

- `FocusSoundManager` generates procedural ambient sounds (white noise, brown noise, gentle tone) via `AVAudioEngine`
- Task completion triggers system sound chimes (`AudioServicesPlaySystemSound`)
- Sound controls appear in the active task header during focus sessions

## Project spec

See `requirements.txt` for the full feature specification and development phases. Stretch goals (iCloud sync, widgets, Apple Watch, Siri) are not yet implemented.
