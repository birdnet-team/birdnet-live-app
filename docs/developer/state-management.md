# State Management

Riverpod state management patterns.

## Overview

BirdNET Live uses [flutter_riverpod](https://riverpod.dev/) for dependency injection and state management.

## Provider Types

| Type | Usage |
|------|-------|
| `Provider` | Read-only computed values, services |
| `StateProvider` | Simple mutable state (booleans, enums) |
| `StateNotifierProvider` | Complex state with business logic |
| `FutureProvider` | Async data (geo-scores, taxonomy lookups) |

## Settings Providers

Settings use generic `StateNotifierProvider` types backed by `SharedPreferences`:

```dart
// Example: confidence threshold (int, 0-100)
final confidenceThresholdProvider =
    StateNotifierProvider<IntSettingNotifier, int>(
  (ref) => IntSettingNotifier(PrefKeys.confidenceThreshold, 25),
);
```

Available notifier types: `IntSettingNotifier`, `DoubleSettingNotifier`, `BoolSettingNotifier`, `StringSettingNotifier`.

## Live Mode Providers

- `liveControllerProvider` — singleton `LiveController` instance
- `liveStateProvider` — current `LiveState` (idle/loading/ready/active/paused/error)
- `sessionDetectionsProvider` — live detection list for the UI
- `currentSessionProvider` — active `LiveSession` metadata
