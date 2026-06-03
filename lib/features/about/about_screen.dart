import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/widgets/content_width_constraint.dart';

/// Provider for app package info.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// About screen with version info, credits, and legal links.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final packageInfo = ref.watch(packageInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ContentWidthConstraint(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // App icon and title
            Center(
              child: Column(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/app-icon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  packageInfo.when(
                    data:
                        (info) => Text(
                          l10n.aboutVersionLabel(
                            info.version,
                            info.buildNumber,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                    loading: () => const SizedBox.shrink(),
                    error: (a, b) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Combined model info — audio model + geo-model in one card.
            // Shows the model display name for each plus the shared species
            // count once at the bottom (both ship with the same 5,250-species
            // intersection, so repeating it on two cards was redundant).
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aboutModelVersion,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.aboutModelName),
                    const SizedBox(height: 12),
                    Text(
                      l10n.aboutGeoModel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.aboutGeoModelName),
                    const SizedBox(height: 12),
                    Text(
                      l10n.aboutSpeciesCount(AppConstants.speciesCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Credits
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aboutCredits,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.aboutCreditsDescription),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Funding
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aboutFunding,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.aboutFundingDescription),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Links
            ListTile(
              leading: const Icon(AppIcons.menuBook),
              title: Text(l10n.aboutUserGuide),
              trailing: const Icon(AppIcons.openInNew),
              onTap:
                  () => openExternalUrl(
                    context,
                    '${AppConstants.docsUrl}${Localizations.localeOf(context).languageCode == 'en' ? '' : '/${Localizations.localeOf(context).languageCode}'}/user/',
                  ),
            ),
            ListTile(
              leading: const Icon(AppIcons.privacyTip),
              title: Text(l10n.aboutPrivacyPolicy),
              trailing: const Icon(AppIcons.openInNew),
              onTap:
                  () => openExternalUrl(
                    context,
                    '${AppConstants.docsUrl}${Localizations.localeOf(context).languageCode == 'en' ? '' : '/${Localizations.localeOf(context).languageCode}'}/privacy/',
                  ),
            ),
            ListTile(
              leading: const Icon(AppIcons.gavel),
              title: Text(l10n.aboutTermsOfUse),
              trailing: const Icon(AppIcons.openInNew),
              onTap:
                  () => openExternalUrl(
                    context,
                    '${AppConstants.docsUrl}${Localizations.localeOf(context).languageCode == 'en' ? '' : '/${Localizations.localeOf(context).languageCode}'}/terms/',
                  ),
            ),
            ListTile(
              leading: const Icon(AppIcons.code),
              title: Text(l10n.aboutGitHub),
              trailing: const Icon(AppIcons.openInNew),
              onTap: () => openExternalUrl(context, AppConstants.githubUrl),
            ),
            ListTile(
              leading: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  theme.colorScheme.onSurfaceVariant,
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/images/icon-birdnet.png',
                  width: 24,
                  height: 24,
                ),
              ),
              title: Text(l10n.aboutWebsite),
              trailing: const Icon(AppIcons.openInNew),
              onTap: () => openExternalUrl(context, AppConstants.birdnetUrl),
            ),
            ListTile(
              leading: const Icon(AppIcons.volunteerActivism),
              title: Text(l10n.aboutDonate),
              trailing: const Icon(AppIcons.openInNew),
              onTap:
                  () => openExternalUrl(context, AppConstants.birdnetDonateUrl),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
