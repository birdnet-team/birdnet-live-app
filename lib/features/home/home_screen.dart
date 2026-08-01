import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';

import '../../core/theme/app_theme.dart';
import '../about/about_screen.dart';
import '../aru/aru_active_screen.dart';
import '../aru/aru_controller.dart';
import '../aru/aru_providers.dart';
import '../aru/aru_setup_screen.dart';
import '../explore/explore_screen.dart';
import '../explore/explore_providers.dart';
import '../history/session_library_screen.dart';
import '../live/live_screen.dart';
import '../live/live_providers.dart';
import '../file_analysis/file_analysis_screen.dart';
import '../live/live_session.dart';
import '../point_count/point_count_setup_screen.dart';
import '../settings/settings_screen.dart';
import '../survey/survey_setup_screen.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/session_type_visuals.dart';
import 'help_screen.dart';

// =============================================================================
// Home Screen — Main Menu
// =============================================================================
//
// Clean, full-screen landing with:
//   • App logo + title
//   • 4 mode cards in a 2×2 grid
//   • Settings & About in the footer
//
// Only "Live" mode is active; the other three show a "Coming Soon" badge.
// Tapping Live pushes a full-screen [LiveScreen] for maximum real estate.
// =============================================================================

/// The app logo, decoded to the largest size it is ever drawn at (160 logical
/// px on a tablet, ×3 for common high-density screens) instead of its full
/// 891×891 source, reducing decode work and the image-cache footprint.
///
/// Shared by the header and by the warm-up's precache so both resolve to the
/// same image-cache entry; `ResizeImage` is part of the cache key, so a plain
/// `AssetImage` here would miss.
const ImageProvider _appLogoImage = ResizeImage(
  AssetImage('assets/images/app-icon.png'),
  width: 480,
  height: 480,
);

