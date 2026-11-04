import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';

/// Estado global simples: filtro atual + lista de veículos.
/// As telas "escutam" este objeto e recarregam quando algo muda,
/// então painel e listas sempre se atualizam sozinhos.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  final Repository repo = Repository();
  Filters filters = Filters.currentMonth();
  List<Vehicle> vehicles = const [];

  /// Sobe a cada mudança (filtro, registro gravado, aba aberta). As telas
  /// comparam este número para saber se precisam recarregar os dados.
  int revision = 0;

  @override
  void notifyListeners() {
    revision++;
    super.notifyListeners();
  }

  Future<void> init() async {
    await repo.open();
    await refreshVehicles();
  }

  Future<void> refreshVehicles() async {
    vehicles = await repo.vehicles();
    // Se o veículo filtrado foi excluído, volta para "todos".
    if (filters.vehicleId != null && !vehicles.any((v) => v.id == filters.vehicleId)) {
      filters = filters.copyWith(clearVehicle: true);
    }
    notifyListeners();
  }

  /// Define o período. Garante datas "puras" (sem hora) e início <= fim,
  /// porque o banco compara datas como texto (yyyy-MM-dd).
  void setPeriod(DateTime from, DateTime to) {
    var a = DateTime(from.year, from.month, from.day);
    var b = DateTime(to.year, to.month, to.day);
    if (a.isAfter(b)) (a, b) = (b, a);
    if (a == filters.from && b == filters.to) return; // nada mudou
    filters = filters.copyWith(from: a, to: b);
    notifyListeners();
  }

  void setVehicle(int? id) {
    if (id == filters.vehicleId) return; // nada mudou
    filters = id == null ? filters.copyWith(clearVehicle: true) : filters.copyWith(vehicleId: id);
    notifyListeners();
  }

  /// Volta ao padrão: mês atual (calculado agora) e todos os veículos.
  void resetFilters() {
    filters = Filters.currentMonth();
    notifyListeners();
  }

  /// Chamar após qualquer gravação/exclusão para atualizar as telas.
  void dataChanged() => notifyListeners();
}
