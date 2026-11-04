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

  void setPeriod(DateTime from, DateTime to) {
    filters = filters.copyWith(from: from, to: to);
    notifyListeners();
  }

  void setVehicle(int? id) {
    filters = id == null ? filters.copyWith(clearVehicle: true) : filters.copyWith(vehicleId: id);
    notifyListeners();
  }

  /// Chamar após qualquer gravação/exclusão para atualizar as telas.
  void dataChanged() => notifyListeners();
}
