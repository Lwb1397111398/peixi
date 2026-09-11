import 'package:flutter/material.dart';

/// 设计 token：间距 / 圆角 / 断点 / 字体栈。规格唯一来源见 DESIGN.md。
abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  static final BorderRadius rSm = BorderRadius.circular(sm);
  static final BorderRadius rMd = BorderRadius.circular(md);
  static final BorderRadius rLg = BorderRadius.circular(lg);
}

/// 播放器双栏与导航栏收缩共用的窗口宽度断点
const double kTwoPaneBreakpoint = 900;

/// 主字体（拉丁/数字走 Segoe UI，中文按 fallback 落到雅黑）
const String kFontPrimary = 'Segoe UI';

/// 中文字体回退栈
const List<String> kFontFamilyFallback = [
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'PingFang SC',
  'Noto Sans CJK SC',
];

/// 语义色 token：状态色的唯一来源。
/// 禁止页面裸用 Colors.green/orange/red/blue，统一走
/// `context.semanticColors.xxx`（ThemeExtension，随主题自动切换明暗套）。
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.error,
    required this.errorBg,
    required this.info,
    required this.infoBg,
  });

  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color error;
  final Color errorBg;
  final Color info;
  final Color infoBg;

  static const light = SemanticColors(
    success: Color(0xFF3E7D46), successBg: Color(0xFFE2EEE0),
    warning: Color(0xFF9A6A00), warningBg: Color(0xFFF3E8CC),
    error: Color(0xFFBA3A2B), errorBg: Color(0xFFF6DED9),
    info: Color(0xFF3A6D93), infoBg: Color(0xFFDAE7F0),
  );

  static const dark = SemanticColors(
    success: Color(0xFF93D095), successBg: Color(0xFF223520),
    warning: Color(0xFFE9C368), warningBg: Color(0xFF3A2F14),
    error: Color(0xFFF2A79B), errorBg: Color(0xFF43251F),
    info: Color(0xFF96CCEA), infoBg: Color(0xFF1D3346),
  );

  @override
  SemanticColors copyWith({
    Color? success, Color? successBg,
    Color? warning, Color? warningBg,
    Color? error, Color? errorBg,
    Color? info, Color? infoBg,
  }) =>
      SemanticColors(
        success: success ?? this.success, successBg: successBg ?? this.successBg,
        warning: warning ?? this.warning, warningBg: warningBg ?? this.warningBg,
        error: error ?? this.error, errorBg: errorBg ?? this.errorBg,
        info: info ?? this.info, infoBg: infoBg ?? this.infoBg,
      );

  @override
  SemanticColors lerp(SemanticColors? other, double t) {
    if (other == null) return this;
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
    );
  }
}

extension SemanticColorsContext on BuildContext {
  SemanticColors get semanticColors =>
      Theme.of(this).extension<SemanticColors>() ?? SemanticColors.light;
}
