import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/app_menu.dart';
import '../widgets/common.dart';
import 'expense_form_screen.dart';
import 'fueling_form_screen.dart';

/// Lista de despesas do período. Despesas de combustível abrem o
/// abastecimento de origem (única forma de editá-las).
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Despesas'), actions: const [MenuButton()]),
      endDrawer: const AppMenuDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // evita conflito entre os botões das abas
        onPressed: () => openScreen(context, const ExpenseFormScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Nova despesa'),
      ),
      body: Column(children: [
        const FilterBar(),
        Expanded(
          child: DataView<List<Expense>>(
            load: () => app.repo.expenses(app.filters),
            builder: (context, list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Nenhuma despesa neste período',
                  message: 'Registre pedágios, alimentação, manutenção e outros gastos.',
                );
              }
              final total = list.fold<int>(0, (s, e) => s + e.amountCents);
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: list.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${list.length} despesa(s) · ${Fmt.money(total)}',
                          style: TextStyle(color: context.kml.muted)),
                    );
                  }
                  final e = list[i - 1];
                  final sub = [
                    Fmt.date(e.date),
                    if (e.isFromFueling) 'Abastecimento',
                    if (e.description != null) e.description!,
                    if (e.tripLabel != null) e.tripLabel!,
                    if (app.vehicles.length > 1) e.vehicleName,
                  ].join(' · ');
                  return Panel(
                    onTap: () => e.isFromFueling
                        ? _openFueling(context, app, e)
                        : openScreen(context, ExpenseFormScreen(expense: e)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.categoryName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(sub, style: TextStyle(color: context.kml.muted, fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Text(Fmt.money(e.amountCents),
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

  /// Busca o abastecimento de origem e abre a edição dele.
  Future<void> _openFueling(BuildContext context, AppState app, Expense e) async {
    final all = await app.repo.fuelings(Filters(from: DateTime(2000), to: DateTime(2100), vehicleId: e.vehicleId));
    final f = all.where((x) => x.id == e.fuelingId);
    if (f.isNotEmpty && context.mounted) {
      openScreen(context, FuelingFormScreen(fueling: f.first));
    }
  }
}
