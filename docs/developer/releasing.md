# Releasing

Release process and distribution.

## Version

Version is set in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

## Checklist

1. Update `CHANGELOG.md` with release notes.
2. Bump version in `pubspec.yaml`.
3. Run `flutter analyze` — must be zero warnings.
4. Run `flutter test` — all tests must pass.
5. Build release artifacts:
    - Android: `flutter build appbundle --release`
    - iOS: `flutter build ios --release` + archive in Xcode
6. Tag the release: `git tag v1.0.0`
7. Push tag: `git push origin v1.0.0`
