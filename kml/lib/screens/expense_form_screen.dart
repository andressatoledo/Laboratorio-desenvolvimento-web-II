import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatters.dart';
import '../core/validators.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Cadastro/edição de despesa (pedágio, alimentação, manutenção, etc.).
/// Combustível não aparece aqui: nasce do abastecimento.
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, this.expense});
  final Expense? expense;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final _app = AppState.instance;

  List<Category> _categories = [];
  List<Trip> _trips = [];
  int? _vehicleId;
  int? _categoryId;
  int? _tripId;
  DateTime _date = Fmt.today();
  bool _loading = true;
  bool _saving = false;

  bool get _editing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Combustível fica de fora: só é criado pelo abastecimento.
    _categories = (await _app.repo.categories()).where((c) => !c.isFuel).toList();
    final e = widget.expense;
    if (e != null) {
      _vehicleId = e.vehicleId;
      _categoryId = e.categoryId;
      _tripId = e.tripId;
      _date = e.date;
      _amount.text = Fmt.moneyPlain(e.amountCents);
      _desc.text = e.description ?? '';
    } else {
      _vehicleId = _app.filters.vehicleId ?? (_app.vehicles.isEmpty ? null : _app.vehicles.first.id);
    }
    await _loadTrips();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadTrips() async {
    if (_vehicleId == null) return;
    _trips = await _app.repo.tripsForLink(_vehicleId!, alsoId: widget.expense?.tripId);
    // Se a viagem escolhida não é do veículo atual, desfaz o vínculo.
    if (_tripId != null && !_trips.any((t) => t.id == _tripId)) _tripId = null;
    if (mounted) setState(() {});
  }

  Future<void> _addCategory() async {
    final r = await showFieldsDialog(context, title: 'Nova categoria', fields: [
      DialogField(label: 'Nome', maxLength: 30, validator: (v) => V.text(v, label: 'o nome', max: 30)),
    ]);
    if (r == null) return;
    try {
      final id = await _app.repo.addCategory(r[0]);
      _categories = (await _app.repo.categories()).where((c) => !c.isFuel).toList();
      if (mounted) setState(() => _categoryId = id);
    } on AppException catch (e) {
      if (mounted) showError(context, e.message);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _app.repo.saveExpense(Expense(
        id: widget.expense?.id,
        vehicleId: _vehicleId!,
        categoryId: _categoryId!,
        tripId: _tripId,
        date: _date,
        amountCents: Parse.cents(_amount.text),
        description: _desc.text,
      ));
      _app.dataChanged();
      if (mounted) Navigator.pop(context);
    } on AppException catch (e) {
      if (mounted) showError(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, title: 'Excluir despesa?', message: 'Esta ação não pode ser desfeita.');
    if (!ok) return;
    try {
      await _app.repo.deleteExpense(widget.expense!.id!);
      _app.dataChanged();
      if (mounted) Navigator.pop(context);
    } on AppException catch (e) {
      if (mounted) showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar despesa' : 'Nova despesa'),
        actions: [
          if (_editing)
            IconButton(tooltip: 'Excluir despesa', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _app.vehicles.isEmpty
              ? const NoVehicleNotice()
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    const gap = SizedBox(height: 16);
    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        VehicleDropdown(
          value: _vehicleId,
          locked: _editing,
          onChanged: (v) {
            _vehicleId = v;
            _loadTrips();
          },
        ),
        gap,
        DateFormField(initialDate: _date, onChanged: (d) => _date = d),
        gap,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              key: ValueKey('cat-$_categoryId'), // atualiza ao escolher/criar categoria
              value: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Categoria', helperText: 'Combustível é registrado na aba Abastecer.'),
              items: [for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'Escolha a categoria.' : null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Nova categoria',
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          ),
        ]),
        gap,
        MoneyField(controller: _amount, label: 'Valor'),
        gap,
        TextFormField(
          controller: _desc,
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
        ),
        gap,
        DropdownButtonFormField<int?>(
          key: ValueKey('trip-$_tripId-${_trips.length}'),
          value: _tripId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Viagem vinculada (opcional)'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Sem viagem')),
            for (final t in _trips)
              DropdownMenuItem<int?>(
                value: t.id,
                child: Text('${Fmt.dateShort(t.date)} · ${t.origin} → ${t.destination}',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _tripId = v),
        ),
        gap,
        SaveButton(saving: _saving, onPressed: _save),
      ]),
    );
  }
}
