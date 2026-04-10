import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../shared/providers/app_providers.dart';

/// Gate screen that requires Terms of Use and Privacy Policy acceptance.
///
/// Blocks access to the main app until the user accepts.
class TermsGateScreen extends ConsumerWidget {
  const TermsGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Icon
              Icon(
                Icons.gavel_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                l10n.termsOfUseTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Terms content
              Expanded(
                flex: 3,
                child: Card(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.termsOfUseTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'BirdNET Live is an open-source application for bird species '
                          'identification. By using this app, you agree to the following terms:\n\n'
                          '1. The app processes audio data entirely on your device. '
                          'No audio is transmitted to external servers unless you explicitly '
                          'configure API sync.\n\n'
                          '2. Species identifications are model predictions and should not be '
                          'used as the sole basis for conservation decisions.\n\n'
                          '3. The BirdNET model is provided by the Cornell K. Lisa Yang Center for '
                          'Conservation Bioacoustics at the Cornell Lab of Ornithology and '
                          'Chemnitz University of Technology.\n\n'
                          '4. The app is distributed under the MIT License.',
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Privacy Policy',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'BirdNET Live respects your privacy:\n\n'
                          '- All audio processing and inference happen on-device.\n'
                          '- No personal data is collected or transmitted by default.\n'
                          '- Location data is stored locally for geotagging detections.\n'
                          '- Map tiles are downloaded from OpenTopoMap only with your consent.\n'
                          '- API sync is user-initiated and configurable.\n'
                          '- You can export or delete all stored data at any time from Settings.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Message
              Text(
                l10n.termsRequiredMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Show a message that they can't use the app
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.termsRequiredMessage)),
                        );
                      },
                      child: Text(l10n.declineTerms),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(termsAcceptedProvider.notifier).accept();
                      },
                      child: Text(l10n.acceptTerms),
                    ),
                  ),
                ],
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
