import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../models/cliente.dart';
import '../services/database_helper.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _clientesFuture;

  @override
  void initState() {
    super.initState();
    _clientesFuture = DatabaseHelper.instance.getClientes();
    _searchController.addListener(_refreshClientes);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshClientes)
      ..dispose();
    super.dispose();
  }

  void _refreshClientes() {
    setState(() {
      _clientesFuture = DatabaseHelper.instance.searchClientes(
        _searchController.text,
      );
    });
  }

  Future<void> _abrirCadastroCliente() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CadastroClientePage()),
    );

    if (created == true) {
      _refreshClientes();
    }
  }

  Future<void> _abrirEdicaoCliente(Map<String, dynamic> cliente) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CadastroClientePage(clienteInicial: cliente),
      ),
    );

    if (updated == true) {
      _refreshClientes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Pesquisar por nome, documento ou telefone',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _clientesFuture,
                  builder: (context, snapshot) {
                    final clientes = snapshot.data ?? [];

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        clientes.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (clientes.isEmpty) {
                      return const Center(
                        child: Text('Nenhum cliente cadastrado ainda.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: clientes.length,
                      itemBuilder: (context, index) {
                        final cliente = clientes[index];
                        final telefones = (cliente['telefones'] as String?) ?? '-';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFD9A441),
                              child: Text(
                                (cliente['nome'] as String).substring(0, 1),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(cliente['nome'] as String),
                            subtitle: Text(
                              '${cliente['tipo_pessoa']}: ${cliente['documento']}\nTelefone: $telefones',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _abrirEdicaoCliente(cliente),
                            ),
                            onTap: () => _abrirEdicaoCliente(cliente),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _abrirCadastroCliente,
            icon: const Icon(Icons.add),
            label: const Text('Cadastrar Cliente'),
          ),
        ),
      ],
    );
  }
}

class CadastroClientePage extends StatefulWidget {
  final Map<String, dynamic>? clienteInicial;

  const CadastroClientePage({
    super.key,
    this.clienteInicial,
  });

  @override
  State<CadastroClientePage> createState() => _CadastroClientePageState();
}

class _CadastroClientePageState extends State<CadastroClientePage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _documentController = TextEditingController();
  final _telefoneController = TextEditingController();
  bool _isSaving = false;
  bool _isCnpj = false;

  late MaskTextInputFormatter _documentFormatter;
  late MaskTextInputFormatter _telefoneFormatter;

  @override
  void initState() {
    super.initState();
    if (widget.clienteInicial != null) {
      final cliente = widget.clienteInicial!;
      _isCnpj = (cliente['tipo_pessoa'] as String?) == 'CNPJ';
      _nomeController.text = cliente['nome'] as String? ?? '';
      _documentController.text = cliente['documento'] as String? ?? '';
      final telefone = ((cliente['telefones'] as String?) ?? '')
          .split(' | ')
          .first
          .trim();
      _telefoneController.text = telefone;
    }
    _documentFormatter = _buildDocumentFormatter();
    _telefoneFormatter = MaskTextInputFormatter(
      mask: '(##) #####-####',
      filter: {'#': RegExp(r'[0-9]')},
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _documentController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  MaskTextInputFormatter _buildDocumentFormatter() {
    return MaskTextInputFormatter(
      mask: _isCnpj ? '##.###.###/####-##' : '###.###.###-##',
      filter: {'#': RegExp(r'[0-9]')},
    );
  }

  void _toggleTipoPessoa(bool? value) {
    final rawText = _documentFormatter.getUnmaskedText();

    setState(() {
      _isCnpj = value ?? false;
      _documentFormatter = _buildDocumentFormatter();
      final formatted = _documentFormatter.maskText(rawText);
      _documentController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  Future<void> _salvarCliente() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final cliente = Cliente(
        id: widget.clienteInicial?['id'] as int?,
        nome: _nomeController.text.trim(),
        documento: _documentController.text.trim(),
        tipoPessoa: _isCnpj ? 'CNPJ' : 'CPF',
      );

      if (widget.clienteInicial == null) {
        await DatabaseHelper.instance.insertCliente(
          cliente,
          [_telefoneController.text.trim()],
        );
      } else {
        await DatabaseHelper.instance.updateCliente(
          cliente,
          [_telefoneController.text.trim()],
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel salvar o cliente: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.clienteInicial != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Cliente' : 'Cadastrar Cliente'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nomeController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome do cliente'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome do cliente.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _documentController,
                        inputFormatters: [_documentFormatter],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _isCnpj ? 'CNPJ' : 'CPF',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o documento.';
                          }
                          return null;
                        },
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefoneController,
                  inputFormatters: [_telefoneFormatter],
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o telefone.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _salvarCliente,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving
                        ? 'Salvando...'
                        : isEditing
                            ? 'Salvar Alteracoes'
                            : 'Salvar Cliente',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
