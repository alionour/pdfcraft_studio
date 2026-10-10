import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'theme/dashboard_style_app_bar.dart';
import 'widgets/dashboard_card.dart';

/// Shown in place of a tool whose processing engine is not finished yet, so
/// the app never reports work it did not actually do.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String description;

  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: DashboardStyleAppBar(
        title: Text(title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: DashboardCard(
              icon: PhosphorIconsLight.hourglassMedium,
              iconColor: theme.colorScheme.primary,
              title: 'Coming soon',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This tool is turned off until it can process your files '
                    'correctly. It will return in a future update.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
