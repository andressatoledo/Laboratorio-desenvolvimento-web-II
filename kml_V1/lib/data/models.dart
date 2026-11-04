import '../core/formatters.dart';

/// Filtro global (período + veículo) usado por painel e listas.
class Filters {
  const Filters({required this.from, required this.to, this.vehicleId});

  final DateTime from;
  final DateTime to;
  final int? vehicleId; // null = todos os veículos

  factory Filters.currentMonth() {
    final n = DateTime.now();
    return Filters(from: DateTime(n.year, n.month, 1), to: DateTime(n.year, n.month + 1, 0));
  }

  Filters copyWith({DateTime? from, DateTime? to, int? vehicleId, bool clearVehicle = false}) =>
      Filters(
        from: from ?? this.from,
        to: to ?? this.to,
        vehicleId: clearVehicle ? null : (vehicleId ?? this.vehicleId),
      );
}

class Vehicle {
  const Vehicle({this.id, required this.name, this.plate});
  final int? id;
  final String name;
  final String? plate;

  factory Vehicle.fromMap(Map<String, Object?> m) =>
      Vehicle(id: m['id'] as int, name: m['name'] as String, plate: m['plate'] as String?);

  Map<String, Object?> toMap() => {'name': name.trim(), 'plate': plate};
}

/// Modalidade de remuneração. [kind] define quais campos o formulário pede.
class PayMode {
  const PayMode({required this.id, required this.name, required this.kind, required this.unit});
  final int id;
  final String name;
  final String kind; // ton | day | km | fixed | custom
  final String unit;

  factory PayMode.fromMap(Map<String, Object?> m) => PayMode(
      id: m['id'] as int, name: m['name'] as String, kind: m['kind'] as String, unit: m['unit'] as String);

  bool get isCustom => kind == 'custom';

  /// Pede quantidade ao usuário? (km usa a distância; fixo usa 1)
  bool get needsQuantity => kind == 'ton' || kind == 'day' || kind == 'custom';

  int get quantityDecimals => kind == 'ton' ? 3 : (kind == 'day' ? 1 : 2);

  String get quantityLabel => switch (kind) {
        'ton' => 'Toneladas transportadas',
        'day' => 'Número de diárias',
        _ => 'Quantidade ($unit)',
      };

  String get rateLabel => switch (kind) {
        'ton' => 'Valor por tonelada',
        'day' => 'Valor da diária',
        'km' => 'Valor por quilômetro',
        'fixed' => 'Valor da viagem',
        _ => 'Valor por $unit',
      };
}

class Category {
  const Category({required this.id, required this.name, required this.isFuel});
  final int id;
  final String name;
  final bool isFuel;

  factory Category.fromMap(Map<String, Object?> m) =>
      Category(id: m['id'] as int, name: m['name'] as String, isFuel: m['is_fuel'] == 1);
}

class Trip {
  const Trip({
    this.id,
    required this.vehicleId,
    required this.payModeId,
    required this.date,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.quantity,
    required this.unitValueCents,
    required this.amountCents,
    this.notes,
    this.modeKind = '',
    this.modeUnit = '',
    this.vehicleName = '',
  });

  final int? id;
  final int vehicleId;
  final int payModeId;
  final DateTime date;
  final String origin;
  final String destination;
  final double distanceKm;
  final double quantity;
  final int unitValueCents;
  final int amountCents;
  final String? notes;
  // Campos vindos do JOIN (somente leitura):
  final String modeKind;
  final String modeUnit;
  final String vehicleName;

