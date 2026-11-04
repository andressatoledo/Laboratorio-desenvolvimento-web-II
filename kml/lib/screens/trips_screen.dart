import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/app_menu.dart';
import '../widgets/common.dart';
import 'trip_form_screen.dart';

/// Consulta de viagens (filtradas por período/veículo). Toque para editar.
class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Viagens'), actions: const [MenuButton()]),
      endDrawer: const AppMenuDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // evita conflito entre os botões das abas
        onPressed: () => openScreen(context, const TripFormScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Nova viagem'),
      ),
      body: Column(children: [
        const FilterBar(),
        Expanded(
          child: DataView<List<Trip>>(
            load: () => app.repo.trips(app.filters),
            builder: (context, trips) {
              if (trips.isEmpty) {
                return const EmptyState(
                  icon: Icons.route_outlined,
                  title: 'Nenhuma viagem neste período',
                  message: 'Toque em "Nova viagem" para registrar a primeira.',
                );
              }
              final total = trips.fold<int>(0, (s, t) => s + t.amountCents);
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: trips.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${trips.length} viagem(ns) · ${Fmt.money(total)}',
                          style: TextStyle(color: context.kml.muted)),
                    );
                  }
                  return _TripTile(trip: trips[i - 1], showVehicle: app.vehicles.length > 1);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip, required this.showVehicle});
  final Trip trip;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    final sub = [
      Fmt.date(trip.date),
      '${Fmt.qty(trip.distanceKm)} km',
      trip.detail,
      if (showVehicle) trip.vehicleName,
    ].join(' · ');
    return Panel(
      onTap: () => openScreen(context, TripFormScreen(trip: trip)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${trip.origin} → ${trip.destination}',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: context.kml.muted, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 12),
        Text(Fmt.money(trip.amountCents),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.kml.positive)),
      ]),
    );
  }
}
