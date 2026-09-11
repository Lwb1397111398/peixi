import 'package:flutter/material.dart';
import 'package:peixi/core/theme/tokens.dart';

/// 全局主题：鼠尾草绿 × 暖白纸感（浅色）/ 墨绿暖黑（深色）。
/// 色值规格见 DESIGN.md；本文件是主题的唯一装配点，
/// 页面不再自拼 TextStyle / 颜色，只消费 Theme 与语义 token。
abstract final class AppTheme {
  static const _seed = Color(0xFF5E7F63); // 鼠尾草绿

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final seeded =
        ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

    // 中性色向绿相微偏移的"纸感"覆盖（fromSeed 的中性不够暖）
    final colorScheme = isLight
        ? seeded.copyWith(
            surface: const Color(0xFFF9F8F2),
            surfaceContainerLowest: const Color(0xFFFEFDFA),
            surfaceContainerLow: const Color(0xFFF3F2EA),
            surfaceContainer: const Color(0xFFEDECE3),
            surfaceContainerHigh: const Color(0xFFE7E6DC),
            surfaceContainerHighest: const Color(0xFFE1E0D5),
            onSurface: const Color(0xFF1B1C18),
            onSurfaceVariant: const Color(0xFF43483E),
            outline: const Color(0xFF74796C),
            outlineVariant: const Color(0xFFD5D6CA),
          )
        : seeded.copyWith(
            surface: const Color(0xFF131510),
            surfaceContainerLowest: const Color(0xFF181A15),
            surfaceContainerLow: const Color(0xFF1E211B),
            surfaceContainer: const Color(0xFF262A22),
            surfaceContainerHigh: const Color(0xFF2F332A),
            surfaceContainerHighest: const Color(0xFF393D33),
            onSurface: const Color(0xFFE2E3DA),
            onSurfaceVariant: const Color(0xFFC2C6B9),
            outline: const Color(0xFF8B9083),
            outlineVariant: const Color(0xFF3F4339),
          );

    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    final textTheme = _textTheme(onSurface, onSurfaceVariant)
        .apply(fontFamily: kFontPrimary, fontFamilyFallback: kFontFamilyFallback);
    final cardSide = isLight
        ? BorderSide(color: colorScheme.outlineVariant)
        : BorderSide.none;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      extensions: [
        isLight ? SemanticColors.light : SemanticColors.dark,
      ],

      // ---- 导航 ----
      appBarTheme: AppBarThemeData(
        backgroundColor: colorScheme.surface,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(size: 22, color: onSurfaceVariant),
        actionsIconTheme: IconThemeData(size: 20, color: onSurfaceVariant),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        groupAlignment: 0,
        useIndicator: true,
        indicatorColor: colorScheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: onSurfaceVariant),
        selectedLabelTextStyle: textTheme.titleSmall!
            .copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle:
            textTheme.titleSmall!.copyWith(color: onSurfaceVariant),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
                right: Radius.circular(AppRadius.lg))),
      ),

      // ---- 容器 ----
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd, side: cardSide),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        barrierColor: isLight ? const Color(0x521B1C18) : const Color(0x7F000000),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x29000000),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        textStyle: textTheme.bodyMedium,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ---- 控件 ----
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        hintStyle: textTheme.bodyMedium!.copyWith(
            color: onSurfaceVariant.withValues(alpha: 0.55)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.m),
        border: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: BorderSide(color: colorScheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: BorderSide(color: colorScheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: BorderSide(color: colorScheme.error, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: BorderSide(color: colorScheme.error, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(textTheme.labelLarge!,
                foreground: colorScheme.onPrimary)
            .copyWith(
          backgroundColor:
              const WidgetStatePropertyAll<Color?>(null), // 用 M3 默认 primary
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(textTheme.labelLarge!, foreground: onSurface)
            .copyWith(
          side: WidgetStatePropertyAll(
              BorderSide(color: colorScheme.outlineVariant)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: AppRadius.rMd)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium!.copyWith(color: onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 2),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs),
        iconColor: onSurfaceVariant,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall!.copyWith(height: 1.35),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        collapsedShape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        childrenPadding: const EdgeInsets.only(bottom: Space.s),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHigh,
        circularTrackColor: colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.rSm,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle:
            textTheme.bodyMedium!.copyWith(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        dividerColor: colorScheme.outlineVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: colorScheme.inverseSurface, borderRadius: AppRadius.rSm),
        textStyle: textTheme.bodySmall!.copyWith(color: colorScheme.onInverseSurface),
        waitDuration: const Duration(milliseconds: 400),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(AppRadius.sm),
        thumbVisibility: const WidgetStatePropertyAll(false),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
      ),
      iconTheme: IconThemeData(size: 20, color: onSurfaceVariant),
    );
  }

  static ButtonStyle _buttonStyle(TextStyle label,
          {required Color foreground}) =>
      ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(foreground),
        textStyle: WidgetStatePropertyAll(label),
        minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Space.l)),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.rMd)),
      );

  static TextTheme _textTheme(Color onSurface, Color onSurfaceVariant) =>
      TextTheme(
        displaySmall: TextStyle(
            fontSize: 30, height: 1.2, letterSpacing: -0.5,
            fontWeight: FontWeight.w600, color: onSurface),
        headlineMedium: TextStyle(
            fontSize: 24, height: 1.25, letterSpacing: -0.3,
            fontWeight: FontWeight.w600, color: onSurface),
        headlineSmall: TextStyle(
            fontSize: 21, height: 1.3, letterSpacing: -0.2,
            fontWeight: FontWeight.w600, color: onSurface),
        titleLarge: TextStyle(
            fontSize: 17, height: 1.4,
            fontWeight: FontWeight.w600, color: onSurface),
        titleMedium: TextStyle(
            fontSize: 14.5, height: 1.4, letterSpacing: 0.1,
            fontWeight: FontWeight.w600, color: onSurface),
        titleSmall: TextStyle(
            fontSize: 12.5, height: 1.4, letterSpacing: 0.2,
            fontWeight: FontWeight.w600, color: onSurface),
        bodyLarge: TextStyle(fontSize: 14.5, height: 1.6, color: onSurface),
        bodyMedium: TextStyle(fontSize: 13, height: 1.55, color: onSurface),
        bodySmall: TextStyle(fontSize: 11.5, height: 1.45, color: onSurfaceVariant),
        labelLarge: TextStyle(
            fontSize: 13, height: 1.2, letterSpacing: 0.1,
            fontWeight: FontWeight.w600, color: onSurface),
        labelMedium: TextStyle(
            fontSize: 11, height: 1.25, letterSpacing: 0.3,
            fontWeight: FontWeight.w600, color: onSurfaceVariant),
        labelSmall: TextStyle(
            fontSize: 10, height: 1.3, letterSpacing: 0.4,
            fontWeight: FontWeight.w600, color: onSurfaceVariant),
      );
}
