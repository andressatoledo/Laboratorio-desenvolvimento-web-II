class ViagensTab extends StatelessWidget {
  const ViagensTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KmlProvider>(context);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      body: provider.viagens.isEmpty
          ? const Center(child: Text('Nenhuma viagem cadastrada.'))
          : ListView.builder(
              itemCount: provider.viagens.length,
              itemBuilder: (ctx, i) {
                final v = provider.viagens[i];
                return Card(
                  margin: const EdgeInsets.horizontal(12, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.navigation)),
                    title: Text('${v.origem} ➔ ${v.destino}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${DateFormat('dd/MM/yyyy').format(v.data)} • ${v.distanciaKm} km • ${v.toneladas} t'),
                    trailing: Text(currency.format(v.valorRecebido), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioViagem(context),
        label: const Text('Nova Viagem'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _abrirFormularioViagem(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FormViagemModal(),
    );
  }
}

class FormViagemModal extends StatefulWidget {
  const FormViagemModal({super.key});

  @override
  State<FormViagemModal> createState() => _FormViagemModalState();
}

class _FormViagemModalState extends State<FormViagemModal> {
  final _formKey = GlobalKey<FormState>();
  final _origemCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  final _distanciaCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _toneladasCtrl = TextEditingController();
  String _modalidade = 'km_rodado';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20, left: 16, right: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cadastrar Viagem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _origemCtrl,
                decoration: const InputDecoration(labelText: 'Origem', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Informe a origem' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _destinoCtrl,
                decoration: const InputDecoration(labelText: 'Destino', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Informe o destino' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _distanciaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Distância (KM)', border: OutlineInputBorder()),
                      validator: (val) {
                        final n = double.tryParse(val ?? '');
                        if (n == null || n <= 0) return 'Distância inválida';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor Recebido (R\$)', border: OutlineInputBorder()),
                      validator: (val) {
                        final n = double.tryParse(val ?? '');
                        if (n == null || n <= 0) return 'Valor inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _toneladasCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Toneladas (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _modalidade,
                decoration: const InputDecoration(labelText: 'Modalidade de Pagamento', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'km_rodado', child: Text('Por KM Rodado')),
                  DropdownMenuItem(value: 'por_tonelada', child: Text('Por Tonelada')),
                  DropdownMenuItem(value: 'diaria', child: Text('Diária')),
                  DropdownMenuItem(value: 'valor_fixo', child: Text('Valor Fixo')),
                ],
                onChanged: (val) => setState(() => _modalidade = val!),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: _salvar,
                child: const Text('Salvar Viagem'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _salvar() async {
    if (_formKey.currentState!.validate()) {
      final novaViagem = Viagem(
        origem: _origemCtrl.text.trim(),
        destino: _destinoCtrl.text.trim(),
        data: DateTime.now(),
        distanciaKm: double.parse(_distanciaCtrl.text),
        valorRecebido: double.parse(_valorCtrl.text),
        modalidadeRemuneracao: _modalidade,
        toneladas: double.tryParse(_toneladasCtrl.text) ?? 0.0,
      );

      final ok = await Provider.of<KmlProvider>(context, listen: false).adicionarViagem(novaViagem);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Viagem salva com sucesso!' : 'Erro ao salvar viagem.')),
        );
      }
    }
  }
}