import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Abertura e esquema do banco SQLite.
///
/// Decisões de modelagem:
///  - Dinheiro sempre em CENTAVOS (INTEGER): sem erros de arredondamento.
///  - Datas em texto ISO (yyyy-MM-dd): ordenam e filtram corretamente.
///  - Chaves estrangeiras ligadas (RESTRICT) + CHECKs + triggers: o próprio
///    banco recusa dados inconsistentes, mesmo que a interface falhe.
///  - Abastecimento gera SUA despesa de combustível automaticamente
///    (expenses.fueling_id), então o gasto nunca é contado duas vezes.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _version = 1;
  Future<Database>? _opening;

  /// Garante uma única abertura, mesmo com chamadas simultâneas.
  Future<Database> get db => _opening ??= _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'kml.db');
    return openDatabase(
      path,
      version: _version,
      // Sem isto o SQLite ignora as chaves estrangeiras.
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      // Futuras migrações entram aqui, comparando old/new version.
      onUpgrade: (d, oldVersion, newVersion) async {},
    );
  }

  static const _datePattern = "'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'";

  Future<void> _onCreate(Database d, int version) async {
    // Veículos: nome único; placa opcional e única (NULL pode repetir).
    await d.execute('''
      CREATE TABLE vehicles(
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT NOT NULL COLLATE NOCASE UNIQUE
              CHECK(length(trim(name)) BETWEEN 1 AND 40),
        plate TEXT UNIQUE CHECK(plate IS NULL OR length(plate) = 7)
      )''');

    // Modalidades de remuneração (tonelada, diária, km, fixo ou criadas pelo usuário).
    await d.execute('''
      CREATE TABLE pay_modes(
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE
             CHECK(length(trim(name)) BETWEEN 1 AND 30),
        kind TEXT NOT NULL CHECK(kind IN ('ton','day','km','fixed','custom')),
        unit TEXT NOT NULL CHECK(length(trim(unit)) BETWEEN 1 AND 12)
      )''');

    // Categorias de despesa. Só uma pode ser "combustível" (índice parcial abaixo).
    await d.execute('''
      CREATE TABLE expense_categories(
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        name    TEXT NOT NULL COLLATE NOCASE UNIQUE
                CHECK(length(trim(name)) BETWEEN 1 AND 30),
        is_fuel INTEGER NOT NULL DEFAULT 0 CHECK(is_fuel IN (0,1))
      )''');
    await d.execute(
        'CREATE UNIQUE INDEX ux_category_fuel ON expense_categories(is_fuel) WHERE is_fuel = 1');

    // Viagens: valor total = quantidade x valor unitário (calculado no app).
    await d.execute('''
      CREATE TABLE trips(
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id       INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
        pay_mode_id      INTEGER NOT NULL REFERENCES pay_modes(id) ON DELETE RESTRICT,
        date             TEXT NOT NULL CHECK(date GLOB $_datePattern),
        origin           TEXT NOT NULL CHECK(length(trim(origin)) BETWEEN 2 AND 80),
        destination      TEXT NOT NULL CHECK(length(trim(destination)) BETWEEN 2 AND 80),
        distance_km      REAL NOT NULL CHECK(distance_km > 0 AND distance_km <= 100000),
        quantity         REAL NOT NULL CHECK(quantity > 0),
        unit_value_cents INTEGER NOT NULL CHECK(unit_value_cents > 0),
        amount_cents     INTEGER NOT NULL CHECK(amount_cents > 0),
        notes            TEXT CHECK(notes IS NULL OR length(notes) <= 200)
      )''');

    // Abastecimentos. A quilometragem não se repete no mesmo veículo.
    await d.execute('''
      CREATE TABLE fuelings(
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id  INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
        date        TEXT NOT NULL CHECK(date GLOB $_datePattern),
        liters      REAL NOT NULL CHECK(liters > 0 AND liters <= 2000),
        total_cents INTEGER NOT NULL CHECK(total_cents > 0),
        odometer_km INTEGER NOT NULL CHECK(odometer_km >= 0 AND odometer_km <= 9999999),
        full_tank   INTEGER NOT NULL DEFAULT 1 CHECK(full_tank IN (0,1)),
        UNIQUE(vehicle_id, odometer_km)
      )''');

    // Despesas. trip_id é opcional (apagar a viagem NÃO apaga a despesa).
    // fueling_id liga a despesa ao abastecimento que a originou (apagar o
    // abastecimento apaga a despesa junto).
    await d.execute('''
      CREATE TABLE expenses(
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id   INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
        category_id  INTEGER NOT NULL REFERENCES expense_categories(id) ON DELETE RESTRICT,
        trip_id      INTEGER REFERENCES trips(id) ON DELETE SET NULL,
        fueling_id   INTEGER UNIQUE REFERENCES fuelings(id) ON DELETE CASCADE,
        date         TEXT NOT NULL CHECK(date GLOB $_datePattern),
        amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
        description  TEXT CHECK(description IS NULL OR length(description) <= 120)
      )''');

    // Índices para os filtros por período e veículo.
    await d.execute('CREATE INDEX ix_trips_date ON trips(date, vehicle_id)');
    await d.execute('CREATE INDEX ix_expenses_date ON expenses(date, vehicle_id)');
    await d.execute('CREATE INDEX ix_fuelings_date ON fuelings(vehicle_id, odometer_km)');

    // --- Triggers de integridade (regras que um CHECK simples não alcança) ---

    // Despesa e viagem vinculada devem ser do mesmo veículo.
    for (final op in ['INSERT', 'UPDATE OF vehicle_id, trip_id']) {
      await d.execute('''
        CREATE TRIGGER trg_expense_trip_${op.startsWith('I') ? 'ins' : 'upd'}
        BEFORE $op ON expenses
        WHEN NEW.trip_id IS NOT NULL
         AND (SELECT vehicle_id FROM trips WHERE id = NEW.trip_id) <> NEW.vehicle_id
        BEGIN SELECT RAISE(ABORT, 'KML_VEICULO'); END''');
    }
    // A viagem não pode trocar de veículo se já tem despesas vinculadas.
    await d.execute('''
      CREATE TRIGGER trg_trip_vehicle_upd BEFORE UPDATE OF vehicle_id ON trips
      WHEN NEW.vehicle_id <> OLD.vehicle_id
       AND EXISTS (SELECT 1 FROM expenses WHERE trip_id = OLD.id)
      BEGIN SELECT RAISE(ABORT, 'KML_VEICULO'); END''');

    // Despesa de combustível só existe ligada a um abastecimento (e vice-versa).
    for (final op in ['INSERT', 'UPDATE OF category_id, fueling_id']) {
      await d.execute('''
        CREATE TRIGGER trg_expense_fuel_${op.startsWith('I') ? 'ins' : 'upd'}
        BEFORE $op ON expenses
        WHEN (SELECT is_fuel FROM expense_categories WHERE id = NEW.category_id)
             <> (NEW.fueling_id IS NOT NULL)
        BEGIN SELECT RAISE(ABORT, 'KML_COMBUSTIVEL'); END''');
    }

    // --- Dados iniciais (únicos, sem lixo) ---
    final b = d.batch();
    b.insert('vehicles', {'name': 'Meu veículo'});
    b.insert('pay_modes', {'name': 'Por tonelada', 'kind': 'ton', 'unit': 't'});
    b.insert('pay_modes', {'name': 'Por diária', 'kind': 'day', 'unit': 'diária'});
    b.insert('pay_modes', {'name': 'Por quilômetro', 'kind': 'km', 'unit': 'km'});
    b.insert('pay_modes', {'name': 'Valor fixo', 'kind': 'fixed', 'unit': 'viagem'});
    b.insert('expense_categories', {'name': 'Combustível', 'is_fuel': 1});
    for (final n in ['Pedágio', 'Alimentação', 'Manutenção', 'Outros']) {
      b.insert('expense_categories', {'name': n});
    }
    await b.commit(noResult: true);
  }
}
