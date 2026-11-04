import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/app_menu.dart';
import '../widgets/common.dart';
import 'fueling_form_screen.dart';

/// Lista de abastecimentos do período. Toque para editar.
class FuelingsScreen extends StatelessWidget {
  const FuelingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Abastecimentos'), actions: const [MenuButton()]),
      endDrawer: const AppMenuDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // evita conflito entre os botões das abas
        onPressed: () => openScreen(context, const FuelingFormScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Abastecer'),
      ),
      body: Column(children: [
        const FilterBar(),
        Expanded(
          child: DataView<List<Fueling>>(
            load: () => app.repo.fuelings(app.filters),
            builder: (context, list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.local_gas_station_outlined,
                  title: 'Nenhum abastecimento neste período',
                  message: 'Registre cada abastecimento para acompanhar o consumo médio.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final f = list[i];
                  final sub = [
                    Fmt.date(f.date),
                    '${Fmt.qty(f.liters)} L',
                    '${Fmt.money(f.pricePerLiterCents)}/L',
                    '${Fmt.qty(f.odometerKm.toDouble())} km',
                    if (!f.fullTank) 'parcial',
                    if (app.vehicles.length > 1) f.vehicleName,
                  ].join(' · ');
                  return Panel(
                    onTap: () => openScreen(context, FuelingFormScreen(fueling: f)),
                    child: Row(children: [
                      Expanded(child: Text(sub, style: const TextStyle(fontSize: 14))),
                      const SizedBox(width: 12),
                      Text(Fmt.money(f.totalCents),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.kml.negative)),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
