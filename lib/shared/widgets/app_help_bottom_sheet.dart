// =============================================================================
// App Help Bottom Sheet — Shared bottom-sheet layout for screen help overlays
// =============================================================================
//
// Provides a consistent draggable help sheet used by operational screens.
// Each section pairs one in-app icon with a short explanation of that control
// or area of the screen.
// =============================================================================

import 'package:flutter/material.dart';

class AppHelpSection {
  const AppHelpSection({required this.icon, required this.body});

  final IconData icon;
  final String body;
}

class AppHelpBottomSheet extends StatelessWidget {
  const AppHelpBottomSheet({
    super.key,
    required this.title,
    required this.sections,
    this.initialChildSize = 0.62,
    this.minChildSize = 0.32,
    this.maxChildSize = 0.92,
    this.footer,
  });

  final String title;
  final List<AppHelpSection> sections;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              for (final section in sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        section.icon,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          section.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (footer != null) ...[const SizedBox(height: 4), footer!],
            ],
          ),
        );
      },
    );
  }
}
