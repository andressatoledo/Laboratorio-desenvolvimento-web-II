class DespesasTab extends StatelessWidget {
  const DespesasTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KmlProvider>(context);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      body: provider.despesas.isEmpty
          ? const Center(child: Text('Nenhuma despesa cadastrada.'))
          : ListView.builder(
              itemCount: provider.despesas.length,
              itemBuilder: (ctx, i) {
                final d = provider.despesas[i];
                return ListTile(
                  leading: const Icon(Icons.money_off, color: Colors.red),
                  title: Text(d.descricao),
                  subtitle: Text('${d.categoria} • ${DateFormat('dd/MM/yyyy').format(d.data)}'),
                  trailing: Text(currency.format(d.valor), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                );
              },
            ),
    );
  }
}