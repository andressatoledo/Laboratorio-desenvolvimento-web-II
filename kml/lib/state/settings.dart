import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências do usuário (hoje: tema claro/escuro/sistema).
/// O MaterialApp escuta [themeMode] e troca o tema na hora.
class Settings {
  static const _key = 'theme_mode';
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  static Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      themeMode.value = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Sem preferência salva (ou erro de leitura): segue o tema do sistema.
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode; // aplica imediatamente
    try {
      await (await SharedPreferences.getInstance()).setString(_key, mode.name);
    } catch (_) {
      // Falha ao salvar não impede o uso; só não persiste.
    }
  }
}
