# Android Widgets

BirdNET Live includes two Android widgets for fast access from the home screen and, on supported devices, the lock screen.

## Availability

- Android only. iOS and Windows do not provide the same widget system.
- Lock screen widget placement depends on Android version, device manufacturer, and widget host.

## Widget Types

### BirdNET Live shortcut

Use this when you want one-tap entry into Live Mode.

- Opens the app directly in **Live Mode**.
- Always auto-starts recording once the model is ready.
- If onboarding or Terms acceptance is still required, the app completes that flow first, then opens Live Mode and starts recording.

This behavior is intentionally different from the regular **Auto-start recording** setting in [Settings](settings.md): the shortcut widget is always quick-start.

### BirdNET Live statistics

Use this when you want at-a-glance session summary data.

- Shows recent detections and species totals from saved sessions.
- Supports compact and expanded layouts depending on widget size.
- Expanded layout includes a settings button for:
  - timeframe: 24 hours, 7 days, or 30 days
  - background transparency
  - font size

Statistics update automatically after sessions are saved, edited, or deleted.

If the widget appears empty, complete and save at least one session first.

## Tips

- Resize the statistics widget after placing it to switch between compact and expanded layouts.
- Keep the shortcut widget near the phone dock for fast field starts.
- Use [Session Library](session-library.md) and [Session Review](session-review.md) to validate and curate detections that feed the statistics widget.
