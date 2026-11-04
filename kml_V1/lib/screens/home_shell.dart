import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'fuelings_screen.dart';
import 'trips_screen.dart';

/// Estrutura principal: 4 abas com navegação inferior (fácil de alcançar com o polegar).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack mantém cada aba viva (filtros e rolagem preservados).
      body: IndexedStack(index: _index, children: const [
        DashboardScreen(),
        TripsScreen(),
        FuelingsScreen(),
        ExpensesScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Painel'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'Viagens'),
          NavigationDestination(icon: Icon(Icons.local_gas_station_outlined), selectedIcon: Icon(Icons.local_gas_station), label: 'Abastecer'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Despesas'),
        ],
      ),
    );
  }
}
