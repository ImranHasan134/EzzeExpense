// ============================================================
//  core/theme.dart — Fully Adaptive Theme (Light + Dark)
//  Accent: Oceanic Cobalt #2563EB  |  Balanced radius
//  Dark:  Midnight Navy, Glowing Azure
//  Light: Ice Blue, Rich Cobalt accents
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Shared accent colours ─────────────────────────────────────
const Color kAccent      = Color(0xFF2563EB); // main cobalt
const Color kAccentLight = Color(0xFF60A5FA); // sky glow
const Color kAccentDeep  = Color(0xFF1E40AF); // deep navy-blue

// ── Semantic colours ──────────────────────────────────────────
const Color kDanger  = Color(0xFFEF4444); // red
const Color kWarning = Color(0xFFF59E0B); // amber
const Color kPurple  = Color(0xFF8B5CF6); // violet
const Color kBlue    = Color(0xFF3B82F6); // blue

// ── Dark palette ──────────────────────────────────────────────
const _dBgDeep      = Color(0xFF0B0E14);
const _dBgBase      = Color(0xFF0F172A);
const _dBgCard      = Color(0xFF1E293B);
const _dBgCardAlt   = Color(0xFF334155);
const _dBgInput     = Color(0xFF0F172A);
const _dTextPrimary = Color(0xFFF8FAFC);
const _dTextSecond  = Color(0xFF94A3B8);
const _dTextHint    = Color(0xFF64748B);
const _dDivider     = Color(0xFF334155);
const _dBorder      = Color(0xFF475569);

// ── Light palette ─────────────────────────────────────────────
const _lBgBase      = Color(0xFFF8FAFC); // clean slate white
const _lBgCard      = Color(0xFFFFFFFF); // white cards
const _lBgCardAlt   = Color(0xFFE2E8F0); // soft blue-grey
const _lBgInput     = Color(0xFFFFFFFF); // white input
const _lTextPrimary = Color(0xFF0F172A); // deep navy text
const _lTextSecond  = Color(0xFF475569); // medium slate
const _lTextHint    = Color(0xFF94A3B8); // soft hint
const _lDivider     = Color(0xFFE2E8F0); // light divider
const _lBorder      = Color(0xFFCBD5E1); // light border

// ── EzzeTheme context helper ──────────────────────────────────
class EzzeTheme {
  final bool isDark;
  const EzzeTheme._(this.isDark);

  factory EzzeTheme.of(BuildContext context) {
    return EzzeTheme._(Theme.of(context).brightness == Brightness.dark);
  }

  Color get bgDeep      => isDark ? _dBgDeep      : const Color(0xFFE2E8F0);
  Color get bgBase      => isDark ? _dBgBase      : _lBgBase;
  Color get bgCard      => isDark ? _dBgCard      : _lBgCard;
  Color get bgCardAlt   => isDark ? _dBgCardAlt   : _lBgCardAlt;
  Color get bgInput     => isDark ? _dBgInput     : _lBgInput;
  Color get textPrimary => isDark ? _dTextPrimary : _lTextPrimary;
  Color get textSecond  => isDark ? _dTextSecond  : _lTextSecond;
  Color get textHint    => isDark ? _dTextHint    : _lTextHint;
  Color get divider     => isDark ? _dDivider     : _lDivider;
  Color get border      => isDark ? _dBorder      : _lBorder;
  Color get accentGlow  => isDark
      ? const Color(0x252563EB) : const Color(0x1A2563EB);
  Color get dangerLight => isDark
      ? const Color(0x22EF4444) : const Color(0x18EF4444);
  Color get warningLight => isDark
      ? const Color(0x22F59E0B) : const Color(0x18F59E0B);

  BoxDecoration glowCard({double radius = 16}) => BoxDecoration(
    color:        bgCard,
    borderRadius: BorderRadius.circular(radius),
    border:       Border.all(color: border, width: 1),
    boxShadow: isDark
        ? const [BoxShadow(
        color: Color(0x1A2563EB), blurRadius: 12, offset: Offset(0, 4))]
        : [BoxShadow(
        color: Colors.black.withOpacity(0.07),
        blurRadius: 8, offset: const Offset(0, 2))],
  );

  BoxDecoration accentCard({double radius = 16}) => BoxDecoration(
    color: isDark
        ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
        color: kAccent.withOpacity(isDark ? 0.35 : 0.45), width: 1),
    boxShadow: isDark
        ? const [BoxShadow(
        color: Color(0x222563EB), blurRadius: 16, offset: Offset(0, 4))]
        : [BoxShadow(
        color: kAccent.withOpacity(0.12),
        blurRadius: 10, offset: const Offset(0, 3))],
  );

  BoxDecoration headerGradient() => BoxDecoration(
    gradient: LinearGradient(
      colors: isDark
          ? [const Color(0xFF0F172A), _dBgBase]
          : [const Color(0xFFDBEAFE), _lBgBase],
      begin: Alignment.topCenter,
      end:   Alignment.bottomCenter,
    ),
  );
}

