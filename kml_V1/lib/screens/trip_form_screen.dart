import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatters.dart';
import '../core/validators.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Cadastro/edição de viagem. Os campos de valor mudam conforme a
/// modalidade de remuneração e o total é calculado na hora.
class TripFormScreen extends StatefulWidget {
  const TripFormScreen({super.key, this.trip});
  final Trip? trip; // null = nova viagem

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final _form = GlobalKey<FormState>();
  final _origin = TextEditingController();
  final _dest = TextEditingController();
  final _dist = TextEditingController();
  final _qty = TextEditingController();
  final _rate = TextEditingController();
  final _notes = TextEditingController();

  final _app = AppState.instance;
  List<PayMode> _modes = [];
  PayMode? _mode;
  int? _vehicleId;
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  bool get _editing => widget.trip != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_origin, _dest, _dist, _qty, _rate, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    _modes = await _app.repo.payModes();
    final t = widget.trip;
    if (t != null) {
      _origin.text = t.origin;
      _dest.text = t.destination;
      _dist.text = Fmt.input(t.distanceKm);
      _qty.text = Fmt.input(t.quantity);
      _rate.text = Fmt.moneyPlain(t.unitValueCents);
      _notes.text = t.notes ?? '';
      _date = t.date;
      _vehicleId = t.vehicleId;
      _mode = _modes.firstWhere((m) => m.id == t.payModeId);
    } else {
      _vehicleId = _app.filters.vehicleId ?? (_app.vehicles.isEmpty ? null : _app.vehicles.first.id);
      _mode = _modes.first;
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Quantidade usada no cálculo conforme a modalidade.
  double _quantity(PayMode m) => switch (m.kind) {
        'fixed' => 1,
        'km' => Parse.decimal(_dist.text) ?? 0,
        _ => Parse.decimal(_qty.text) ?? 0,
      };

  int _amount(PayMode m) => (_quantity(m) * Parse.cents(_rate.text)).round();

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
    if (r == null) return;
    try {
      final id = await _app.repo.addPayMode(r[0], r[1]);
      _modes = await _app.repo.payModes();
      if (mounted) setState(() => _mode = _modes.firstWhere((m) => m.id == id));
    } on AppException catch (e) {
      if (mounted) showError(context, e.message);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final m = _mode!;
    final amount = _amount(m);
    if (amount < 1 || amount > V.maxCents) {
      showError(context, 'O total da viagem deve ficar entre R\$ 0,01 e R\$ 9.999.999,99.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _app.repo.saveTrip(Trip(
        id: widget.trip?.id,
        vehicleId: _vehicleId!,
        payModeId: m.id,
        date: _date,
        origin: _origin.text,
        destination: _dest.text,
        distanceKm: Parse.decimal(_dist.text)!,
        quantity: _quantity(m),
        unitValueCents: Parse.cents(_rate.text),
        amountCents: amount,
        notes: _notes.text,
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
    final ok = await confirmDialog(context,
        title: 'Excluir viagem?',
        message: 'As despesas vinculadas continuam registradas, apenas sem a viagem.');
    if (!ok) return;
    try {
      await _app.repo.deleteTrip(widget.trip!.id!);
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
        title: Text(_editing ? 'Editar viagem' : 'Nova viagem'),
        actions: [
          if (_editing)
            IconButton(tooltip: 'Excluir viagem', icon: const Icon(Icons.delete_outline), onPressed: _delete),
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
    final m = _mode!;
    const gap = SizedBox(height: 16);
    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        VehicleDropdown(value: _vehicleId, locked: _editing, onChanged: (v) => setState(() => _vehicleId = v)),
        gap,
        DateFormField(initialDate: _date, onChanged: (d) => _date = d),
        gap,
        TextFormField(
          controller: _origin,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          decoration: const InputDecoration(labelText: 'Origem'),
          validator: (v) => V.text(v, label: 'a origem', min: 2),
        ),
        gap,
        TextFormField(
          controller: _dest,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          decoration: const InputDecoration(labelText: 'Destino'),
          validator: (v) => V.text(v, label: 'o destino', min: 2),
        ),
        gap,
        DecimalField(controller: _dist, label: 'Distância percorrida', suffix: 'km', min: 0.1, max: 100000, decimals: 1),
        gap,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: DropdownButtonFormField<PayMode>(
              value: m,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Forma de remuneração'),
              items: [for (final x in _modes) DropdownMenuItem(value: x, child: Text(x.name))],
              onChanged: (v) => setState(() => _mode = v),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Nova modalidade',
            onPressed: _addMode,
            icon: const Icon(Icons.add),
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          ),
        ]),
        gap,
        if (m.needsQuantity) ...[
          DecimalField(
            controller: _qty,
            label: m.quantityLabel,
            min: m.kind == 'ton' ? 0.001 : 0.1,
            max: 9999999,
            decimals: m.quantityDecimals,
          ),
          gap,
        ],
        MoneyField(controller: _rate, label: m.rateLabel),
        gap,
        // Total recalculado a cada alteração de quantidade, valor ou distância.
        ListenableBuilder(
          listenable: Listenable.merge([_qty, _rate, _dist]),
          builder: (context, _) => Panel(
            child: Row(children: [
              const Expanded(child: Text('Valor total recebido', style: TextStyle(fontWeight: FontWeight.w600))),
              Text(Fmt.money(_amount(m)), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
        gap,
        TextFormField(
          controller: _notes,
          maxLines: 2,
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Observações (opcional)'),
        ),
        gap,
        SaveButton(saving: _saving, onPressed: _save),
      ]),
    );
  }
}
