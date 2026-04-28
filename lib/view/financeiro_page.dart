import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';

class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  String _tipoSelecionado = 'Receber';

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Tipo atual: $_tipoSelecionado'),
            trailing: const Icon(Icons.unfold_less),
            onTap: () async {
              final tipo = await showModalBottomSheet<String>(
                context: context,
                builder: (context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.trending_down),
                          title: const Text('Contas a Receber'),
                          onTap: () => Navigator.pop(context, 'Receber'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.trending_up),
                          title: const Text('Contas a Pagar'),
                          onTap: () => Navigator.pop(context, 'Pagar'),
                        ),
                      ],
                    ),
                  );
                },
              );

              if (tipo != null) {
                setState(() => _tipoSelecionado = tipo);
              }
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.getContasByTipo(_tipoSelecionado),
            builder: (context, snapshot) {
              final contas = snapshot.data ?? [];

              if (contas.isEmpty) {
                return const Center(
                  child: Text('Nenhuma conta encontrada para o filtro atual.'),
                );
              }

              return ListView.builder(
                itemCount: contas.length,
                itemBuilder: (context, index) {
                  final conta = contas[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(conta['cliente_nome'] as String),
                      subtitle: Text(
                        'Status: ${conta['status']} | Emissao: ${conta['data_emissao']}',
                      ),
                      trailing: Text(
                        currency.format(conta['valor']),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
