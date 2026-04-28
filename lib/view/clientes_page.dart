import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final _searchController = TextEditingController();
  final _documentController = TextEditingController();
  bool _isCnpj = false;

  late MaskTextInputFormatter _documentFormatter;

  @override
  void initState() {
    super.initState();
    _documentFormatter = _buildFormatter();
  }

  MaskTextInputFormatter _buildFormatter() {
    return MaskTextInputFormatter(
      mask: _isCnpj ? '##.###.###/####-##' : '###.###.###-##',
      filter: {'#': RegExp(r'[0-9]')},
    );
  }

  void _toggleTipoPessoa(bool? value) {
    final rawText = _documentFormatter.getUnmaskedText();

    setState(() {
      _isCnpj = value ?? false;
      _documentFormatter = _buildFormatter();
      final formatted = _documentFormatter.maskText(rawText);
      _documentController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Pesquisar por nome ou documento',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _documentController,
                  inputFormatters: [_documentFormatter],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _isCnpj ? 'CNPJ' : 'CPF',
                    helperText: 'Mascara dinamica com base na selecao.',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Checkbox(
                    value: _isCnpj,
                    onChanged: _toggleTipoPessoa,
                  ),
                  const Text('CNPJ'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Exemplo de formulario. O CRUD deve consumir DatabaseHelper.insertCliente, updateCliente, deleteCliente e searchClientes.',
            ),
          ),
        ],
      ),
    );
  }
}
