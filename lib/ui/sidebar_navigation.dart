import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/theme_notifier.dart';
import 'home_screen.dart';
import 'organize_screen.dart';
import 'compress_screen.dart';
import 'security_screen.dart';
import 'ocr_screen.dart';
import 'stamper_screen.dart';
import 'layout_screen.dart';
import 'metadata_screen.dart';
import 'filter_screen.dart';
import 'extractor_screen.dart';
import 'flatten_screen.dart';
import 'bookmark_screen.dart';
import 'accessibility_screen.dart';
import 'crop_screen.dart';
import 'compare_screen.dart';
import 'form_data_screen.dart';
import 'splitter_screen.dart';
import 'reorder_screen.dart';
import 'merge_screen.dart';
import 'watermark_background_screen.dart';
import 'orientation_normalizer_screen.dart';
import 'header_footer_screen.dart';
import 'table_extractor_screen.dart';
import 'settings_screen.dart';

class SidebarNavigation extends StatefulWidget {
  const SidebarNavigation({super.key});

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation> {
  int _selectedIndex = 0;
  bool _isExpanded = true;

  final List<Widget> _pages = const [
    HomeScreen(),
    OrganizeScreen(),
    CompressScreen(),
    SecurityScreen(),
    OcrScreen(),
    StamperScreen(),
    LayoutScreen(),
    MetadataScreen(),
    FilterScreen(),
    ExtractorScreen(),
    FlattenScreen(),
    BookmarkScreen(),
    AccessibilityScreen(),
    CropScreen(),
    CompareScreen(),
    FormDataScreen(),
    SplitterScreen(),
    ReorderScreen(),
    MergeScreen(),
    WatermarkBackgroundScreen(),
    OrientationNormalizerScreen(),
    HeaderFooterScreen(),
    TableExtractorScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: _isExpanded ? 240 : 70,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(theme),
                    const Divider(height: 1, thickness: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        children: [
                          if (_isExpanded) _buildCategoryTitle('Convert & Core', theme),
                          _buildMenuItem(
                            index: 0,
                            title: 'Convert Hub',
                            icon: PhosphorIconsLight.arrowsLeftRight,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 1,
                            title: 'Organize & Edit',
                            icon: PhosphorIconsLight.squaresFour,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 2,
                            title: 'Compress PDF',
                            icon: PhosphorIconsLight.arrowsInLineHorizontal,
                            theme: theme,
                          ),
                          const SizedBox(height: 16),
                          if (_isExpanded) _buildCategoryTitle('Document Utilities', theme),
                          _buildMenuItem(
                            index: 3,
                            title: 'Security & Stamps',
                            icon: PhosphorIconsLight.shieldCheck,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 4,
                            title: 'OCR & Text Extract',
                            icon: PhosphorIconsLight.textAa,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 5,
                            title: 'Page Numbers',
                            icon: PhosphorIconsLight.hash,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 6,
                            title: 'N-Up Grid Layout',
                            icon: PhosphorIconsLight.gridFour,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 7,
                            title: 'Metadata & Privacy',
                            icon: PhosphorIconsLight.info,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 8,
                            title: 'Color Filters & Dark Mode',
                            icon: PhosphorIconsLight.palette,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 9,
                            title: 'Image & Asset Extractor',
                            icon: PhosphorIconsLight.images,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 10,
                            title: 'Form & Annotation Flatten',
                            icon: PhosphorIconsLight.fileLock,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 11,
                            title: 'Bookmarks & TOC Outline',
                            icon: PhosphorIconsLight.bookmarkSimple,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 12,
                            title: 'Accessibility & Contrast',
                            icon: PhosphorIconsLight.eye,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 13,
                            title: 'Margin & Page Crop',
                            icon: PhosphorIconsLight.crop,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 14,
                            title: 'Compare & Visual Diff',
                            icon: PhosphorIconsLight.gitDiff,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 15,
                            title: 'Form Data Exporter',
                            icon: PhosphorIconsLight.table,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 16,
                            title: 'Page Splitter & Extractor',
                            icon: PhosphorIconsLight.scissors,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 17,
                            title: 'Page Reorder & Rotate',
                            icon: PhosphorIconsLight.arrowsDownUp,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 18,
                            title: 'Batch Merger & Joiner',
                            icon: PhosphorIconsLight.gitMerge,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 19,
                            title: 'Watermark & Background',
                            icon: PhosphorIconsLight.stamp,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 20,
                            title: 'Orientation & Size Normalizer',
                            icon: PhosphorIconsLight.arrowsOutSimple,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 21,
                            title: 'Header & Footer Customizer',
                            icon: PhosphorIconsLight.textT,
                            theme: theme,
                          ),
                          _buildMenuItem(
                            index: 22,
                            title: 'Table Extractor & CSV',
                            icon: PhosphorIconsLight.table,
                            theme: theme,
                          ),
                          const SizedBox(height: 16),
                          if (_isExpanded) _buildCategoryTitle('Preferences', theme),
                          _buildMenuItem(
                            index: 23,
                            title: 'Settings',
                            icon: PhosphorIconsLight.gearSix,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    _buildFooter(theme),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_selectedIndex),
                  child: _pages[_selectedIndex],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.arrowsLeftRight),
              label: 'Convert',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.squaresFour),
              label: 'Organize',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.arrowsInLineHorizontal),
              label: 'Compress',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.shieldCheck),
              label: 'Security',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.textAa),
              label: 'OCR',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.hash),
              label: 'Stamper',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.gridFour),
              label: 'N-Up',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.info),
              label: 'Metadata',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.palette),
              label: 'Filter',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.images),
              label: 'Extractor',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.fileLock),
              label: 'Flatten',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.bookmarkSimple),
              label: 'Bookmarks',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.eye),
              label: 'Access',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.crop),
              label: 'Crop',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.gitDiff),
              label: 'Compare',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.table),
              label: 'Form Data',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.scissors),
              label: 'Splitter',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.arrowsDownUp),
              label: 'Reorder',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.gitMerge),
              label: 'Merger',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.stamp),
              label: 'Watermark',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.arrowsOutSimple),
              label: 'Size',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.textT),
              label: 'Header',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.table),
              label: 'Tables',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.gearSix),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    if (!_isExpanded) {
      return Container(
        height: 64,
        alignment: Alignment.center,
        child: IconButton(
          tooltip: 'Expand Sidebar',
          icon: const Icon(PhosphorIconsLight.caretRight),
          onPressed: () => setState(() => _isExpanded = true),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 64,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = false),
        child: Row(
          children: [
            Icon(
              PhosphorIconsLight.filePdf,
              size: 28,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'PDFCraft',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Text(
                'STUDIO',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.orange[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  final Map<int, bool> _hoverStates = {};

  Widget _buildMenuItem({
    required int index,
    required String title,
    required IconData icon,
    required ThemeData theme,
  }) {
    final isSelected = _selectedIndex == index;
    final isHovered = _hoverStates[index] ?? false;

    if (!_isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: title,
          preferBelow: false,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoverStates[index] = true),
            onExit: (_) => setState(() => _hoverStates[index] = false),
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 46,
                transform: isHovered && !isSelected
                    ? Matrix4.translationValues(0.0, -2.0, 0.0)
                    : Matrix4.identity(),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : isHovered
                          ? theme.colorScheme.primary.withValues(alpha: 0.06)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : isHovered
                          ? theme.colorScheme.primary.withValues(alpha: 0.85)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoverStates[index] = true),
        onExit: (_) => setState(() => _hoverStates[index] = false),
        child: GestureDetector(
          onTap: () => setState(() => _selectedIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: isHovered && !isSelected
                ? Matrix4.translationValues(0.0, -2.0, 0.0)
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : isHovered
                      ? theme.colorScheme.primary.withValues(alpha: 0.05)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: isSelected ? 9 : 12,
                right: 12,
                top: 10,
                bottom: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : isHovered
                            ? theme.colorScheme.primary.withValues(alpha: 0.85)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildFooter(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (!_isExpanded) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: Tooltip(
          message: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
          child: IconButton(
            icon: Icon(
              isDark ? PhosphorIconsLight.sun : PhosphorIconsLight.moon,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            onPressed: () {
              themeNotifier.setThemeMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      height: 60,
      child: Row(
        children: [
          Icon(
            PhosphorIconsLight.userCircle,
            size: 32,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offline Utility',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
            child: IconButton(
              icon: Icon(
                isDark ? PhosphorIconsLight.sun : PhosphorIconsLight.moon,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              onPressed: () {
                themeNotifier.setThemeMode(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
