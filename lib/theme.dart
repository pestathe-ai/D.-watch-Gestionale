import 'package:flutter/material.dart';

/// Rosso del marchio (icona, pulsanti principali, riquadro in evidenza).
const Color kRed = Color(0xFFD62828);
const Color kRedDeep = Color(0xFF9F1A1A);

/// Colori semantici dell'app, uno per tema chiaro e uno per scuro.
@immutable
class Tk extends ThemeExtension<Tk> {
  final Color bg;
  final Color surface;
  final Color field;
  final Color ink;
  final Color muted;
  final Color border;
  final Color red;
  final Color redSoft;
  final Color green;
  final Color greenSoft;

  const Tk({
    required this.bg,
    required this.surface,
    required this.field,
    required this.ink,
    required this.muted,
    required this.border,
    required this.red,
    required this.redSoft,
    required this.green,
    required this.greenSoft,
  });

  static const light = Tk(
    bg: Color(0xFFF6F3F1),
    surface: Color(0xFFFFFFFF),
    field: Color(0xFFF3EFED),
    ink: Color(0xFF1B1B1F),
    muted: Color(0xFF6E6A6A),
    border: Color(0xFFECE7E4),
    red: Color(0xFFD62828),
    redSoft: Color(0xFFFDE8E8),
    green: Color(0xFF1E7B3E),
    greenSoft: Color(0xFFE6F4EA),
  );

  static const dark = Tk(
    bg: Color(0xFF131113),
    surface: Color(0xFF1D1A1D),
    field: Color(0xFF282428),
    ink: Color(0xFFF4F0F0),
    muted: Color(0xFFA9A3A3),
    border: Color(0xFF2E2A2E),
    red: Color(0xFFFF6B6B),
    redSoft: Color(0xFF3A1D1F),
    green: Color(0xFF5CC97E),
    greenSoft: Color(0xFF1B3324),
  );

  @override
  Tk copyWith({
    Color? bg,
    Color? surface,
    Color? field,
    Color? ink,
    Color? muted,
    Color? border,
    Color? red,
    Color? redSoft,
    Color? green,
    Color? greenSoft,
  }) =>
      Tk(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        field: field ?? this.field,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        border: border ?? this.border,
        red: red ?? this.red,
        redSoft: redSoft ?? this.redSoft,
        green: green ?? this.green,
        greenSoft: greenSoft ?? this.greenSoft,
      );

  @override
  Tk lerp(ThemeExtension<Tk>? other, double t) {
    if (other is! Tk) return this;
    return Tk(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      field: Color.lerp(field, other.field, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      red: Color.lerp(red, other.red, t)!,
      redSoft: Color.lerp(redSoft, other.redSoft, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenSoft: Color.lerp(greenSoft, other.greenSoft, t)!,
    );
  }
}

extension TkContext on BuildContext {
  Tk get tk => Theme.of(this).extension<Tk>()!;
}

/// Cifre allineate in colonna (importi leggibili e ordinati).
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];

ThemeData buildTheme(Brightness b) {
  final isLight = b == Brightness.light;
  final t = isLight ? Tk.light : Tk.dark;
  final base = ThemeData(brightness: b, useMaterial3: true);
  final cs = ColorScheme.fromSeed(seedColor: kRed, brightness: b).copyWith(
    primary: t.red,
    onPrimary: isLight ? Colors.white : const Color(0xFF2B0B0B),
    surface: t.surface,
    onSurface: t.ink,
    outline: t.border,
    outlineVariant: t.border,
    surfaceContainerHighest: t.field,
  );
  RoundedRectangleBorder shape(double r) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
  OutlineInputBorder field(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: c == Colors.transparent ? BorderSide.none : BorderSide(color: c, width: w),
      );

  return base.copyWith(
    colorScheme: cs,
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.surface,
    dividerColor: t.border,
    extensions: [t],
    textTheme: base.textTheme.apply(bodyColor: t.ink, displayColor: t.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: t.ink, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: field(Colors.transparent, 0),
      enabledBorder: field(Colors.transparent, 0),
      focusedBorder: field(t.red, 1.6),
      labelStyle: TextStyle(color: t.muted),
      hintStyle: TextStyle(color: t.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: shape(14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: shape(14),
        foregroundColor: t.ink,
        side: BorderSide(color: t.border),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kRed,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: shape(18),
      extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: t.redSoft,
      height: 72,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((s) {
        final sel = s.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11.5,
          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          color: sel ? t.ink : t.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((s) {
        return IconThemeData(color: s.contains(WidgetState.selected) ? t.red : t.muted, size: 24);
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: t.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: shape(24),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      contentTextStyle: TextStyle(color: t.bg, fontSize: 14),
      shape: shape(14),
    ),
  );
}
