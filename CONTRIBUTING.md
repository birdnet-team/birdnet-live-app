# Contributing to BirdNET Live

Thank you for your interest in contributing to BirdNET Live! This guide will help you get started.

## Development Setup

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.27+)
- [Android Studio](https://developer.android.com/studio) (for Android SDK & emulator)
- [Xcode](https://developer.apple.com/xcode/) (macOS only, for iOS development)

### Getting Started

```bash
# Clone the repository
git clone https://github.com/birdnet-team/birdnet-live-app.git
cd birdnet-live-app

# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run the app
flutter run
```

### Running Tests

```bash
# All tests
flutter test

# Specific feature
flutter test test/features/audio/

# With coverage
flutter test --coverage
```

## Code Style

- Follow [Effective Dart](https://dart.dev/effective-dart) guidelines
- Use `flutter analyze` to check for lint issues
- Format code with `dart format .`
- Use dartdoc comments for public APIs

### File Structure

Each feature follows this pattern:

```
lib/features/{name}/
  {name}_screen.dart         # UI
  {name}_controller.dart     # Logic (if needed)
  {name}_provider.dart       # State
  widgets/                   # Feature-specific widgets
```

## Pull Request Guidelines

1. **Branch naming**: `feature/description`, `fix/description`, `docs/description`
2. **Commit messages**: Use [Conventional Commits](https://www.conventionalcommits.org/)
   - `feat: add spectrogram color map selector`
   - `fix: resolve audio buffer overflow`
   - `docs: update API integration guide`
3. **Keep PRs focused**: One feature or fix per PR
4. **Tests**: Add tests for new functionality
5. **Documentation**: Update relevant docs for user-facing changes

## Reporting Issues

- Use GitHub Issues with the appropriate template
- Include device info, Flutter version, and steps to reproduce
- Attach logs if relevant (`flutter logs`)

## Code of Conduct

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.
