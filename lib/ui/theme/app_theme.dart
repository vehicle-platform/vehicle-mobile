import 'package:flutter/material.dart';

import 'package:vehicle_mobile/ui/theme/spacing.dart';
import 'package:vehicle_mobile/ui/theme/tokens.dart';
import 'package:vehicle_mobile/ui/theme/typography.dart';

export 'package:vehicle_mobile/ui/theme/spacing.dart';
export 'package:vehicle_mobile/ui/theme/tokens.dart';
export 'package:vehicle_mobile/ui/theme/typography.dart';

/// The app theme: high contrast, Material 3; dark by default, [Brightness.light]
/// for the system light mode.
ThemeData buildAppTheme({Brightness brightness = Brightness.dark}) {
  final t = brightness == Brightness.dark ? VehicleTokens.dark : VehicleTokens.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.accent,
    onPrimary: t.onAccent,
    secondary: t.accent,
    onSecondary: t.onAccent,
    error: t.error,
    onError: t.onAccent,
    surface: t.surface,
    onSurface: t.textPrimary,
    onSurfaceVariant: t.textSecondary,
    outline: t.outline,
    outlineVariant: t.outline,
    surfaceContainerLowest: t.background,
    surfaceContainerLow: t.surface,
    surfaceContainer: t.surface,
    surfaceContainerHigh: t.surfaceRaised,
    surfaceContainerHighest: t.surfaceRaised,
  );
  final textTheme = buildTextTheme(t);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip));
  const minButton = Size(64, Spacing.touchTarget);

  return ThemeData(
    useMaterial3: true,
    fontFamily: VehicleFonts.text,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.background,
    canvasColor: t.background,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[t],
    appBarTheme: AppBarTheme(
      backgroundColor: t.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      foregroundColor: t.textPrimary,
    ),
    cardTheme: CardThemeData(
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: t.hairline),
      ),
    ),
    dividerTheme: DividerThemeData(color: t.outline, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
            color: selected ? t.accent : t.textSecondary, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium!.copyWith(
          color: selected ? t.accent : t.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          letterSpacing: 0.4,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: t.surface,
      elevation: 0,
      indicatorColor: Colors.transparent,
      minWidth: 80,
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: IconThemeData(color: t.accent, size: 24),
      unselectedIconTheme: IconThemeData(color: t.textSecondary, size: 24),
      selectedLabelTextStyle: textTheme.labelMedium!
          .copyWith(color: t.accent, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: textTheme.labelMedium,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minButton,
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        textStyle: textTheme.labelLarge,
        shape: shape,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: minButton,
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        elevation: 0,
        textStyle: textTheme.labelLarge,
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minButton,
        foregroundColor: t.textPrimary,
        side: BorderSide(color: t.textSecondary),
        textStyle: textTheme.labelLarge,
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minButton,
        foregroundColor: t.accent,
        textStyle: textTheme.labelLarge,
        shape: shape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(Spacing.touchTarget, Spacing.touchTarget),
        foregroundColor: t.textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surfaceRaised,
      labelStyle: textTheme.bodyMedium!.copyWith(color: t.textSecondary),
      hintStyle: textTheme.bodyMedium!.copyWith(color: t.noData),
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
        borderSide: BorderSide(color: t.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
        borderSide: BorderSide(color: t.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
        borderSide: BorderSide(color: t.accent, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onAccent : t.textSecondary),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : t.surfaceRaised),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : t.textSecondary),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: t.accent,
      unselectedLabelColor: t.textSecondary,
      indicatorColor: t.accent,
      dividerColor: t.outline,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelLarge,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: minButton,
        backgroundColor: t.surface,
        foregroundColor: t.textPrimary,
        selectedBackgroundColor: t.surfaceRaised,
        selectedForegroundColor: t.accent,
        side: BorderSide(color: t.outline),
        textStyle: textTheme.labelLarge,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.surfaceRaised,
      contentTextStyle: textTheme.bodyMedium,
      actionTextColor: t.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
        side: BorderSide(color: t.outline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.accent,
      linearTrackColor: t.surfaceRaised,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: t.textSecondary,
      textColor: t.textPrimary,
      minVerticalPadding: Spacing.sm,
    ),
  );
}
