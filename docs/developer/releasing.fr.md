<!-- TRANSLATION TODO (fr) -->

# Releasing

Release process and distribution.

## Version

Version is set in `pubspec.yaml`:

```yaml
version: 0.15.3+161
```

## Checklist

1. Update `CHANGELOG.md` with release notes.
2. Bump version in `pubspec.yaml` and run `dart dev/sync_version.dart`.
3. Confirm Git LFS model files with `git lfs pull` on fresh checkouts.
4. Run `flutter analyze` — must be zero warnings.
5. Run `flutter test` — all tests must pass.
6. Build release artifacts:
    - Android: `flutter build appbundle --release`
    - iOS: `flutter build ios --release` + archive in Xcode
7. Tag the release: `git tag v0.15.2`
8. Push tag: `git push origin v0.15.2`
