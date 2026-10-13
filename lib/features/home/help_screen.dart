import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/utils/session_type_visuals.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../live/live_session.dart';

/// Quick reference with visible summaries and optional workflow details.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _sections = List.generate(5, (_) => GlobalKey());
  final _scrollController = ScrollController();
  final _showBackToTop = ValueNotifier(false);
  late final Future<Map<String, dynamic>> _modelNames = _loadModelNames();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateBackToTop);
  }

  void _updateBackToTop() {
    _showBackToTop.value = _scrollController.offset > 300;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _showBackToTop.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadModelNames() async {
    final raw = await rootBundle.loadString(AppConstants.modelConfigAssetPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  void _jumpTo(int section) {
    final target = _sections[section].currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final headings = [
      l10n.helpModesTitle,
      l10n.helpModelsTitle,
      l10n.helpSettingsTitle,
      l10n.helpToolsTitle,
      l10n.helpTipsTitle,
    ];

    Widget mode(
      SessionType type,
      String title,
      String summary,
      String body,
      String guide, {
      String? tip,
      bool comingSoon = false,
    }) {
      final palette = sessionTypePalette(theme, type);
      return _HelpCard(
        icon: sessionTypeIcon(type),
        accent: palette.accent,
        container: palette.container,
        title: title,
        summary: summary,
        badge: comingSoon ? l10n.comingSoon : null,
        children: [
          _HelpText(body),
          if (tip != null) ...[const SizedBox(height: 12), _FieldTip(tip)],
          _GuideLink(page: guide),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showBackToTop,
        builder: (context, visible, child) => visible
            ? FloatingActionButton.small(
                heroTag: null,
                tooltip: l10n.helpBackToTop,
                onPressed: () {
                  if (MediaQuery.disableAnimationsOf(context)) {
                    _scrollController.jumpTo(0);
                  } else {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: const Icon(AppIcons.arrowUpwardRounded),
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidthConstraint(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                _HelpText(l10n.helpIntro),
                const SizedBox(height: 16),
                _HelpSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading(
                          icon: AppIcons.menuBook,
                          title: l10n.aboutUserGuide,
                        ),
                        const SizedBox(height: 8),
                        _HelpText(l10n.helpTipGuide),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => _launchUserGuide(context),
                          icon: const Icon(AppIcons.openInNew, size: 18),
                          label: Text(l10n.aboutUserGuide),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.helpJumpTo, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < headings.length; i++)
                      ActionChip(
                        label: Text(headings[i]),
                        onPressed: () => _jumpTo(i),
                      ),
                  ],
                ),
                _Heading(key: _sections[0], title: headings[0], section: true),
                mode(
                  SessionType.live,
                  l10n.liveMode,
                  l10n.liveModeDescription,
                  l10n.helpLiveBody,
                  'live-mode/',
                ),
                mode(
                  SessionType.pointCount,
                  l10n.pointCountMode,
                  l10n.pointCountModeDescription,
                  l10n.helpPointCountBody,
                  'point-count-mode/',
                  tip: l10n.pointCountTipConsistency,
                ),
                mode(
                  SessionType.survey,
                  l10n.surveyMode,
                  l10n.helpSurveySummary,
                  l10n.helpSurveyBody,
                  'survey-mode/',
                  tip: l10n.surveyTipRepeat,
                ),
                mode(
                  SessionType.aru,
                  l10n.aruMode,
                  l10n.aruModeDescription,
                  l10n.helpAruBody,
                  'aru-mode/',
                  tip: l10n.helpTipTest,
                ),
                mode(
                  SessionType.fileUpload,
                  l10n.fileAnalysisMode,
                  l10n.fileAnalysisModeDescription,
                  l10n.helpFileAnalysisBody,
                  'file-analysis/',
                  tip: l10n.helpTipRecordingLocation,
                ),
                mode(
                  SessionType.batchAnalysis,
                  l10n.batchAnalysisMode,
                  l10n.batchAnalysisModeDescription,
                  l10n.helpBatchAnalysisBody,
                  'batch-analysis/',
                  comingSoon: true,
                ),
                _Heading(key: _sections[1], title: headings[1], section: true),
                _HelpText(l10n.helpModelsIntro),
                const SizedBox(height: 12),
                FutureBuilder<Map<String, dynamic>>(
                  future: _modelNames,
                  builder: (context, snapshot) {
                    // Explanations remain available if metadata cannot load.
                    String? name(String model) =>
                        (snapshot.data?[model]
                                as Map<String, dynamic>?)?['name']
                            as String?;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HelpCard(
                          icon: AppIcons.graphicEq,
                          title: l10n.helpAudioModelTitle,
                          summary: l10n.helpAudioModelSummary,
                          children: [
                            _HelpText(l10n.helpAudioModelBody),
                            if (name('audioModel') case final modelName?) ...[
                              const SizedBox(height: 12),
                              Text(
                                modelName,
                                style: theme.textTheme.labelMedium,
                              ),
                            ],
                          ],
                        ),
                        _HelpCard(
                          icon: AppIcons.travelExplore,
                          title: l10n.helpGeomodelTitle,
                          summary: l10n.helpGeomodelSummary,
                          children: [
                            _HelpText(l10n.helpGeomodelBody),
                            if (name('geoModel') case final modelName?) ...[
                              const SizedBox(height: 12),
                              Text(
                                modelName,
                                style: theme.textTheme.labelMedium,
                              ),
                            ],
                            const _GuideLink(page: 'explore/'),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                _Heading(key: _sections[2], title: headings[2], section: true),
                _HelpText(l10n.helpControlSettings),
                const SizedBox(height: 12),
                _HelpCard(
                  icon: AppIcons.verifiedRounded,
                  title: l10n.settingsInference,
                  summary: l10n.helpDetectionSettingsSummary,
                  children: [
                    _HelpParagraph(
                      l10n.settingsConfidenceThreshold,
                      l10n.helpTipThreshold,
                    ),
                    _HelpParagraph(
                      l10n.settingsSensitivity,
                      l10n.helpSensitivityBody,
                    ),
                    _HelpParagraph(
                      l10n.settingsWindowDuration,
                      l10n.settingsHelpWindowDuration,
                    ),
                    _HelpParagraph(
                      l10n.settingsInferenceRate,
                      l10n.settingsHelpInferenceRate,
                    ),
                    const _GuideLink(page: 'settings/'),
                  ],
                ),
                _HelpCard(
                  icon: AppIcons.myLocation,
                  title: l10n.settingsLocation,
                  summary: l10n.helpTipGeoFilter,
                  children: [
                    _HelpText(l10n.helpLocationSettingsBody),
                    const _GuideLink(page: 'settings/'),
                  ],
                ),
                _HelpCard(
                  icon: AppIcons.micRounded,
                  title: l10n.settingsAudio,
                  summary: l10n.audioSourcePickerHint,
                  children: [
                    _HelpParagraph(
                      l10n.audioSourceMicrophone,
                      l10n.settingsHelpAudioSource,
                    ),
                    _HelpParagraph(
                      l10n.settingsHighPassFilter,
                      l10n.helpHighPassBody,
                    ),
                    const _GuideLink(page: 'settings/'),
                  ],
                ),
                _HelpCard(
                  icon: AppIcons.saveRounded,
                  title: l10n.settingsRecording,
                  summary: l10n.settingsRecordingDescription,
                  children: [
                    _HelpText(l10n.settingsHelpRecordingMode),
                    const SizedBox(height: 12),
                    _HelpText(l10n.settingsHelpRecordingFormat),
                    const SizedBox(height: 12),
                    _HelpText(l10n.helpSavingBody),
                    const _GuideLink(page: 'settings/'),
                  ],
                ),
                _HelpCard(
                  icon: AppIcons.tuneRounded,
                  title: l10n.settingsGeneral,
                  summary: l10n.helpPreferencesSummary,
                  children: [
                    _HelpParagraph(
                      l10n.settingsSpectrogram,
                      l10n.helpSpectrogramBody,
                    ),
                    _HelpParagraph(l10n.settingsPrivacy, l10n.helpPrivacyBody),
                    const _GuideLink(page: 'settings/'),
                  ],
                ),
                _Heading(key: _sections[3], title: headings[3], section: true),
                _HelpCard(
                  icon: AppIcons.searchRounded,
                  title: l10n.exploreMode,
                  summary: l10n.exploreModeDescription,
                  children: [
                    _HelpText(l10n.helpExploreBody),
                    const _GuideLink(page: 'explore/'),
                  ],
                ),
                _HelpCard(
                  icon: AppIcons.libraryMusic,
                  title: l10n.sessionLibraryTitle,
                  summary: l10n.helpReviewSummary,
                  children: [
                    _HelpText(l10n.helpSessionsBody),
                    const SizedBox(height: 12),
                    _HelpText(l10n.helpTipReview),
                    const _GuideLink(page: 'session-review/'),
                  ],
                ),
                _Heading(key: _sections[4], title: headings[4], section: true),
                _HelpSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _FieldTip(
                          l10n.pointCountTipMicrophone,
                          icon: AppIcons.micRounded,
                        ),
                        _FieldTip(l10n.pointCountTipWind, icon: AppIcons.air),
                        _FieldTip(
                          l10n.pointCountTipQuiet,
                          icon: AppIcons.volumeMuteRounded,
                        ),
                        _FieldTip(
                          l10n.pointCountTipStableSurface,
                          icon: AppIcons.touchApp,
                        ),
                        _FieldTip(
                          l10n.helpTipTest,
                          icon: AppIcons.playArrowRounded,
                        ),
                        _FieldTip(
                          l10n.helpTipRecordingLocation,
                          icon: AppIcons.myLocation,
                        ),
                        _FieldTip(l10n.helpTipReview, icon: AppIcons.hearing),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    super.key,
    required this.title,
    this.icon,
    this.section = false,
  });
  final String title;
  final IconData? icon;
  final bool section;

  @override
  Widget build(BuildContext context) => Padding(
    padding: section
        ? const EdgeInsets.only(top: 28, bottom: 12)
        : EdgeInsets.zero,
    child: Semantics(
      header: true,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    ),
  );
}

class _HelpSurface extends StatelessWidget {
  const _HelpSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contrast = AppTheme.isHighContrastTheme(theme);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: contrast
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: contrast
              ? theme.colorScheme.outline
              : theme.colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.icon,
    required this.title,
    required this.summary,
    required this.children,
    this.accent,
    this.container,
    this.badge,
  });
  final IconData icon;
  final String title;
  final String summary;
  final List<Widget> children;
  final Color? accent;
  final Color? container;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contrast = AppTheme.isHighContrastTheme(theme);
    return _HelpSurface(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: contrast
                ? theme.colorScheme.surface
                : (container ?? theme.colorScheme.surfaceContainerHighest),
            borderRadius: BorderRadius.circular(10),
            border: contrast
                ? Border.all(color: theme.colorScheme.outline)
                : null,
          ),
          child: Icon(
            icon,
            size: 22,
            color: accent ?? theme.colorScheme.onSurface,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            if (badge != null) ...[
              const SizedBox(height: 4),
              Text(badge!, style: theme.textTheme.labelMedium),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _HelpText(summary),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: children,
      ),
    );
  }
}

class _HelpText extends StatelessWidget {
  const _HelpText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
  );
}

class _HelpParagraph extends StatelessWidget {
  const _HelpParagraph(this.title, this.body);
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        _HelpText(body),
      ],
    ),
  );
}

class _FieldTip extends StatelessWidget {
  const _FieldTip(this.text, {this.icon = AppIcons.lightbulbOutline});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: _HelpText(text)),
      ],
    ),
  );
}

class _GuideLink extends StatelessWidget {
  const _GuideLink({required this.page});
  final String page;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => _launchUserGuide(context, page),
      icon: const Icon(AppIcons.openInNew, size: 18),
      label: Text(AppLocalizations.of(context)!.aboutUserGuide),
    ),
  );
}

Future<void> _launchUserGuide(BuildContext context, [String page = '']) async {
  final prefix = AppConstants.docsLocalePrefix(
    Localizations.localeOf(context).languageCode,
  );
  await openExternalUrl(context, '${AppConstants.docsUrl}$prefix/user/$page');
}
