// =====================================================================
// Onboarding flow
//
// First-run experience and Terms-of-Use gate, combined into a single
// PageView-based wizard. The previous version used the
// `introduction_screen` package plus a separate `TermsGateScreen` that
// re-prompted for ToU acceptance after onboarding finished â€” meaning
// users were shown the terms twice and the layout wasted vertical space
// on oversized centered icons.
//
// This rewrite:
//   * Custom PageView with a compact bottom controls bar so body text
//     gets the screen real estate it deserves.
//   * Interactive Permissions page that actually triggers the OS
//     microphone and location prompts via `record` + `geolocator`
//     (instead of just describing the permissions in prose).
//   * Terms & Privacy page with an "I agree" checkbox; the Get Started
//     button is disabled until the box is checked. On finish we mark
//     both `onboardingComplete` and `termsAccepted` in one shot, so
//     there is no follow-up gate screen.
// =====================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';

import '../../core/theme/app_semantic_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/widgets/content_width_constraint.dart';

// ---------------------------------------------------------------------------
// Layout constants
//
// The onboarding flow follows the conventions seen in well-designed first-run
// experiences (Material 3 onboarding, iOS welcome flows, Duolingo, etc.):
//   * Content is capped at a comfortable reading width on tablets/landscape
//     so lines of body text don't stretch edge-to-edge.
//   * Generous vertical breathing room around hero icons and titles.
//   * Body text is the visual anchor, not the icon — icons are accents,
//     not the entire screen.
// ---------------------------------------------------------------------------
const double _kOnboardingMaxWidth = 520;
const double _kPageHorizontalPadding = 28;
const double _kPageTopPadding = 12;
const double _kHeroIconSize = 64;
const double _kHeroIconBoxSize = 88;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool _termsAgreed = false;
  bool _micGranted = false;
  bool _locGranted = false;
  bool _locUnavailable = false;
  bool _requestingMic = false;
  bool _requestingLoc = false;
  int _locationRequestSerial = 0;

  bool get _isDesktopPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static const int _totalPages = 5;
  static const int _termsPageIndex = 4;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissionStatus() async {
    if (_isDesktopPlatform) {
      if (!mounted) return;
      setState(() {
        _locUnavailable = true;
        _locGranted = false;
      });
      return;
    }

    final serial = ++_locationRequestSerial;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final loc = await Geolocator.checkPermission();
      if (!mounted || serial != _locationRequestSerial) return;
      setState(() {
        _locUnavailable = !serviceEnabled;
        _locGranted =
            loc == LocationPermission.whileInUse ||
            loc == LocationPermission.always;
      });
    } catch (_) {
      // Preserve previous state on plugin/OS errors to avoid UI flicker.
    }
  }

  Future<void> _requestMic() async {
    if (_requestingMic) return;
    setState(() => _requestingMic = true);
    try {
      final granted = await AudioRecorder().hasPermission();
      if (!mounted) return;
      setState(() => _micGranted = granted);
    } catch (_) {
      if (!mounted) return;
      setState(() => _micGranted = false);
    } finally {
      if (mounted) setState(() => _requestingMic = false);
    }
  }

  Future<void> _requestLocation() async {
    if (_requestingLoc) return;

    if (_isDesktopPlatform) {
      if (!mounted) return;
      setState(() {
        _locUnavailable = true;
        _locGranted = false;
      });
      return;
    }

    setState(() => _requestingLoc = true);
    final serial = ++_locationRequestSerial;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!mounted || serial != _locationRequestSerial) return;
      setState(() {
        _locUnavailable = false;
        _locGranted =
            perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always;
      });
    } catch (_) {
      // Preserve previous state on plugin/OS errors to avoid UI flicker.
    } finally {
      if (mounted) setState(() => _requestingLoc = false);
    }
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToTerms() {
    _controller.animateToPage(
      _termsPageIndex,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    await ref.read(termsAcceptedProvider.notifier).accept();
    await ref.read(onboardingCompleteProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: just the Skip action, right-aligned. Kept compact so
            // the page content gets the lion's share of vertical space.
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _page < _termsPageIndex ? 1 : 0,
                      child: TextButton(
                        onPressed:
                            _page < _termsPageIndex ? _skipToTerms : null,
                        child: Text(l10n.skip),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) {
                  setState(() => _page = i);
                  if (i == 3) _refreshPermissionStatus();
                },
                children: [
                  _WelcomePage(l10n: l10n, theme: theme),
                  _InfoPage(
                    icon: AppIcons.graphicEqRounded,
                    title: l10n.onboardingHowItWorksTitle,
                    body: l10n.onboardingHowItWorksBody,
                    theme: theme,
                  ),
                  _InfoPage(
                    icon: AppIcons.gridViewRounded,
                    title: l10n.onboardingFeaturesTitle,
                    body: l10n.onboardingFeaturesBody,
                    theme: theme,
                  ),
                  _PermissionsPage(
                    l10n: l10n,
                    theme: theme,
                    micGranted: _micGranted,
                    locGranted: _locGranted,
                    locUnavailable: _locUnavailable,
                    requestingMic: _requestingMic,
                    requestingLoc: _requestingLoc,
                    onRequestMic: _requestMic,
                    onRequestLocation: _requestLocation,
                  ),
                  _TermsPage(
                    l10n: l10n,
                    theme: theme,
                    agreed: _termsAgreed,
                    onAgreedChanged:
                        (v) => setState(() => _termsAgreed = v ?? false),
                  ),
                ],
              ),
            ),
            _ControlsBar(
              page: _page,
              total: _totalPages,
              isFinalPage: _page == _termsPageIndex,
              canFinish: _termsAgreed,
              onNext: _next,
              onFinish: _finish,
              theme: theme,
              l10n: l10n,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom controls bar
// ---------------------------------------------------------------------------

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.page,
    required this.total,
    required this.isFinalPage,
    required this.canFinish,
    required this.onNext,
    required this.onFinish,
    required this.theme,
    required this.l10n,
  });

  final int page;
  final int total;
  final bool isFinalPage;
  final bool canFinish;
  final VoidCallback onNext;
  final Future<void> Function() onFinish;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // Bottom controls live in their own ContentWidthConstraint so the
    // primary action button stays a comfortable tap-target width on tablets
    // (rather than spanning the entire screen).
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: ContentWidthConstraint(
        maxWidth: _kOnboardingMaxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < total; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          i == page
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: isFinalPage ? (canFinish ? onFinish : null) : onNext,
                child: Text(
                  isFinalPage ? l10n.getStarted : l10n.next,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page: Welcome
// ---------------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.l10n, required this.theme});

  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Welcome page is visually centered — the typical pattern for the very
    // first onboarding card. Larger app-icon hero + centered title and body,
    // wrapped in a ContentWidthConstraint so it doesn't stretch on tablets.
    return ContentWidthConstraint(
      maxWidth: _kOnboardingMaxWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _kPageHorizontalPadding,
          _kPageTopPadding,
          _kPageHorizontalPadding,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/images/app-icon.png',
                width: 112,
                height: 112,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.onboardingWelcomeTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Flexible(
              flex: 5,
              child: SingleChildScrollView(
                child: Text(
                  l10n.onboardingWelcomeBody,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(220),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page: generic info (icon + title + body)
// ---------------------------------------------------------------------------

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String body;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Generic info pages: hero icon (sized for visual weight, not just decoration),
    // big title, comfortable body text. Capped width keeps lines readable on
    // tablets and landscape.
    return ContentWidthConstraint(
      maxWidth: _kOnboardingMaxWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _kPageHorizontalPadding,
          _kPageTopPadding,
          _kPageHorizontalPadding,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              width: _kHeroIconBoxSize,
              height: _kHeroIconBoxSize,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: _kHeroIconSize * 0.6,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(220),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page: Permissions (interactive)
// ---------------------------------------------------------------------------

class _PermissionsPage extends ConsumerWidget {
  const _PermissionsPage({
    required this.l10n,
    required this.theme,
    required this.micGranted,
    required this.locGranted,
    required this.locUnavailable,
    required this.requestingMic,
    required this.requestingLoc,
    required this.onRequestMic,
    required this.onRequestLocation,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final bool micGranted;
  final bool locGranted;
  final bool locUnavailable;
  final bool requestingMic;
  final bool requestingLoc;
  final Future<void> Function() onRequestMic;
  final Future<void> Function() onRequestLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContentWidthConstraint(
      maxWidth: _kOnboardingMaxWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _kPageHorizontalPadding,
          _kPageTopPadding,
          _kPageHorizontalPadding,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              width: _kHeroIconBoxSize,
              height: _kHeroIconBoxSize,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                AppIcons.securityRounded,
                size: _kHeroIconSize * 0.6,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.onboardingPermissionsTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.onboardingPermissionsBody,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(210),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _PermissionTile(
                    icon: AppIcons.micRounded,
                    title: l10n.permissionMicrophoneTitle,
                    description: l10n.permissionMicrophoneDescription,
                    granted: micGranted,
                    unavailable: false,
                    busy: requestingMic,
                    onGrant: onRequestMic,
                    theme: theme,
                    l10n: l10n,
                  ),
                  const SizedBox(height: 14),
                  _PermissionTile(
                    icon: AppIcons.locationOnRounded,
                    title: l10n.permissionLocationTitle,
                    description: l10n.permissionLocationDescription,
                    granted: locGranted,
                    unavailable: locUnavailable,
                    busy: requestingLoc,
                    onGrant: onRequestLocation,
                    theme: theme,
                    l10n: l10n,
                  ),
                  const SizedBox(height: 14),
                  _ConsentTile(
                    icon: AppIcons.mapSheet,
                    title: l10n.settingsPrivacyAllowMap,
                    description: l10n.settingsPrivacyAllowMapSubtitle,
                    value: ref.watch(privacyAllowMapProvider),
                    onChanged:
                        (val) =>
                            ref.read(privacyAllowMapProvider.notifier).set(val),
                    theme: theme,
                  ),
                  const SizedBox(height: 14),
                  _ConsentTile(
                    icon: AppIcons.public,
                    title: l10n.settingsPrivacyAllowReverseGeocoding,
                    description:
                        l10n.settingsPrivacyAllowReverseGeocodingSubtitle,
                    value: ref.watch(privacyAllowReverseGeocodingProvider),
                    onChanged:
                        (val) => ref
                            .read(privacyAllowReverseGeocodingProvider.notifier)
                            .set(val),
                    theme: theme,
                  ),
                  const SizedBox(height: 14),
                  _ConsentTile(
                    icon: AppIcons.cloud,
                    title: l10n.settingsPrivacyAllowWeather,
                    description: l10n.settingsPrivacyAllowWeatherSubtitle,
                    value: ref.watch(privacyAllowWeatherProvider),
                    onChanged:
                        (val) => ref
                            .read(privacyAllowWeatherProvider.notifier)
                            .set(val),
                    theme: theme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.unavailable,
    required this.busy,
    required this.onGrant,
    required this.theme,
    required this.l10n,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final bool unavailable;
  final bool busy;
  final Future<void> Function() onGrant;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 22,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(170),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (unavailable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.locationOffRounded,
                  color: theme.colorScheme.outline,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.surveyLocationUnavailable,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else if (granted)
            Icon(
              AppIcons.checkCircleRounded,
              color: AppSemanticColors.of(context).success,
              size: 28,
            )
          else
            SizedBox(
              height: 36,
              child: FilledButton.tonal(
                onPressed: busy ? null : onGrant,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child:
                    busy
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(
                            Platform.isIOS
                                ? l10n.permissionRequestIOS
                                : l10n.permissionRequest,
                          ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 22,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(170),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page: Terms & Privacy (with required checkbox)
// ---------------------------------------------------------------------------

class _TermsPage extends StatelessWidget {
  const _TermsPage({
    required this.l10n,
    required this.theme,
    required this.agreed,
    required this.onAgreedChanged,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final bool agreed;
  final ValueChanged<bool?> onAgreedChanged;

  Future<void> _open(BuildContext context, String path) async {
    final localeCode = Localizations.localeOf(context).languageCode;
    final basePath = localeCode == 'en' ? '' : '/$localeCode';
    await openExternalUrl(context, '${AppConstants.docsUrl}$basePath$path');
  }

  @override
  Widget build(BuildContext context) {
    return ContentWidthConstraint(
      maxWidth: _kOnboardingMaxWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _kPageHorizontalPadding,
          _kPageTopPadding,
          _kPageHorizontalPadding,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              width: _kHeroIconBoxSize,
              height: _kHeroIconBoxSize,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                AppIcons.gavelRounded,
                size: _kHeroIconSize * 0.6,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.onboardingTermsTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  l10n.onboardingTermsBody,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(220),
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _open(context, '/terms/'),
                  icon: const Icon(AppIcons.gavelRounded, size: 18),
                  label: Text(l10n.onboardingTermsLink),
                ),
                TextButton.icon(
                  onPressed: () => _open(context, '/privacy/'),
                  icon: const Icon(AppIcons.privacyTip, size: 18),
                  label: Text(l10n.onboardingPrivacyLink),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => onAgreedChanged(!agreed),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Checkbox(value: agreed, onChanged: onAgreedChanged),
                    Expanded(
                      child: Text(
                        l10n.onboardingTermsAccept,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
