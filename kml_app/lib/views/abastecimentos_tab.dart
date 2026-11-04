class AbastecimentosTab extends StatelessWidget {
  const AbastecimentosTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KmlProvider>(context);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      body: provider.abastecimentos.isEmpty
          ? const Center(child: Text('Nenhum abastecimento registrado.'))
          : ListView.builder(
              itemCount: provider.abastecimentos.length,
              itemBuilder: (ctx, i) {
                final a = provider.abastecimentos[i];
                return ListTile(
                  leading: const Icon(Icons.local_gas_station, color: Colors.orange),
                  title: Text('${a.litros.toStringAsFixed(1)} Litros'),
                  subtitle: Text('KM: ${a.kmAtual} • Preço/L: ${currency.format(a.precoPorLitro)}'),
                  trailing: Text(currency.format(a.valorTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
    );
  }
}