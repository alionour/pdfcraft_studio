import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/theme_notifier.dart';
import 'widgets/dashboard_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar — matching dr_copilot style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIconsLight.gear,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Customize application settings and appearance options',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appearance Section Header
                  _buildSectionHeader(
                    context,
                    icon: PhosphorIconsLight.palette,
                    label: 'Appearance & Theme',
                  ),
                  const SizedBox(height: 16),

                  // Theme Selection Card
                  DashboardCard(
                    icon: PhosphorIconsLight.sun,
                    iconColor: theme.colorScheme.primary,
                    title: 'Theme Mode',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select your preferred color theme for PDFCraft Studio interface',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: themeNotifier,
                          builder: (context, currentThemeMode, _) {
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 500;
                                if (isWide) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _buildThemeCard(
                                          context,
                                          mode: ThemeMode.light,
                                          title: 'Light Theme',
                                          subtitle: 'Clean & bright appearance',
                                          icon: PhosphorIconsLight.sun,
                                          isSelected: currentThemeMode == ThemeMode.light,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildThemeCard(
                                          context,
                                          mode: ThemeMode.dark,
                                          title: 'Dark Theme',
                                          subtitle: 'Easy on the eyes in low light',
                                          icon: PhosphorIconsLight.moon,
                                          isSelected: currentThemeMode == ThemeMode.dark,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildThemeCard(
                                          context,
                                          mode: ThemeMode.system,
                                          title: 'System Default',
                                          subtitle: 'Sync with OS settings',
                                          icon: PhosphorIconsLight.desktopTower,
                                          isSelected: currentThemeMode == ThemeMode.system,
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    children: [
                                      _buildThemeCard(
                                        context,
                                        mode: ThemeMode.light,
                                        title: 'Light Theme',
                                        subtitle: 'Clean & bright appearance',
                                        icon: PhosphorIconsLight.sun,
                                        isSelected: currentThemeMode == ThemeMode.light,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildThemeCard(
                                        context,
                                        mode: ThemeMode.dark,
                                        title: 'Dark Theme',
                                        subtitle: 'Easy on the eyes in low light',
                                        icon: PhosphorIconsLight.moon,
                                        isSelected: currentThemeMode == ThemeMode.dark,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildThemeCard(
                                        context,
                                        mode: ThemeMode.system,
                                        title: 'System Default',
                                        subtitle: 'Sync with OS settings',
                                        icon: PhosphorIconsLight.desktopTower,
                                        isSelected: currentThemeMode == ThemeMode.system,
                                      ),
                                    ],
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // About Section Header
                  _buildSectionHeader(
                    context,
                    icon: PhosphorIconsLight.info,
                    label: 'About Application',
                  ),
                  const SizedBox(height: 16),

                  // About Card
                  DashboardCard(
                    icon: PhosphorIconsLight.filePdf,
                    iconColor: theme.colorScheme.error,
                    title: 'PDFCraft Studio',
                    trailing: Text(
                      'v1.0.0',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'All-in-one desktop tool for converting, organizing, securing, compressing, and extracting text from PDF files.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeCard(
    BuildContext context, {
    required ThemeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;

    return InkWell(
      onTap: () => themeNotifier.setThemeMode(mode),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : theme.iconTheme.color,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? activeColor : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(PhosphorIconsLight.checkCircle, color: activeColor, size: 20),
          ],
        ),
      ),
    );
  }
}

