import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatters.dart';
import '../core/validators.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Cadastro/edição de abastecimento. Ao salvar, a despesa de combustível
/// é criada/atualizada automaticamente (sem lançar duas vezes).
class FuelingFormScreen extends StatefulWidget {
  const FuelingFormScreen({super.key, this.fueling});
  final Fueling? fueling;

  @override
  State<FuelingFormScreen> createState() => _FuelingFormScreenState();
}

class _FuelingFormScreenState extends State<FuelingFormScreen> {
  final _form = GlobalKey<FormState>();
  final _liters = TextEditingController();
  final _total = TextEditingController();
  final _odo = TextEditingController();
  final _app = AppState.instance;

  int? _vehicleId;
  DateTime _date = Fmt.today();
  bool _fullTank = true;
  bool _saving = false;
  int? _lastOdo; // dica: última quilometragem do veículo

  bool get _editing => widget.fueling != null;

  @override
  void initState() {
    super.initState();
    final f = widget.fueling;
    if (f != null) {
      _vehicleId = f.vehicleId;
      _date = f.date;
      _liters.text = Fmt.input(f.liters);
      _total.text = Fmt.moneyPlain(f.totalCents);
      _odo.text = '${f.odometerKm}';
      _fullTank = f.fullTank;
    } else {
      _vehicleId = _app.filters.vehicleId ?? (_app.vehicles.isEmpty ? null : _app.vehicles.first.id);
    }
    _loadLastOdo();
  }

  @override
  void dispose() {
    for (final c in [_liters, _total, _odo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLastOdo() async {
    if (_vehicleId == null) return;
    final v = await _app.repo.lastOdometer(_vehicleId!);
    if (mounted) setState(() => _lastOdo = v);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _app.repo.saveFueling(Fueling(
        id: widget.fueling?.id,
        vehicleId: _vehicleId!,
        date: _date,
        liters: Parse.decimal(_liters.text)!,
        totalCents: Parse.cents(_total.text),
        odometerKm: int.parse(_odo.text.trim()),
        fullTank: _fullTank,
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
        title: 'Excluir abastecimento?',
        message: 'A despesa de combustível gerada por ele também será excluída.');
    if (!ok) return;
    try {
      await _app.repo.deleteFueling(widget.fueling!.id!);
      _app.dataChanged();
      if (mounted) Navigator.pop(context);
    } on AppException catch (e) {
      if (mounted) showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar abastecimento' : 'Novo abastecimento'),
        actions: [
          if (_editing)
            IconButton(tooltip: 'Excluir abastecimento', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: _app.vehicles.isEmpty
          ? const NoVehicleNotice()
          : Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                VehicleDropdown(
                  value: _vehicleId,
                  locked: _editing,
                  onChanged: (v) {
                    setState(() => _vehicleId = v);
                    _loadLastOdo();
                  },
                ),
                gap,
                DateFormField(initialDate: _date, onChanged: (d) => _date = d),
                gap,
                DecimalField(controller: _liters, label: 'Litros abastecidos', suffix: 'L', min: 0.1, max: 2000),
                gap,
                MoneyField(controller: _total, label: 'Valor pago'),
                gap,
                // Preço por litro calculado automaticamente (total ÷ litros).
                ListenableBuilder(
                  listenable: Listenable.merge([_liters, _total]),
                  builder: (context, _) {
                    final l = Parse.decimal(_liters.text);
                    final c = Parse.cents(_total.text);
                    final price = (l != null && l > 0 && c > 0) ? Fmt.money((c / l).round()) : '—';
                    return Panel(
                      child: Row(children: [
                        const Expanded(child: Text('Preço por litro', style: TextStyle(fontWeight: FontWeight.w600))),
                        Text(price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      ]),
                    );
                  },
                ),
                gap,
                TextFormField(
                  controller: _odo,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                  decoration: InputDecoration(
                    labelText: 'Quilometragem do veículo',
                    suffixText: 'km',
                    helperText: _lastOdo == null ? null : 'Último registro: ${Fmt.qty(_lastOdo!.toDouble())} km',
                  ),
                  validator: (v) => V.integer(v, label: 'a quilometragem', min: 0, max: 9999999),
                ),
                gap,
                SwitchListTile(
                  value: _fullTank,
                  onChanged: (v) => setState(() => _fullTank = v),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('Completei o tanque'),
                  subtitle: const Text('Necessário para calcular o consumo médio (km/L).'),
                ),
                gap,
                SaveButton(saving: _saving, onPressed: _save),
              ]),
            ),
    );
  }
}
