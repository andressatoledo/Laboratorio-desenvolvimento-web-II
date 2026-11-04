import 'package:sqflite/sqflite.dart';

import '../core/formatters.dart';
import 'app_database.dart';
import 'models.dart';

/// Erro com mensagem pronta para mostrar ao usuário.
class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Único ponto de acesso ao banco. Todas as consultas usam parâmetros (?),
/// nunca texto digitado concatenado: protege contra SQL injection.
/// Gravações compostas rodam em transação (ou tudo grava, ou nada grava).
class Repository {
  Future<Database> get _db => AppDatabase.instance.db;

  Future<void> open() async => _db;

  /// Converte erros do SQLite em mensagens compreensíveis.
  Future<T> _guard<T>(Future<T> Function() action, {String? inUse}) async {
    try {
      return await action();
    } on AppException {
      rethrow;
    } on DatabaseException catch (e) {
      final m = e.toString();
      if (m.contains('KML_VEICULO')) {
        throw AppException('A despesa e a viagem vinculada precisam ser do mesmo veículo.');
      }
      if (m.contains('KML_COMBUSTIVEL')) {
        throw AppException('Despesas de combustível são registradas na aba Abastecer.');
      }
      if (m.contains('FOREIGN KEY')) {
        throw AppException(inUse ?? 'Este item está em uso e não pode ser removido.');
      }
      if (m.contains('vehicles.plate')) throw AppException('Já existe um veículo com esta placa.');
      if (m.contains('vehicles.name')) throw AppException('Já existe um veículo com este nome.');
      if (m.contains('fuelings.')) {
        throw AppException('Já existe um abastecimento com esta quilometragem neste veículo.');
      }
      if (m.contains('UNIQUE')) throw AppException('Já existe um cadastro com este nome.');
      if (m.contains('CHECK')) throw AppException('Algum valor está fora dos limites permitidos.');
      throw AppException('Não foi possível concluir a operação. Tente novamente.');
    }
  }

  /// Cláusula de período/veículo reutilizada nas consultas. [a] = alias da tabela.
  (String, List<Object?>) _where(Filters f, String a) => (
        '$a.date BETWEEN ? AND ?${f.vehicleId != null ? ' AND $a.vehicle_id = ?' : ''}',
        <Object?>[Fmt.iso(f.from), Fmt.iso(f.to), if (f.vehicleId != null) f.vehicleId],
      );

  // ------------------------------------------------------------ Veículos
  Future<List<Vehicle>> vehicles() async {
    final rows = await (await _db).query('vehicles', orderBy: 'name COLLATE NOCASE');
    return rows.map(Vehicle.fromMap).toList();
  }

  Future<void> saveVehicle(Vehicle v) => _guard(() async {
        final db = await _db;
        if (v.id == null) {
          await db.insert('vehicles', v.toMap());
        } else {
          await db.update('vehicles', v.toMap(), where: 'id = ?', whereArgs: [v.id]);
        }
      });

  Future<void> deleteVehicle(int id) => _guard(
        () async => (await _db).delete('vehicles', where: 'id = ?', whereArgs: [id]),
        inUse: 'Este veículo tem viagens, despesas ou abastecimentos e não pode ser excluído.',
      );

  // ------------------------------------------- Modalidades e categorias
  Future<List<PayMode>> payModes() async {
    final rows = await (await _db).query('pay_modes', orderBy: 'id');
    return rows.map(PayMode.fromMap).toList();
  }

  Future<int> addPayMode(String name, String unit) => _guard(() async => (await _db)
      .insert('pay_modes', {'name': name.trim(), 'kind': 'custom', 'unit': unit.trim()}));

  Future<void> deletePayMode(int id) => _guard(
        () async => (await _db)
            .delete('pay_modes', where: 'id = ? AND kind = ?', whereArgs: [id, 'custom']),
        inUse: 'Esta modalidade já foi usada em viagens e não pode ser excluída.',
      );

