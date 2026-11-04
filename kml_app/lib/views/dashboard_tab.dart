class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KmlProvider>(context);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo Financeiro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Receita Total', currency.format(provider.receitaTotal), Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCard('Despesas Totais', currency.format(provider.despesasTotais), Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          _buildMetricCard(
            'Lucro Estimado',
            currency.format(provider.lucroEstimado),
            provider.lucroEstimado >= 0 ? Colors.blue.shade800 : Colors.orange.shade800,
            isHighlight: true,
          ),
          const SizedBox(height: 20),
          const Text('Desempenho Operacional', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildSmallCard('Consumo Médio', '${provider.consumoMedioKmL.toStringAsFixed(2)} km/L', Icons.speed),
              _buildSmallCard('Custo por KM', currency.format(provider.custoMedioPorKm), Icons.attach_money),
              _buildSmallCard('Gastos Combustível', currency.format(provider.gastosCombustivel), Icons.local_gas_station),
              _buildSmallCard('Viagens Feitas', '${provider.qtdViagens}', Icons.alt_route),
              _buildSmallCard('Lucro / Viagem', currency.format(provider.lucroMedioPorViagem), Icons.trending_up),
              _buildSmallCard('Total Toneladas', '${provider.totalToneladas.toStringAsFixed(1)} t', Icons.scale),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, {bool isHighlight = false}) {
    return Card(
      color: isHighlight ? color.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(0.4), width: isHighlight ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: isHighlight ? 22 : 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.blueAccent),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}