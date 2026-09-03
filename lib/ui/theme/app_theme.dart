import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme generated the same way dr_copilot builds its theme: a
/// [FlexColorScheme] preset (`FlexScheme.tealM3`) converted to a
/// [ThemeData], then given the same app-bar/tab-bar/transition overrides
/// and set to the Poppins font family app-wide.
class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? FlexColorScheme.dark(scheme: FlexScheme.tealM3).toTheme
        : FlexColorScheme.light(scheme: FlexScheme.tealM3).toTheme;

    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: GoogleFonts.poppins().fontFamily),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: base.colorScheme.primaryContainer,
        foregroundColor: base.colorScheme.onPrimaryContainer,
        iconTheme: IconThemeData(color: base.colorScheme.onPrimaryContainer),
        actionsIconTheme: IconThemeData(color: base.colorScheme.onPrimaryContainer),
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: base.colorScheme.primary,
        unselectedLabelColor: base.colorScheme.onSurfaceVariant,
        indicatorColor: base.colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(
          base.colorScheme.primary.withValues(alpha: 0.08),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// dr_copilot fade-through slide transition builder
class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final fadeOut = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeIn,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(curved),
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 1,
          end: 0,
        ).animate(fadeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