  factory Trip.fromMap(Map<String, Object?> m) => Trip(
        id: m['id'] as int,
        vehicleId: m['vehicle_id'] as int,
        payModeId: m['pay_mode_id'] as int,
        date: Fmt.parseIso(m['date'] as String),
        origin: m['origin'] as String,
        destination: m['destination'] as String,
        distanceKm: (m['distance_km'] as num).toDouble(),
        quantity: (m['quantity'] as num).toDouble(),
        unitValueCents: m['unit_value_cents'] as int,
        amountCents: m['amount_cents'] as int,
        notes: m['notes'] as String?,
        modeKind: (m['mode_kind'] as String?) ?? '',
        modeUnit: (m['mode_unit'] as String?) ?? '',
        vehicleName: (m['vehicle_name'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {
        'vehicle_id': vehicleId,
        'pay_mode_id': payModeId,
        'date': Fmt.iso(date),
        'origin': origin.trim(),
        'destination': destination.trim(),
        'distance_km': distanceKm,
        'quantity': quantity,
        'unit_value_cents': unitValueCents,
        'amount_cents': amountCents,
        'notes': (notes == null || notes!.trim().isEmpty) ? null : notes!.trim(),
      };

  /// Resumo de como o valor foi calculado, para a lista.
  String get detail => switch (modeKind) {
        'ton' => '${Fmt.qty(quantity)} t × ${Fmt.money(unitValueCents)}',
        'day' => '${Fmt.qty(quantity)} diária(s) × ${Fmt.money(unitValueCents)}',
        'km' => '${Fmt.money(unitValueCents)} por km',
        'fixed' => 'Valor fixo',
        _ => '${Fmt.qty(quantity)} $modeUnit × ${Fmt.money(unitValueCents)}',
      };
}

class Fueling {
  const Fueling({
    this.id,
    required this.vehicleId,
    required this.date,
    required this.liters,
    required this.totalCents,
    required this.odometerKm,
    required this.fullTank,
    this.vehicleName = '',
  });

  final int? id;
  final int vehicleId;
  final DateTime date;
  final double liters;
  final int totalCents;
  final int odometerKm;
  final bool fullTank;
  final String vehicleName;

  /// Preço por litro derivado (total ÷ litros), em centavos.
  int get pricePerLiterCents => (totalCents / liters).round();

  factory Fueling.fromMap(Map<String, Object?> m) => Fueling(
        id: m['id'] as int,
        vehicleId: m['vehicle_id'] as int,
        date: Fmt.parseIso(m['date'] as String),
        liters: (m['liters'] as num).toDouble(),
        totalCents: m['total_cents'] as int,
        odometerKm: m['odometer_km'] as int,
        fullTank: m['full_tank'] == 1,
        vehicleName: (m['vehicle_name'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {
        'vehicle_id': vehicleId,
        'date': Fmt.iso(date),
        'liters': liters,
        'total_cents': totalCents,
        'odometer_km': odometerKm,
        'full_tank': fullTank ? 1 : 0,
      };
}

class Expense {
  const Expense({
    this.id,
    required this.vehicleId,
    required this.categoryId,
    this.tripId,
    this.fuelingId,
    required this.date,
    required this.amountCents,
    this.description,
    this.categoryName = '',
    this.vehicleName = '',
    this.tripLabel,
  });

  final int? id;
  final int vehicleId;
  final int categoryId;
  final int? tripId;
  final int? fuelingId; // != null: despesa gerada por um abastecimento
  final DateTime date;
  final int amountCents;
  final String? description;
  final String categoryName;
  final String vehicleName;
  final String? tripLabel;

  bool get isFromFueling => fuelingId != null;

  factory Expense.fromMap(Map<String, Object?> m) {
    final origin = m['trip_origin'] as String?;
    return Expense(
      id: m['id'] as int,
      vehicleId: m['vehicle_id'] as int,
      categoryId: m['category_id'] as int,
      tripId: m['trip_id'] as int?,
      fuelingId: m['fueling_id'] as int?,
      date: Fmt.parseIso(m['date'] as String),
      amountCents: m['amount_cents'] as int,
      description: m['description'] as String?,
      categoryName: (m['category_name'] as String?) ?? '',
      vehicleName: (m['vehicle_name'] as String?) ?? '',
      tripLabel: origin == null ? null : '$origin → ${m['trip_destination']}',
    );
  }

  Map<String, Object?> toMap() => {
        'vehicle_id': vehicleId,
        'category_id': categoryId,
        'trip_id': tripId,
        'fueling_id': fuelingId,
        'date': Fmt.iso(date),
        'amount_cents': amountCents,
        'description': (description == null || description!.trim().isEmpty) ? null : description!.trim(),
      };
}

/// Média de receita por unidade de cada modalidade usada no período.
class ModeAverage {
  const ModeAverage({required this.kind, required this.unit, required this.trips, required this.revenueCents, required this.quantity});
  final String kind;
  final String unit;
  final int trips;
  final int revenueCents;
  final double quantity;

  String get label => switch (kind) {
        'ton' => 'Média por tonelada',
        'day' => 'Média por diária',
        'km' => 'Média por quilômetro',
        'fixed' => 'Média por viagem (valor fixo)',
        _ => 'Média por $unit',
      };

  /// Receita ÷ quantidade, em centavos (ex.: R$/t).
  int get averageCents => quantity <= 0 ? 0 : (revenueCents / quantity).round();
}

class CategoryTotal {
  const CategoryTotal(this.name, this.totalCents);
  final String name;
  final int totalCents;
}

/// Todos os indicadores do painel para o período filtrado.
class Summary {
  const Summary({
    required this.tripCount,
    required this.revenueCents,
    required this.expensesCents,
    required this.fuelCents,
    required this.km,
    required this.tons,
    required this.kmPerLiter,
    required this.modes,
    required this.categories,
  });

  final int tripCount;
  final int revenueCents;
  final int expensesCents;
  final int fuelCents;
  final double km;
  final double tons;
  final double? kmPerLiter; // null = dados insuficientes
  final List<ModeAverage> modes;
  final List<CategoryTotal> categories;

  int get profitCents => revenueCents - expensesCents;
  int? get revenuePerTripCents => tripCount == 0 ? null : (revenueCents / tripCount).round();
  int? get profitPerTripCents => tripCount == 0 ? null : (profitCents / tripCount).round();
  int? get costPerKmCents => km <= 0 ? null : (expensesCents / km).round();
}
