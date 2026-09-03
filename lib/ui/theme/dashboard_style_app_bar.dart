import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An [AppBar] restyled to visually match the app's flat, borderless
/// in-body header: no elevation, background blending into the page, and a
/// bold flush-left title. Used across the app so every screen's app bar
/// looks consistent, including dark mode.
///
/// Accepts the same commonly-used [AppBar] parameters as a drop-in
/// replacement — pass `AppBar(...)` call sites through unchanged except for
/// the widget name. Any explicit override (e.g. a page that truly needs
/// `centerTitle: true`) wins over the shared defaults below.
class DashboardStyleAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DashboardStyleAppBar({
    super.key,
    this.title,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.bottom,
    this.centerTitle,
    this.elevation,
    this.scrolledUnderElevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.shape,
    this.backgroundColor,
    this.foregroundColor,
    this.iconTheme,
    this.actionsIconTheme,
    this.titleSpacing,
    this.toolbarHeight,
    this.titleTextStyle,
    this.toolbarTextStyle,
    this.systemOverlayStyle,
    this.flexibleSpace,
  });

  final Widget? title;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;
  final double? elevation;
  final double? scrolledUnderElevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final ShapeBorder? shape;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconThemeData? iconTheme;
  final IconThemeData? actionsIconTheme;
  final double? titleSpacing;
  final double? toolbarHeight;
  final TextStyle? titleTextStyle;
  final TextStyle? toolbarTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final Widget? flexibleSpace;

  @override
  Size get preferredSize => Size.fromHeight(
        (toolbarHeight ?? kToolbarHeight) + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBackground = backgroundColor ?? theme.scaffoldBackgroundColor;
    return AppBar(
      backgroundColor: resolvedBackground,
      surfaceTintColor: surfaceTintColor ?? resolvedBackground,
      elevation: elevation ?? 0,
      scrolledUnderElevation: scrolledUnderElevation ?? elevation ?? 0,
      shadowColor: shadowColor,
      shape: shape,
      foregroundColor: foregroundColor ?? theme.colorScheme.onSurface,
      iconTheme: iconTheme,
      actionsIconTheme: actionsIconTheme,
      titleSpacing: titleSpacing,
      toolbarHeight: toolbarHeight,
      toolbarTextStyle: toolbarTextStyle,
      systemOverlayStyle: systemOverlayStyle,
      flexibleSpace: flexibleSpace,
      titleTextStyle: titleTextStyle ??
          theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            color: theme.colorScheme.onSurface,
          ),
      centerTitle: centerTitle ?? false,
      title: title,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      bottom: bottom,
    );
  }
}
