import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/validators.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Gerência de veículos: adicionar, editar e excluir (só se não houver registros).
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});
  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _app = AppState.instance;

  Future<void> _edit([Vehicle? v]) async {
    final r = await showFieldsDialog(context, title: v == null ? 'Novo veículo' : 'Editar veículo', fields: [
      DialogField(
          label: 'Nome',
          initial: v?.name ?? '',
          hint: 'ex.: Caminhão baú',
          validator: (x) => V.text(x, label: 'o nome', max: 40)),
      DialogField(
          label: 'Placa (opcional)',
          initial: v?.plate ?? '',
          maxLength: 8,
          hint: 'ABC1D23',
          caps: TextCapitalization.characters,
          validator: V.plate),
    ]);
    if (r == null) return;
    try {
      await _app.repo.saveVehicle(Vehicle(id: v?.id, name: r[0], plate: V.normalizePlate(r[1])));
      await _app.refreshVehicles();
      _app.dataChanged();
    } on AppException catch (e) {
      if (mounted) showError(context, e.message);
    }
  }

  Future<void> _delete(Vehicle v) async {
    final ok = await confirmDialog(context, title: 'Excluir "${v.name}"?', message: 'Esta ação não pode ser desfeita.');
    if (!ok) return;
    try {
      await _app.repo.deleteVehicle(v.id!);
      await _app.refreshVehicles();
    } on AppException catch (e) {
      if (mounted) showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veículos')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _edit, icon: const Icon(Icons.add), label: const Text('Novo veículo')),
      body: ListenableBuilder(
        listenable: _app,
        builder: (context, _) {
          final list = _app.vehicles;
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'Nenhum veículo',
                message: 'Cadastre um veículo para registrar viagens, abastecimentos e despesas.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = list[i];
              return Panel(
                onTap: () => _edit(v),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (v.plate != null)
                        Text(v.plate!, style: const TextStyle(color: AppColors.muted)),
                    ]),
                  ),
                  IconButton(
                      tooltip: 'Excluir ${v.name}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(v)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