  Future<List<Category>> categories() async {
    final rows = await (await _db).query('expense_categories', orderBy: 'is_fuel DESC, name COLLATE NOCASE');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> addCategory(String name) => _guard(() async =>
      (await _db).insert('expense_categories', {'name': name.trim(), 'is_fuel': 0}));

  Future<void> deleteCategory(int id) => _guard(
        () async => (await _db)
            .delete('expense_categories', where: 'id = ? AND is_fuel = 0', whereArgs: [id]),
        inUse: 'Esta categoria já foi usada em despesas e não pode ser excluída.',
      );

  // -------------------------------------------------------------- Viagens
  Future<List<Trip>> trips(Filters f) async {
    final (w, args) = _where(f, 't');
    final rows = await (await _db).rawQuery('''
      SELECT t.*, m.kind AS mode_kind, m.unit AS mode_unit, v.name AS vehicle_name
      FROM trips t
      JOIN pay_modes m ON m.id = t.pay_mode_id
      JOIN vehicles v ON v.id = t.vehicle_id
      WHERE $w ORDER BY t.date DESC, t.id DESC''', args);
    return rows.map(Trip.fromMap).toList();
  }

  /// Viagens do veículo para vincular a uma despesa (as 30 mais recentes,
  /// mais a já vinculada ao editar).
  Future<List<Trip>> tripsForLink(int vehicleId, {int? alsoId}) async {
    final rows = await (await _db).rawQuery('''
      SELECT * FROM trips WHERE vehicle_id = ? OR id = ?
      ORDER BY date DESC, id DESC LIMIT 31''', [vehicleId, alsoId ?? -1]);
    return rows.map(Trip.fromMap).where((t) => t.vehicleId == vehicleId || t.id == alsoId).toList();
  }

  Future<void> saveTrip(Trip t) => _guard(() async {
        final db = await _db;
        if (t.id == null) {
          await db.insert('trips', t.toMap());
        } else {
          await db.update('trips', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
        }
      });

  /// Despesas vinculadas permanecem (trip_id vira NULL).
  Future<void> deleteTrip(int id) =>
      _guard(() async => (await _db).delete('trips', where: 'id = ?', whereArgs: [id]));

  // ------------------------------------------------------------- Despesas
  Future<List<Expense>> expenses(Filters f) async {
    final (w, args) = _where(f, 'e');
    final rows = await (await _db).rawQuery('''
      SELECT e.*, c.name AS category_name, v.name AS vehicle_name,
             t.origin AS trip_origin, t.destination AS trip_destination
      FROM expenses e
      JOIN expense_categories c ON c.id = e.category_id
      JOIN vehicles v ON v.id = e.vehicle_id
      LEFT JOIN trips t ON t.id = e.trip_id
      WHERE $w ORDER BY e.date DESC, e.id DESC''', args);
    return rows.map(Expense.fromMap).toList();
  }

  Future<void> saveExpense(Expense e) => _guard(() async {
        // Despesas de abastecimento só mudam pelo próprio abastecimento.
        if (e.fuelingId != null) {
          throw AppException('Edite esta despesa pela aba Abastecer.');
        }
        final db = await _db;
        if (e.id == null) {
          await db.insert('expenses', e.toMap());
        } else {
          await db.update('expenses', e.toMap(),
              where: 'id = ? AND fueling_id IS NULL', whereArgs: [e.id]);
        }
      });

  Future<void> deleteExpense(int id) => _guard(() async => (await _db)
      .delete('expenses', where: 'id = ? AND fueling_id IS NULL', whereArgs: [id]));

  // -------------------------------------------------------- Abastecimentos
  Future<List<Fueling>> fuelings(Filters f) async {
    final (w, args) = _where(f, 'f');
    final rows = await (await _db).rawQuery('''
      SELECT f.*, v.name AS vehicle_name FROM fuelings f
      JOIN vehicles v ON v.id = f.vehicle_id
      WHERE $w ORDER BY f.date DESC, f.odometer_km DESC''', args);
    return rows.map(Fueling.fromMap).toList();
  }

  /// Maior quilometragem registrada do veículo (para dica no formulário).
  Future<int?> lastOdometer(int vehicleId) async {
    final r = await (await _db).rawQuery(
        'SELECT MAX(odometer_km) AS m FROM fuelings WHERE vehicle_id = ?', [vehicleId]);
    return r.first['m'] as int?;
  }

  /// Grava o abastecimento e a despesa de combustível correspondente na
  /// MESMA transação, mantendo os dois sempre sincronizados.
  Future<void> saveFueling(Fueling f) => _guard(() async {
        final db = await _db;
        await db.transaction((txn) async {
          // A quilometragem precisa crescer junto com a data.
          final iso = Fmt.iso(f.date);
          final bad = await txn.rawQuery('''
            SELECT COUNT(*) AS n FROM fuelings
            WHERE vehicle_id = ? AND id <> ?
              AND ((date < ? AND odometer_km >= ?) OR (date > ? AND odometer_km <= ?))''',
              [f.vehicleId, f.id ?? -1, iso, f.odometerKm, iso, f.odometerKm]);
          if (_i(bad.first['n']) > 0) {
            throw AppException(
                'A quilometragem não combina com os outros abastecimentos deste veículo: ela deve aumentar conforme a data.');
          }

          final cat = await txn.query('expense_categories', columns: ['id'], where: 'is_fuel = 1');
          final expenseValues = {
            'vehicle_id': f.vehicleId,
            'category_id': cat.first['id'],
            'date': iso,
            'amount_cents': f.totalCents,
          };

          if (f.id == null) {
            final id = await txn.insert('fuelings', f.toMap());
            await txn.insert('expenses', {...expenseValues, 'fueling_id': id});
          } else {
            await txn.update('fuelings', f.toMap(), where: 'id = ?', whereArgs: [f.id]);
            await txn.update('expenses', expenseValues, where: 'fueling_id = ?', whereArgs: [f.id]);
          }
        });
      });

  /// A despesa de combustível é removida junto (ON DELETE CASCADE).
  Future<void> deleteFueling(int id) =>
      _guard(() async => (await _db).delete('fuelings', where: 'id = ?', whereArgs: [id]));

  // --------------------------------------------------------------- Painel
  Future<Summary> summary(Filters f) async {
    final db = await _db;
    final (tw, ta) = _where(f, 't');
    final (ew, ea) = _where(f, 'e');

    final trip = (await db.rawQuery('''
      SELECT COUNT(*) AS n, COALESCE(SUM(amount_cents),0) AS rev,
             COALESCE(SUM(distance_km),0) AS km
      FROM trips t WHERE $tw''', ta)).first;

    final modeRows = await db.rawQuery('''
      SELECT m.kind, m.unit, COUNT(*) AS n, SUM(t.amount_cents) AS rev, SUM(t.quantity) AS qty
      FROM trips t JOIN pay_modes m ON m.id = t.pay_mode_id
      WHERE $tw GROUP BY m.id ORDER BY rev DESC''', ta);

    final catRows = await db.rawQuery('''
      SELECT c.name, c.is_fuel, SUM(e.amount_cents) AS total
      FROM expenses e JOIN expense_categories c ON c.id = e.category_id
      WHERE $ew GROUP BY c.id ORDER BY total DESC''', ea);

    var expenses = 0, fuel = 0, tons = 0.0;
    final categories = <CategoryTotal>[];
    for (final r in catRows) {
      final total = _i(r['total']);
      expenses += total;
      if (r['is_fuel'] == 1) fuel += total;
      categories.add(CategoryTotal(r['name'] as String, total));
    }
    final modes = <ModeAverage>[];
    for (final r in modeRows) {
      if (r['kind'] == 'ton') tons += _d(r['qty']);
      modes.add(ModeAverage(
        kind: r['kind'] as String,
        unit: r['unit'] as String,
        trips: _i(r['n']),
        revenueCents: _i(r['rev']),
        quantity: _d(r['qty']),
      ));
    }

    return Summary(
      tripCount: _i(trip['n']),
      revenueCents: _i(trip['rev']),
      expensesCents: expenses,
      fuelCents: fuel,
      km: _d(trip['km']),
      tons: tons,
      kmPerLiter: await _consumption(f),
      modes: modes,
      categories: categories,
    );
  }

  /// Consumo médio (km/L) pelo método do "tanque cheio":
  /// entre dois abastecimentos completos, km rodados ÷ litros colocados
  /// desde o anterior (inclui abastecimentos parciais no meio).
  /// Conta só trechos que TERMINAM dentro do período filtrado.
  Future<double?> _consumption(Filters f) async {
    final rows = await (await _db).rawQuery('''
      SELECT vehicle_id, date, liters, odometer_km, full_tank FROM fuelings
      ${f.vehicleId != null ? 'WHERE vehicle_id = ?' : ''}
      ORDER BY vehicle_id, odometer_km''', [if (f.vehicleId != null) f.vehicleId]);

    final from = Fmt.iso(f.from), to = Fmt.iso(f.to);
    var km = 0.0, liters = 0.0;
    int? vehicle, lastFullOdo;
    var litersSince = 0.0;

    for (final r in rows) {
      if (r['vehicle_id'] != vehicle) {
        vehicle = r['vehicle_id'] as int;
        lastFullOdo = null;
        litersSince = 0;
      }
      litersSince += _d(r['liters']);
      if (r['full_tank'] != 1) continue;
      final date = r['date'] as String;
      if (lastFullOdo != null && date.compareTo(from) >= 0 && date.compareTo(to) <= 0) {
        km += _i(r['odometer_km']) - lastFullOdo;
        liters += litersSince;
      }
      lastFullOdo = _i(r['odometer_km']);
      litersSince = 0;
    }
    return liters > 0 ? km / liters : null;
  }
}