/// Main menu screen — entry point after onboarding.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_warmUpApp());
    });
  }

  Future<void> _warmUpApp() async {
    // Let the logo finish decoding before any of this starts. The first frame
    // paints without it — an asset image is never ready that early — and its
    // decode finishes on a *later* main-isolate turn, so a warm-up that grabs
    // the isolate first leaves the header visibly logo-less for as long as it
    // holds on. Nothing below is on the critical path for what the user sees.
    await _precacheLogo();
    if (!mounted) return;

    // Riverpod caches these results, so opening Live Mode (or another feature)
    // reuses work that has already completed instead of redoing it — and
    // nothing here is awaited, so the menu stays interactive throughout.
    //
    // loadModel() decides for itself whether there is anything to do: it joins
    // a load already in flight, no-ops once the model is ready or a session is
    // running, and retries after a failure. The menu does not second-guess it.
    unawaited(ref.read(liveControllerProvider).loadModel());

    _preload(ref.read(taxonomyServiceProvider.future), 'taxonomy');
    _preload(ref.read(audioLabelsSetProvider.future), 'audio labels');
    _preload(ref.read(geoModelProvider.future), 'geo model');
    unawaited(_warmUpLocation());
  }

  /// Decode the logo into the image cache, so the header can paint it on the
  /// next frame.
  ///
  /// Bounded, and failures are swallowed: this gates every other warm-up, and
  /// a logo that never resolves must not be able to leave the model unloaded.
  Future<void> _precacheLogo() async {
    try {
      await precacheImage(
        _appLogoImage,
        context,
      ).timeout(const Duration(seconds: 2));
    } catch (error) {
      debugPrint('[HomeScreen] logo precache failed: $error');
    }
  }

  /// Warm the location up only when doing so is free.
  ///
  /// With GPS off the provider just echoes the manual coordinates.  With GPS
  /// on it calls through to `getCurrentLocation()`, which *requests* the
  /// permission if it has not been granted yet — so without this guard a user
  /// who skipped the location step during onboarding would be met by the OS
  /// location prompt on the main menu, out of any context that explains it.
  /// Leave that first request to the screen that actually needs a fix.
  Future<void> _warmUpLocation() async {
    if (ref.read(useGpsProvider)) {
      final granted = await ref.read(locationServiceProvider).hasPermission();
      if (!granted || !mounted) return;
    }
    _preload(ref.read(currentLocationProvider.future), 'location');
  }

  /// Let a warm-up run to completion in the background, logging rather than
  /// surfacing failures — a warm-up is an optimisation, and the screen that
  /// really needs the value will report the error itself.
  void _preload<T>(Future<T> future, String label) {
    unawaited(() async {
      try {
        await future;
      } catch (error) {
        debugPrint('[HomeScreen] $label warm-up failed: $error');
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortestSide >= 600;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal:
                    isLandscape ? (isTablet ? 64 : 48) : (isTablet ? 40 : 24),
                vertical: isLandscape ? 12 : 0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child:
                      isLandscape
                          ? _LandscapeHomeLayout(
                            l10n: l10n,
                            theme: theme,
                            isTablet: isTablet,
                          )
                          : _PortraitHomeLayout(
                            l10n: l10n,
                            theme: theme,
                            isTablet: isTablet,
                          ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Portrait Layout — Original vertical arrangement
// ─────────────────────────────────────────────────────────────────────────────

class _PortraitHomeLayout extends ConsumerWidget {
  const _PortraitHomeLayout({
    required this.l10n,
    required this.theme,
    this.isTablet = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const SizedBox(height: 32),
        _LogoHeader(l10n: l10n, theme: theme, isTablet: isTablet),
        const SizedBox(height: 24),
        _ModeCarousel(l10n: l10n, theme: theme, isTablet: isTablet),
        const SizedBox(height: 12),
        _Footer(l10n: l10n, theme: theme, isTablet: isTablet),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Landscape Layout — Logo + title left, grid + footer right
// ─────────────────────────────────────────────────────────────────────────────

class _LandscapeHomeLayout extends ConsumerWidget {
  const _LandscapeHomeLayout({
    required this.l10n,
    required this.theme,
    this.isTablet = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: isTablet ? 14 : 8),
        // ── Compact single-row logo + title header, pinned left ──
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
            child: _LogoHeader(
              l10n: l10n,
              theme: theme,
              compact: true,
              isTablet: isTablet,
            ),
          ),
        ),
        SizedBox(height: isTablet ? 28 : 20),
        // ── Right: mode grid + footer ─────────────────────────
        _LandscapeModeGrid(l10n: l10n, theme: theme, isTablet: isTablet),
        SizedBox(height: isTablet ? 32 : 22),
        SizedBox(
          width: double.infinity,
          child: _Footer(l10n: l10n, theme: theme, isTablet: isTablet),
        ),
        SizedBox(height: isTablet ? 16 : 10),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo Header
// ─────────────────────────────────────────────────────────────────────────────

class _LogoHeader extends ConsumerWidget {
  const _LogoHeader({
    required this.l10n,
    required this.theme,
    this.compact = false,
    this.isTablet = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool compact;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highContrast = AppTheme.isHighContrastTheme(theme);
    final logoSize =
        compact ? (isTablet ? 72.0 : 56.0) : (isTablet ? 160.0 : 120.0);
    final logo = Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (highContrast
                    ? AppTheme.brandPrimaryLight
                    : theme.colorScheme.primary)
                .withAlpha(60),
            blurRadius: compact ? 16 : 32,
            spreadRadius: compact ? 2 : 4,
          ),
        ],
      ),
      child: ClipOval(
        child: Image(
          image: _appLogoImage,
          width: logoSize,
          height: logoSize,
          fit: BoxFit.cover,
        ),
      ),
    );
    final title = Text(
      l10n.appTitle,
      style: (compact
              ? theme.textTheme.headlineSmall
              : theme.textTheme.headlineMedium)
          ?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            fontSize: compact ? (isTablet ? 22 : 20) : (isTablet ? 32 : null),
          ),
      textAlign: compact ? TextAlign.left : TextAlign.center,
    );
    final subtitle = Text(
      l10n.homeSubtitle,
      style: theme.textTheme.bodyMedium?.copyWith(
        color:
            highContrast
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withAlpha(153),
        fontSize: isTablet ? 16 : null,
      ),
      textAlign: compact ? TextAlign.left : TextAlign.center,
    );
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          logo,
          SizedBox(width: isTablet ? 18 : 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 520 : 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 4), subtitle],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        logo,
        SizedBox(height: isTablet ? 28 : 20),
        title,
        const SizedBox(height: 6),
        subtitle,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode Carousel — 2 pages of 2×2 cards with indicators
// ─────────────────────────────────────────────────────────────────────────────

class _ModeCarousel extends ConsumerStatefulWidget {
  const _ModeCarousel({
    required this.l10n,
    required this.theme,
    this.isTablet = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isTablet;

  @override
  ConsumerState<_ModeCarousel> createState() => _ModeCarouselState();
}

class _ModeCarouselState extends ConsumerState<_ModeCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double maxWidth = widget.isTablet ? 550 : 400;
    final double aspectRatio = widget.isTablet ? 1.2 : 1.0;
    final double spacing = widget.isTablet ? 12 : 10;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gridWidth = constraints.maxWidth.clamp(0.0, maxWidth);
          final pageOuterSpacing = spacing / 2;
          final pageWidth =
              gridWidth > spacing ? gridWidth - spacing : gridWidth;
          final cellWidth = (pageWidth - spacing) / 2;
          final cellHeight = cellWidth / aspectRatio;
          final gridHeight = cellHeight * 2 + spacing;
          final pageMargin = EdgeInsets.symmetric(horizontal: pageOuterSpacing);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: gridHeight,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    // Page 1 — Live recording modes
                    Padding(
                      padding: pageMargin,
                      child: GridView.count(
                        padding: EdgeInsets.zero,
                        crossAxisCount: 2,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: aspectRatio,
                        children: [
                          _ModeCard(
                            icon: sessionTypeIcon(SessionType.live),
                            label: widget.l10n.liveMode,
                            description: widget.l10n.liveModeDescription,
                            accentColor: sessionTypeAccentColor(
                              widget.theme,
                              SessionType.live,
                            ),
                            isTablet: widget.isTablet,
                            onTap: () => _openLive(context),
                          ),
                          _ModeCard(
                            icon: sessionTypeIcon(SessionType.pointCount),
                            label: widget.l10n.pointCountMode,
                            description: widget.l10n.pointCountModeDescription,
                            accentColor: sessionTypeAccentColor(
                              widget.theme,
                              SessionType.pointCount,
                            ),
                            isTablet: widget.isTablet,
                            onTap: () => _openPointCount(context),
                          ),
                          _ModeCard(
                            icon: sessionTypeIcon(SessionType.survey),
                            label: widget.l10n.surveyMode,
                            description: widget.l10n.surveyModeDescription,
                            accentColor: sessionTypeAccentColor(
                              widget.theme,
                              SessionType.survey,
                            ),
                            isTablet: widget.isTablet,
                            onTap: () => _openSurvey(context),
                          ),
                          _ModeCard(
                            icon: sessionTypeIcon(SessionType.aru),
                            label: widget.l10n.aruMode,
                            description: widget.l10n.aruModeDescription,
                            accentColor: sessionTypeAccentColor(
                              widget.theme,
                              SessionType.aru,
                            ),
                            isTablet: widget.isTablet,
                            onTap: () => _openAru(context, ref),
                          ),
                        ],
                      ),
                    ),
                    // Page 2 — File workflows
                    Padding(
                      padding: pageMargin,
                      child: GridView.count(
                        padding: EdgeInsets.zero,
                        crossAxisCount: 2,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: aspectRatio,
                        children: [
                          _ModeCard(
                            icon: sessionTypeIcon(SessionType.fileUpload),
                            label: widget.l10n.fileAnalysisMode,
                            description:
                                widget.l10n.fileAnalysisModeDescription,
                            accentColor: sessionTypeAccentColor(
                              widget.theme,
                              SessionType.fileUpload,
                            ),
                            isTablet: widget.isTablet,
                            onTap: () => _openFileAnalysis(context),
                          ),
                          _ModeCard(
                            icon: sessionTypeIcon(SessionType.batchAnalysis),
                            label: widget.l10n.batchAnalysisMode,
                            description:
                                widget.l10n.batchAnalysisModeDescription,
                            accentColor: sessionTypeAccentColor(
                              widget.theme,
                              SessionType.batchAnalysis,
                            ),
                            isTablet: widget.isTablet,
                            comingSoon: true,
                            onTap:
                                () => _showComingSoonSnackBar(
                                  context,
                                  widget.l10n.batchAnalysisMode,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Page Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (index) {
                  final isSelected = _currentPage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: isSelected ? 18 : 8,
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? widget.theme.colorScheme.primary
                              : widget.theme.colorScheme.onSurface.withAlpha(
                                50,
                              ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openLive(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LiveScreen()));
  }

  void _openPointCount(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PointCountSetupScreen()),
    );
  }

  void _openSurvey(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SurveySetupScreen()));
  }

  void _openFileAnalysis(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FileAnalysisScreen()));
  }

  void _openAru(BuildContext context, WidgetRef ref) {
    final session = ref.read(aruSessionProvider);
    final state = ref.read(aruStateProvider);
    if (session != null &&
        state != AruControllerState.completed &&
        state != AruControllerState.idle) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AruActiveScreen()));
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AruSetupScreen()));
    }
  }

  void _showComingSoonSnackBar(BuildContext context, String modeLabel) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$modeLabel: ${widget.l10n.comingSoon}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual mode card
// ─────────────────────────────────────────────────────────────────────────────

class _LandscapeModeGrid extends ConsumerWidget {
  const _LandscapeModeGrid({
    required this.l10n,
    required this.theme,
    this.isTablet = false,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = isTablet ? 12.0 : 8.0;
    final maxWidth = isTablet ? 980.0 : 760.0;
    final aspectRatio = isTablet ? 2.05 : 2.15;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GridView.count(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        crossAxisCount: 3,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: aspectRatio,
        children: [
          _ModeCard(
            icon: sessionTypeIcon(SessionType.live),
            label: l10n.liveMode,
            description: l10n.liveModeDescription,
            accentColor: sessionTypeAccentColor(theme, SessionType.live),
            isTablet: isTablet,
            compact: true,
            onTap: () => _openLive(context),
          ),
          _ModeCard(
            icon: sessionTypeIcon(SessionType.pointCount),
            label: l10n.pointCountMode,
            description: l10n.pointCountModeDescription,
            accentColor: sessionTypeAccentColor(theme, SessionType.pointCount),
            isTablet: isTablet,
            compact: true,
            onTap: () => _openPointCount(context),
          ),
          _ModeCard(
            icon: sessionTypeIcon(SessionType.survey),
            label: l10n.surveyMode,
            description: l10n.surveyModeDescription,
            accentColor: sessionTypeAccentColor(theme, SessionType.survey),
            isTablet: isTablet,
            compact: true,
            onTap: () => _openSurvey(context),
          ),
          _ModeCard(
            icon: sessionTypeIcon(SessionType.aru),
            label: l10n.aruMode,
            description: l10n.aruModeDescription,
            accentColor: sessionTypeAccentColor(theme, SessionType.aru),
            isTablet: isTablet,
            compact: true,
            onTap: () => _openAru(context, ref),
          ),
          _ModeCard(
            icon: sessionTypeIcon(SessionType.fileUpload),
            label: l10n.fileAnalysisMode,
            description: l10n.fileAnalysisModeDescription,
            accentColor: sessionTypeAccentColor(theme, SessionType.fileUpload),
            isTablet: isTablet,
            compact: true,
            onTap: () => _openFileAnalysis(context),
          ),
          _ModeCard(
            icon: sessionTypeIcon(SessionType.batchAnalysis),
            label: l10n.batchAnalysisMode,
            description: l10n.batchAnalysisModeDescription,
            accentColor: sessionTypeAccentColor(
              theme,
              SessionType.batchAnalysis,
            ),
            isTablet: isTablet,
            compact: true,
            comingSoon: true,
            onTap:
                () => _showComingSoonSnackBar(context, l10n.batchAnalysisMode),
          ),
        ],
      ),
    );
  }

  void _openLive(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LiveScreen()));
  }

  void _openPointCount(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PointCountSetupScreen()),
    );
  }

  void _openSurvey(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SurveySetupScreen()));
  }

  void _openFileAnalysis(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FileAnalysisScreen()));
  }

  void _openAru(BuildContext context, WidgetRef ref) {
    final session = ref.read(aruSessionProvider);
    final state = ref.read(aruStateProvider);
    if (session != null &&
        state != AruControllerState.completed &&
        state != AruControllerState.idle) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AruActiveScreen()));
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AruSetupScreen()));
    }
  }

  void _showComingSoonSnackBar(BuildContext context, String modeLabel) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$modeLabel: ${l10n.comingSoon}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.accentColor,
    this.isTablet = false,
    this.compact = false,
    this.comingSoon = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color accentColor;
  final bool isTablet;
  final bool compact;
  final bool comingSoon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isBrandTheme = isBrandThemeColorScheme(theme.colorScheme);
    final highContrast = AppTheme.isHighContrastTheme(theme);
    final cardColor =
        isBrandTheme
            ? (theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest.withAlpha(120)
                : theme.colorScheme.surfaceContainerHighest.withAlpha(180))
            : (theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surfaceContainerHigh);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
      side:
          isBrandTheme
              ? BorderSide.none
              : BorderSide(
                color: theme.colorScheme.outlineVariant.withAlpha(140),
              ),
    );

    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: cardColor,
      elevation: isBrandTheme ? 0 : 1,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? (isTablet ? 16 : 12) : (isTablet ? 20 : 14),
            vertical: compact ? (isTablet ? 12 : 10) : (isTablet ? 18 : 12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon & "Coming Soon" badge row.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width:
                        compact ? (isTablet ? 42 : 34) : (isTablet ? 52 : 44),
                    height:
                        compact ? (isTablet ? 42 : 34) : (isTablet ? 52 : 44),
                    decoration: BoxDecoration(
                      color:
                          isBrandTheme
                              ? accentColor.withAlpha(isDark ? 50 : 30)
                              : accentColor.withAlpha(36),
                      borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                    ),
                    child: Icon(
                      icon,
                      color: accentColor,
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  if (comingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(compact ? 10 : 12),
                      ),
                      child: Text(
                        l10n.comingSoon,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 11 : 9,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: compact ? (isTablet ? 10 : 8) : (isTablet ? 18 : 12),
              ),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      highContrast
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withAlpha(
                            comingSoon ? 150 : 255,
                          ),
                  fontSize:
                      compact ? (isTablet ? 13 : 12) : (isTablet ? 14 : null),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        highContrast
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withAlpha(
                              comingSoon ? 80 : 100,
                            ),
                    fontSize:
                        compact ? (isTablet ? 11 : 10) : (isTablet ? 12 : 11),
                  ),
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer — 5 items that wrap naturally
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({
    required this.l10n,
    required this.theme,
    this.isTablet = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final highContrast = AppTheme.isHighContrastTheme(theme);
    final color =
        highContrast
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurface.withAlpha(153);
    final fontSize = isTablet ? 16.0 : 14.0;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: isTablet ? 12 : 6,
      runSpacing: isTablet ? 6 : 4,
      children: [
        // Sessions first — it's the more frequently used destination
        // (every recording produces one) so it deserves the leftmost
        // slot. Settings sits near the end where infrequent prefs
        // belong (#33).
        _FooterButton(
          icon: AppIcons.libraryMusic,
          label: l10n.sessionLibraryTitle,
          color: color,
          fontSize: fontSize,
          isTablet: isTablet,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SessionLibraryScreen(),
                ),
              ),
        ),
        _FooterButton(
          icon: AppIcons.searchRounded,
          label: l10n.exploreMode,
          color: color,
          fontSize: fontSize,
          isTablet: isTablet,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ExploreScreen()),
              ),
        ),
        _FooterButton(
          icon: AppIcons.tuneRounded,
          label: l10n.settings,
          color: color,
          fontSize: fontSize,
          isTablet: isTablet,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
        ),
        _FooterButton(
          icon: AppIcons.helpOutlineRounded,
          label: l10n.helpTitle,
          color: color,
          fontSize: fontSize,
          isTablet: isTablet,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
              ),
        ),
        _FooterButton(
          icon: AppIcons.infoOutline,
          label: l10n.about,
          color: color,
          fontSize: fontSize,
          isTablet: isTablet,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
        ),
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.fontSize,
    this.isTablet = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final double fontSize;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isTablet ? 24 : 20, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: fontSize)),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 12 : 8,
          vertical: isTablet ? 10 : 8,
        ),
        minimumSize: Size(isTablet ? 76 : 64, isTablet ? 48 : 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      ),
    );
  }
}
