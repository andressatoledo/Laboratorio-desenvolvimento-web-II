import 'package:flutter/material.dart';

/// Cores-base da marca: petróleo (asfalto molhado) e âmbar (sinalização).
class AppColors {
  static const ink = Color(0xFF12343B);
  static const amber = Color(0xFFF2A71B);
}

/// Cores que mudam entre tema claro e escuro. Use sempre via
/// `context.kml.muted`, `context.kml.panel` etc., nunca cores fixas,
/// para o app ficar legível nos dois modos.
@immutable
class KmlColors extends ThemeExtension<KmlColors> {
  const KmlColors({
    required this.muted,
    required this.line,
    required this.panel,
    required this.positive,
    required this.negative,
  });

  final Color muted; // textos secundários
  final Color line; // bordas e divisórias
  final Color panel; // fundo dos cartões
  final Color positive; // receitas
  final Color negative; // despesas e erros

  static const light = KmlColors(
    muted: Color(0xFF55666A),
    line: Color(0xFFD9DFDB),
    panel: Colors.white,
    positive: Color(0xFF1F7A4D),
    negative: Color(0xFFB3261E),
  );

  static const dark = KmlColors(
    muted: Color(0xFFA6B8BC),
    line: Color(0xFF2E4146),
    panel: Color(0xFF182529),
    positive: Color(0xFF63D394),
    negative: Color(0xFFFF8A80),
  );

  @override
  KmlColors copyWith({Color? muted, Color? line, Color? panel, Color? positive, Color? negative}) =>
      KmlColors(
        muted: muted ?? this.muted,
        line: line ?? this.line,
        panel: panel ?? this.panel,
        positive: positive ?? this.positive,
        negative: negative ?? this.negative,
      );

  @override
  KmlColors lerp(ThemeExtension<KmlColors>? other, double t) {
    if (other is! KmlColors) return this;
    return KmlColors(
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
    );
  }
}

extension KmlContext on BuildContext {
  KmlColors get kml => Theme.of(this).extension<KmlColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final kml = isDark ? KmlColors.dark : KmlColors.light;
  final background = isDark ? const Color(0xFF0F1A1D) : const Color(0xFFF5F6F3);
  final onBackground = isDark ? const Color(0xFFE8EFF0) : AppColors.ink;

  final scheme = ColorScheme.fromSeed(seedColor: AppColors.ink, brightness: brightness).copyWith(
    // Claro: botões petróleo. Escuro: botões âmbar (mais contraste).
    primary: isDark ? AppColors.amber : AppColors.ink,
    onPrimary: isDark ? AppColors.ink : Colors.white,
    secondary: AppColors.amber,
    onSecondary: AppColors.ink,
    // A barra de navegação usa estas duas para o item selecionado.
    secondaryContainer: AppColors.amber,
    onSecondaryContainer: AppColors.ink,
    error: kml.negative,
    surface: kml.panel,
    onSurface: isDark ? const Color(0xFFE8EFF0) : const Color(0xFF1B2B2F),
    onSurfaceVariant: kml.muted,
  );

  const radius = BorderRadius.all(Radius.circular(12));
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    extensions: [kml],
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: onBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: onBackground),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kml.panel,
      border: border(kml.line),
      enabledBorder: border(kml.line),
      focusedBorder: border(scheme.primary, 2),
      errorBorder: border(kml.negative),
      focusedErrorBorder: border(kml.negative, 2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: kml.panel),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.amber,
      foregroundColor: AppColors.ink,
    ),
  );
}
