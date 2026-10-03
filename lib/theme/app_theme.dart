import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF25638A),
      brightness: brightness,
    );
    final dark = brightness == Brightness.dark;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    final buttons = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      shape: WidgetStatePropertyAll(shape),
      textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
    return base.copyWith(
      scaffoldBackgroundColor: dark ? scheme.surface : const Color(0xFFF4F7FA),
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium
            ?.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
        headlineSmall: base.textTheme.headlineSmall
            ?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
        titleLarge: base.textTheme.titleLarge
            ?.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: base.textTheme.titleMedium
            ?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
        bodyLarge:
            base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
        bodyMedium:
            base.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
        bodySmall: base.textTheme.bodySmall?.copyWith(
            fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder:
            border.copyWith(borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.error, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttons),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: buttons.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? null : scheme.primary),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? null : scheme.onPrimary),
        elevation: const WidgetStatePropertyAll(0),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttons),
      textButtonTheme: TextButtonThemeData(style: buttons),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: const Color(0x140F2940),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
            color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      drawerTheme: DrawerThemeData(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent),
      listTileTheme: ListTileThemeData(
        shape: shape,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        selectedColor: scheme.primary,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.5),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            TextStyle(color: scheme.onInverseSurface, fontSize: 14),
        shape: shape,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme: DividerThemeData(
          color: scheme.outlineVariant, thickness: 1, space: 24),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: shape,
      ),
    );
  }
}
