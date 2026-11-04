import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'catalog_screen.dart';
import 'expense_form_screen.dart';
import 'fueling_form_screen.dart';
import 'trip_form_screen.dart';
import 'vehicles_screen.dart';

/// Painel financeiro: indicadores do período e veículo filtrados.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('KML'),
          Text('Quilômetros e lucratividade',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.muted)),
        ]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (v) => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => v == 'vehicles' ? const VehiclesScreen() : const CatalogScreen()),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'vehicles', child: Text('Veículos')),
              PopupMenuItem(value: 'catalog', child: Text('Categorias e modalidades')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        const FilterBar(),
        Expanded(
          child: DataView<Summary>(
            load: () => app.repo.summary(app.filters),
            builder: (context, s) => _DashboardBody(s: s),
          ),
        ),
      ]),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.s});
  final Summary s;

  @override
  Widget build(BuildContext context) {
    final noData = s.tripCount == 0 && s.expensesCents == 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _Hero(s: s),
        const SizedBox(height: 12),
        // Atalhos de cadastro rápido.
        Row(children: [
          Expanded(child: _QuickAction(Icons.route, 'Viagem', () => _open(context, const TripFormScreen()))),
          const SizedBox(width: 8),
          Expanded(child: _QuickAction(Icons.local_gas_station, 'Abastecer', () => _open(context, const FuelingFormScreen()))),
          const SizedBox(width: 8),
          Expanded(child: _QuickAction(Icons.receipt_long, 'Despesa', () => _open(context, const ExpenseFormScreen()))),
        ]),
        if (noData) ...[
          const SizedBox(height: 12),
          const Panel(
            child: Text('Nada registrado neste período. Use os atalhos acima para começar '
                'ou altere o período no filtro.'),
          ),
        ],
        const SizedBox(height: 16),
        _metrics(),
        const SizedBox(height: 16),
        _modesPanel(),
        const SizedBox(height: 16),
        _categoriesPanel(),
      ],
    );
  }

  void _open(BuildContext c, Widget screen) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => screen));

  String _orDash(int? cents) => cents == null ? '—' : Fmt.money(cents);

  Widget _metrics() {
    final tiles = <(String, String, String?)>[
      ('Gasto com combustível', Fmt.money(s.fuelCents), null),
      ('Consumo médio', s.kmPerLiter == null ? '—' : '${Fmt.fixed(s.kmPerLiter!, 2)} km/L',
          s.kmPerLiter == null ? 'Requer 2 tanques cheios' : null),
      ('Custo por km rodado', _orDash(s.costPerKmCents), null),
      ('Viagens', '${s.tripCount}', null),
      ('Receita por viagem', _orDash(s.revenuePerTripCents), null),
      ('Lucro por viagem', _orDash(s.profitPerTripCents), null),
      ('Quilômetros rodados', '${Fmt.qty(s.km)} km', null),
      ('Toneladas transportadas', '${Fmt.qty(s.tons)} t', null),
    ];
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final t in tiles) SizedBox(width: w, child: _MetricTile(label: t.$1, value: t.$2, hint: t.$3)),
      ]);
    });
  }

  Widget _modesPanel() {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Receita média por modalidade',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (s.modes.isEmpty)
          const Text('Nenhuma viagem no período.', style: TextStyle(color: AppColors.muted))
        else
          for (final m in s.modes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(child: Text('${m.label} (${m.trips})')),
                Text(Fmt.money(m.averageCents), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
      ]),
    );
  }

  Widget _categoriesPanel() {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Despesas por categoria',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (s.categories.isEmpty)
          const Text('Nenhuma despesa no período.', style: TextStyle(color: AppColors.muted))
        else
          for (final c in s.categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(c.name)),
                  Text('${Fmt.money(c.totalCents)}  ·  ${(c.totalCents * 100 / s.expensesCents).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: c.totalCents / s.expensesCents,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: AppColors.line,
                  color: AppColors.ink,
                ),
              ]),
            ),
      ]),
    );
  }
}

/// Destaque do painel: o lucro, com uma faixa tracejada de "pista" abaixo.
class _Hero extends StatelessWidget {
  const _Hero({required this.s});
  final Summary s;

  @override
  Widget build(BuildContext context) {
    final negative = s.profitCents < 0;
    return Panel(
      color: AppColors.ink,
      borderColor: AppColors.ink,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Lucro estimado', style: TextStyle(color: Colors.white70, fontSize: 15)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(Fmt.money(s.profitCents),
              style: TextStyle(
                  color: negative ? const Color(0xFFFFB4AB) : Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 16),
        const _LaneDivider(),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _HeroFigure('Receita', Fmt.money(s.revenueCents))),
          Expanded(child: _HeroFigure('Despesas', Fmt.money(s.expensesCents))),
        ]),
      ]),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 2),
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
      ]);
}

class _LaneDivider extends StatelessWidget {
  const _LaneDivider();
  @override
  Widget build(BuildContext context) =>
      const ExcludeSemantics(child: CustomPaint(size: Size(double.infinity, 4), painter: _LanePainter()));
}

class _LanePainter extends CustomPainter {
  const _LanePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.amber
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (double x = 0; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, 2), Offset(x + 14, 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Icon(icon, color: AppColors.ink),
          const SizedBox(height: 4),
          Text('+ $label', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, this.hint});
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 6),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
          if (hint != null) Text(hint!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      );
}
