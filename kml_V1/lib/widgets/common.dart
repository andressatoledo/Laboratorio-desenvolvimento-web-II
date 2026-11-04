import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../core/validators.dart';
import '../state/app_state.dart';

// ===================================================================
// Mensagens e diálogos
// ===================================================================

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.negative,
      behavior: SnackBarBehavior.floating,
    ));
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirmLabel = 'Excluir'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class DialogField {
  const DialogField({
    required this.label,
    this.initial = '',
    this.validator,
    this.maxLength = 40,
    this.caps = TextCapitalization.sentences,
    this.hint,
  });
  final String label;
  final String initial;
  final String? Function(String?)? validator;
  final int maxLength;
  final TextCapitalization caps;
  final String? hint;
}

/// Diálogo com campos de texto validados. Devolve os valores ou null.
Future<List<String>?> showFieldsDialog(BuildContext context,
    {required String title, required List<DialogField> fields}) {
  return showDialog<List<String>>(
      context: context, builder: (_) => _FieldsDialog(title: title, fields: fields));
}

class _FieldsDialog extends StatefulWidget {
  const _FieldsDialog({required this.title, required this.fields});
  final String title;
  final List<DialogField> fields;
  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  final _key = GlobalKey<FormState>();
  late final _ctls = [for (final f in widget.fields) TextEditingController(text: f.initial)];

  @override
  void dispose() {
    for (final c in _ctls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < widget.fields.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: TextFormField(
                  controller: _ctls[i],
                  autofocus: i == 0,
                  textCapitalization: widget.fields[i].caps,
                  inputFormatters: [LengthLimitingTextInputFormatter(widget.fields[i].maxLength)],
                  decoration: InputDecoration(
                      labelText: widget.fields[i].label, hintText: widget.fields[i].hint),
                  validator: widget.fields[i].validator,
                ),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_key.currentState!.validate()) {
              Navigator.pop(context, [for (final c in _ctls) c.text.trim()]);
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// ===================================================================
// Blocos visuais
// ===================================================================

/// Contêiner padrão: fundo branco, borda fina, cantos arredondados.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.onTap,
    this.color = Colors.white,
    this.borderColor = AppColors.line,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 15)),
        ]),
      ),
    );
  }
}

/// Aviso exibido quando não há nenhum veículo cadastrado.
class NoVehicleNotice extends StatelessWidget {
  const NoVehicleNotice({super.key});
  @override
  Widget build(BuildContext context) => const EmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'Cadastre um veículo primeiro',
        message: 'No Painel, abra o menu e escolha "Veículos".',
      );
}

/// Carrega dados de forma assíncrona e recarrega sempre que o AppState
/// avisa de mudança (filtro alterado ou registro gravado/excluído).
class DataView<T> extends StatefulWidget {
  const DataView({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<DataView<T>> createState() => _DataViewState<T>();
}

class _DataViewState<T> extends State<DataView<T>> {
  late Future<T> _future = widget.load();

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_reload);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() => _future = widget.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData) return widget.builder(context, snap.data as T);
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Não foi possível carregar os dados.'),
              TextButton(onPressed: _reload, child: const Text('Tentar novamente')),
            ]),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

