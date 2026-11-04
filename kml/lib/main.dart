import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/app_theme.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'state/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';

  await Settings.load(); // tema salvo

  try {
    // Abre (e cria, se preciso) o banco e carrega os veículos.
    await AppState.instance.init();
    runApp(const KmlApp());
  } catch (_) {
    // Falha ao abrir o banco: mostra uma mensagem em vez de tela em branco.
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Não foi possível abrir o banco de dados do aplicativo. '
              'Feche e abra o app novamente.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
  }
}

class KmlApp extends StatelessWidget {
  const KmlApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Reconstrói só o MaterialApp quando o tema muda.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: Settings.themeMode,
      builder: (context, mode, _) => _app(mode),
    );
  }

  Widget _app(ThemeMode mode) {
    return MaterialApp(
      title: 'KML',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}
