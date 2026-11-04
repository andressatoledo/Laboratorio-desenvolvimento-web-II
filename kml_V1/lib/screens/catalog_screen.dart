import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/validators.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Categorias de despesa e modalidades de remuneração.
/// Itens padrão do sistema ficam protegidos (cadeado); os criados pelo
/// usuário podem ser excluídos se nunca foram usados.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _repo = AppState.instance.repo;
  late Future<(List<Category>, List<PayMode>)> _future = _load();

  Future<(List<Category>, List<PayMode>)> _load() async => (await _repo.categories(), await _repo.payModes());

  void _refresh() => setState(() => _future = _load());

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      _refresh();
    } on AppException catch (e) {
      if (mounted) showError(context, e.message);
    }
  }

  Future<void> _addCategory() async {
    final r = await showFieldsDialog(context, title: 'Nova categoria', fields: [
      DialogField(label: 'Nome', maxLength: 30, validator: (v) => V.text(v, label: 'o nome', max: 30)),
    ]);
    if (r != null) await _run(() async => _repo.addCategory(r[0]));
  }

  Future<void> _addMode() async {
    final r = await showFieldsDialog(context, title: 'Nova modalidade', fields: [
      DialogField(label: 'Nome', maxLength: 30, validator: (v) => V.text(v, label: 'o nome', max: 30)),
      DialogField(
          label: 'Unidade de cobrança',
          hint: 'ex.: saca, hora',
          maxLength: 12,
          caps: TextCapitalization.none,
          validator: (v) => V.text(v, label: 'a unidade', max: 12)),
    ]);
    if (r != null) await _run(() async => _repo.addPayMode(r[0], r[1]));
  }

  Future<void> _confirmDelete(String name, Future<void> Function() delete) async {
    if (await confirmDialog(context, title: 'Excluir "$name"?', message: 'Esta ação não pode ser desfeita.')) {
      await _run(delete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias e modalidades')),
      body: FutureBuilder<(List<Category>, List<PayMode>)>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (cats, modes) = snap.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            _header('Categorias de despesa', _addCategory),
            for (final c in cats)
              _row(c.name, locked: c.isFuel, onDelete: () => _confirmDelete(c.name, () => _repo.deleteCategory(c.id))),
            const SizedBox(height: 24),
            _header('Modalidades de remuneração', _addMode),
            for (final m in modes)
              _row(m.name,
                  subtitle: 'Unidade: ${m.unit}',
                  locked: !m.isCustom,
                  onDelete: () => _confirmDelete(m.name, () => _repo.deletePayMode(m.id))),
          ]);
        },
      ),
    );
  }

  Widget _header(String title, VoidCallback onAdd) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Adicionar')),
        ]),
      );

  Widget _row(String name, {String? subtitle, required bool locked, required VoidCallback onDelete}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 16)),
                if (subtitle != null) Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ]),
            ),
            if (locked)
              const Tooltip(message: 'Item padrão do sistema', child: Icon(Icons.lock_outline, color: AppColors.muted))
            else
              IconButton(tooltip: 'Excluir $name', icon: const Icon(Icons.delete_outline), onPressed: onDelete),
          ]),
        ),
      );
}
