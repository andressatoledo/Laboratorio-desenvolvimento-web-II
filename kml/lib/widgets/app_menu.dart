import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../screens/catalog_screen.dart';
import '../screens/vehicles_screen.dart';
import '../state/app_state.dart';
import '../state/settings.dart';

/// Botão ☰ para a barra superior (abre o menu lateral à direita).
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) => Builder(
        builder: (ctx) => IconButton(
          tooltip: 'Menu',
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
        ),
      );
}

/// Menu lateral: cadastros no alto e configurações (tema) embaixo.
class AppMenuDrawer extends StatelessWidget {
  const AppMenuDrawer({super.key});

  /// Fecha o menu, abre a tela e atualiza os dados ao voltar.
  /// O Navigator é capturado ANTES de fechar o menu (o contexto do menu
  /// deixa de existir depois).
  Future<void> _open(BuildContext context, Widget screen) async {
    final nav = Navigator.of(context);
    nav.pop();
    await nav.push(MaterialPageRoute(builder: (_) => screen));
    AppState.instance.dataChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _section(context, 'Cadastros'),
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('Veículos'),
            onTap: () => _open(context, const VehiclesScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categorias e modalidades'),
            onTap: () => _open(context, const CatalogScreen()),
          ),
          const Spacer(),
          const Divider(height: 1),
          _section(context, 'Configurações'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: Settings.themeMode,
                builder: (context, mode, _) => SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Escuro')),
                      ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => Settings.setThemeMode(s.first),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.kml.muted)),
      );
}