/// Barra de filtros: período e (se houver mais de um) veículo.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final app = AppState.instance;
        final f = app.filters;
        final vehicleName = f.vehicleId == null
            ? 'Todos os veículos'
            : app.vehicles.firstWhere((v) => v.id == f.vehicleId).name;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            ActionChip(
              avatar: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('${Fmt.date(f.from)} a ${Fmt.date(f.to)}'),
              onPressed: () => _pickPeriod(context),
            ),
            if (app.vehicles.length > 1) ...[
              const SizedBox(width: 8),
              PopupMenuButton<int>(
                tooltip: 'Filtrar por veículo',
                onSelected: (id) => app.setVehicle(id == 0 ? null : id),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 0, child: Text('Todos os veículos')),
                  for (final v in app.vehicles) PopupMenuItem(value: v.id!, child: Text(v.name)),
                ],
                child: Chip(
                    avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: Text(vehicleName)),
              ),
            ],
          ]),
        );
      },
    );
  }

  Future<void> _pickPeriod(BuildContext context) async {
    final now = DateTime.now();
    final presets = <(String, DateTime, DateTime)>[
      ('Este mês', DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0)),
      ('Mês passado', DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0)),
      ('Últimos 30 dias', DateTime(now.year, now.month, now.day - 29), DateTime(now.year, now.month, now.day)),
      ('Este ano', DateTime(now.year, 1, 1), DateTime(now.year, 12, 31)),
    ];
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < presets.length; i++)
            ListTile(title: Text(presets[i].$1), onTap: () => Navigator.pop(ctx, i)),
          ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Escolher datas'),
              onTap: () => Navigator.pop(ctx, -1)),
        ]),
      ),
    );
    if (choice == null) return;
    if (choice >= 0) {
      AppState.instance.setPeriod(presets[choice].$2, presets[choice].$3);
      return;
    }
    if (!context.mounted) return;
    final current = AppState.instance.filters;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: current.from, end: current.to),
      saveText: 'Aplicar',
    );
    if (range != null) AppState.instance.setPeriod(range.start, range.end);
  }
}

// ===================================================================
// Campos de formulário
// ===================================================================

/// Campo de dinheiro (R$), com validação de valor mínimo e máximo.
class MoneyField extends StatelessWidget {
  const MoneyField({super.key, required this.controller, required this.label, this.helper});
  final TextEditingController controller;
  final String label;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [CurrencyInputFormatter()],
      decoration: InputDecoration(labelText: label, prefixText: 'R\$ ', helperText: helper),
      validator: (v) => V.money(v, label: label),
    );
  }
}

/// Campo decimal (km, litros, toneladas...) com limites.
class DecimalField extends StatelessWidget {
  const DecimalField({
    super.key,
    required this.controller,
    required this.label,
    required this.min,
    required this.max,
    this.decimals = 2,
    this.suffix,
    this.helper,
  });
  final TextEditingController controller;
  final String label;
  final double min;
  final double max;
  final int decimals;
  final String? suffix;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [DecimalInputFormatter(maxDecimals: decimals)],
      decoration: InputDecoration(labelText: label, suffixText: suffix, helperText: helper),
      validator: (v) => V.decimal(v, label: label, min: min, max: max),
    );
  }
}

/// Campo de data que abre o calendário (não aceita data futura).
class DateFormField extends FormField<DateTime> {
  DateFormField({
    super.key,
    required DateTime initialDate,
    required ValueChanged<DateTime> onChanged,
    String label = 'Data',
  }) : super(
          initialValue: initialDate,
          validator: V.date,
          builder: (state) => InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showDatePicker(
                context: state.context,
                initialDate: state.value ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                state.didChange(picked);
                onChanged(picked);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                errorText: state.errorText,
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(Fmt.date(state.value ?? DateTime.now()),
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
        );
}

/// Seletor de veículo. Bloqueado ao editar (evita inconsistências).
class VehicleDropdown extends StatelessWidget {
  const VehicleDropdown({super.key, required this.value, required this.onChanged, required this.locked});
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Veículo',
        helperText: locked ? 'Para trocar o veículo, exclua e cadastre de novo.' : null,
      ),
      items: [
        for (final v in AppState.instance.vehicles)
          DropdownMenuItem(value: v.id, child: Text(v.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: locked ? null : onChanged,
      validator: (v) => v == null ? 'Escolha o veículo.' : null,
    );
  }
}

/// Botão principal de salvar, com indicador de progresso.
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.saving, required this.onPressed});
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: saving ? null : onPressed,
      child: saving
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
          : const Text('Salvar'),
    );
  }
}