const LinearGradient kAccentGradient = LinearGradient(
  colors: [kAccent, kAccentLight],
  begin:  Alignment.topLeft,
  end:    Alignment.bottomRight,
);

ThemeData buildTheme(bool isDark) {
  final t = EzzeTheme._(isDark);

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor:              Colors.transparent,
    statusBarBrightness:         isDark ? Brightness.dark  : Brightness.light,
    statusBarIconBrightness:     isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor:    t.bgBase,
    systemNavigationBarIconBrightness:
    isDark ? Brightness.light : Brightness.dark,
  ));

  return ThemeData(
    useMaterial3:            true,
    brightness:              isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: t.bgBase,

    colorScheme: isDark
        ? ColorScheme.dark(
      primary:    kAccent,      onPrimary:  _dBgDeep,
      secondary:  kAccentLight, onSecondary: _dBgDeep,
      surface:    t.bgCard,     onSurface:  t.textPrimary,
      surfaceContainerHighest: t.bgCardAlt,
      error:      kDanger,      onError:    Colors.white,
    )
        : ColorScheme.light(
      primary:    kAccent,      onPrimary:  Colors.white,
      secondary:  kAccentDeep,  onSecondary: Colors.white,
      surface:    t.bgCard,     onSurface:  t.textPrimary,
      surfaceContainerHighest: t.bgCardAlt,
      error:      kDanger,      onError:    Colors.white,
    ),

    cardTheme: CardThemeData(
      color:       t.bgCard,
      elevation:   isDark ? 0 : 1,
      shadowColor: isDark ? Colors.transparent : Colors.black12,
      margin:      EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.border, width: 1),
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor:  t.bgBase,
      foregroundColor:  t.textPrimary,
      elevation:        0,
      centerTitle:      false,
      surfaceTintColor: Colors.transparent,
      shadowColor:      Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarBrightness:     isDark ? Brightness.dark  : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        color:         t.textPrimary,
        fontSize:      20,
        fontWeight:    FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme:        IconThemeData(color: t.textSecond),
      actionsIconTheme: IconThemeData(color: t.textSecond),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.bgBase,
      indicatorColor:  kAccent.withOpacity(isDark ? 0.2 : 0.13),
      iconTheme: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected))
          return const IconThemeData(color: kAccent, size: 24);
        return IconThemeData(color: t.textHint, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected))
          return const TextStyle(
              color: kAccent, fontSize: 11, fontWeight: FontWeight.w600);
        return TextStyle(
            color: t.textHint, fontSize: 11, fontWeight: FontWeight.w400);
      }),
      surfaceTintColor: Colors.transparent,
      elevation:        0,
      height:           68,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kAccent,
      foregroundColor: isDark ? _dBgDeep : Colors.white,
      elevation:       8,
      shape:           const CircleBorder(),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled:    true,
      fillColor: t.bgInput,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
      labelStyle:      TextStyle(color: t.textSecond, fontSize: 14),
      hintStyle:       TextStyle(color: t.textHint,   fontSize: 14),
      prefixIconColor: t.textSecond,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    chipTheme: ChipThemeData(
      backgroundColor:     t.bgCardAlt,
      selectedColor:       kAccent.withOpacity(0.15),
      labelStyle:          TextStyle(color: t.textSecond, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: kAccent, fontSize: 13),
      side:                BorderSide(color: t.border, width: 1),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      checkmarkColor: kAccent,
    ),

    dividerTheme:
    DividerThemeData(color: t.divider, thickness: 1, space: 1),

    textTheme: TextTheme(
      displayLarge:  TextStyle(color: t.textPrimary, fontWeight: FontWeight.w800),
      displayMedium: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
      titleLarge:    TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium:   TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
      titleSmall:    TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
      bodyLarge:     TextStyle(color: t.textPrimary, fontSize: 15),
      bodyMedium:    TextStyle(color: t.textSecond,  fontSize: 14),
      bodySmall:     TextStyle(color: t.textSecond,  fontSize: 12),
      labelLarge:    TextStyle(color: t.textSecond,  fontWeight: FontWeight.w600, fontSize: 13),
      labelSmall:    TextStyle(color: t.textHint,    fontSize: 11),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? kAccent : t.textHint),
      trackColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected)
          ? kAccent.withOpacity(0.3)
          : t.bgCardAlt),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? kAccent : t.textHint),
    ),

    listTileTheme: ListTileThemeData(
      iconColor:         t.textSecond,
      textColor:         t.textPrimary,
      subtitleTextStyle: TextStyle(color: t.textSecond, fontSize: 13),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color:            kAccent,
      linearTrackColor: t.bgCardAlt,
    ),

    iconTheme: IconThemeData(color: t.textSecond, size: 22),
  );
}