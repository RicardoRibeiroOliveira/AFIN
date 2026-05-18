import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/conta_financeira.dart';
import '../services/database_helper.dart';

class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  final _clienteFilterController = TextEditingController();
  String _tipoAtual = 'Receber';
  String? _grupoSelecionado;
  String _situacaoSelecionada = 'todas';
  late Future<List<Map<String, dynamic>>> _contasFuture;
  late Future<List<String>> _gruposFuture;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _clienteFilterController.addListener(_carregarDados);
  }

  @override
  void dispose() {
    _clienteFilterController
      ..removeListener(_carregarDados)
      ..dispose();
    super.dispose();
  }

  void _carregarDados() {
    setState(() {
      _contasFuture = DatabaseHelper.instance.getContasByTipo(
        _tipoAtual,
        grupo: _grupoSelecionado,
        clienteQuery: _clienteFilterController.text,
        situacao: _situacaoSelecionada,
      );
      _gruposFuture = DatabaseHelper.instance.getGruposByTipo(_tipoAtual);
    });
  }

  void _atualizarTipo(String tipo) {
    setState(() {
      _tipoAtual = tipo;
      _grupoSelecionado = null;
      _contasFuture = DatabaseHelper.instance.getContasByTipo(
        _tipoAtual,
        clienteQuery: _clienteFilterController.text,
        situacao: _situacaoSelecionada,
      );
      _gruposFuture = DatabaseHelper.instance.getGruposByTipo(_tipoAtual);
    });
  }

  Future<void> _abrirAcoesAdicionar() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final grupoLabel =
            _tipoAtual == 'Receber'
                ? 'Cadastrar grupo de recebimento'
                : 'Cadastrar grupo de pagamento';
        final contaLabel =
            _tipoAtual == 'Receber'
                ? 'Cadastrar conta a receber'
                : 'Cadastrar conta a pagar';

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(contaLabel),
                onTap: () {
                  Navigator.of(context).pop();
                  _abrirCadastroConta();
                },
              ),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(grupoLabel),
                onTap: () {
                  Navigator.of(context).pop();
                  _abrirCadastroGrupo();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _abrirCadastroConta({Map<String, dynamic>? contaInicial}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => CadastroContaPage(
              tipo: _tipoAtual,
              contaInicial: contaInicial,
            ),
      ),
    );

    if (changed == true) {
      _carregarDados();
    }
  }

  Future<void> _abrirCadastroGrupo() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CadastroGrupoPage(tipo: _tipoAtual)),
    );

    if (changed == true) {
      _carregarDados();
    }
  }

  Future<void> _marcarConta(Map<String, dynamic> conta) async {
    final valorInicial =
        (conta['valor'] as num).toStringAsFixed(2).replaceAll('.', ',');
    final formatter = MaskTextInputFormatter(
      mask: '###.###.###,##',
      filter: {'#': RegExp(r'[0-9]')},
    );
    final controller = TextEditingController(
      text: formatter.maskText(valorInicial),
    );

    DateTime dataPagamento = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final acao = _tipoAtual == 'Receber' ? 'Receber' : 'Pagar';
            final dataFormatada = DateFormat(
              'dd/MM/yyyy',
            ).format(dataPagamento);

            return AlertDialog(
              title: Text('$acao conta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    inputFormatters: [formatter],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          _tipoAtual == 'Receber'
                              ? 'Valor recebido'
                              : 'Valor pago',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data do lancamento'),
                    subtitle: Text(dataFormatada),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: dataPagamento,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (selected != null) {
                        setDialogState(() => dataPagamento = selected);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(acao),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final valor = _parseCurrency(controller.text);
    await DatabaseHelper.instance.marcarContaComoPagaOuRecebida(
      contaId: conta['id'] as int,
      valorRecebido: valor,
      dataPagamento: dataPagamento,
    );
    _carregarDados();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    const situacoes = <Map<String, String>>[
      {'value': 'todas', 'label': 'Todas'},
      {'value': 'aberto', 'label': 'Em aberto'},
      {'value': 'pago', 'label': 'Pago'},
      {'value': 'vencido', 'label': 'Vencido'},
    ];

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _tipoAtual,
                  decoration: const InputDecoration(
                    labelText: 'Tipo atual',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Receber', child: Text('Receber')),
                    DropdownMenuItem(value: 'Pagar', child: Text('Pagar')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _atualizarTipo(value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _clienteFilterController,
                  decoration: const InputDecoration(
                    hintText: 'Filtrar por cliente, CPF/CNPJ ou telefone',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children:
                        situacoes.map((situacao) {
                          final value = situacao['value']!;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(situacao['label']!),
                              selected: _situacaoSelecionada == value,
                              onSelected: (_) {
                                setState(() => _situacaoSelecionada = value);
                                _carregarDados();
                              },
                            ),
                          );
                        }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<String>>(
                  future: _gruposFuture,
                  builder: (context, snapshot) {
                    final grupos = snapshot.data ?? const <String>[];
                    return SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('Todos os grupos'),
                              selected: _grupoSelecionado == null,
                              onSelected: (_) {
                                setState(() => _grupoSelecionado = null);
                                _carregarDados();
                              },
                            ),
                          ),
                          ...grupos.map(
                            (grupo) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(grupo),
                                selected: _grupoSelecionado == grupo,
                                onSelected: (_) {
                                  setState(() => _grupoSelecionado = grupo);
                                  _carregarDados();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _contasFuture,
                    builder: (context, snapshot) {
                      final contas = snapshot.data ?? const [];

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          contas.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (contas.isEmpty) {
                        return const Center(
                          child: Text('Nenhuma conta cadastrada para este tipo.'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: contas.length,
                        itemBuilder: (context, index) {
                          final conta = contas[index];
                          final vencimento = DateFormat('dd/MM/yyyy').format(
                            DateTime.parse(conta['data_vencimento'] as String),
                          );
                          final isPago = conta['status'] == 'Pago';
                          final acaoLabel =
                              _tipoAtual == 'Receber' ? 'Receber' : 'Pagar';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _abrirCadastroConta(contaInicial: conta),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            conta['cliente_nome'] as String? ??
                                                'Cliente',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Grupo: ${conta['grupo']}'),
                                          if ((conta['descricao'] as String?) !=
                                                  null &&
                                              (conta['descricao'] as String)
                                                  .trim()
                                                  .isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                conta['descricao'] as String,
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Vencimento: $vencimento | Status: ${conta['status']}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: 88,
                                        maxWidth: 112,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            currency.format(conta['valor']),
                                            textAlign: TextAlign.end,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(
                                                  minWidth: 32,
                                                  minHeight: 32,
                                                ),
                                                tooltip: 'Editar conta',
                                                onPressed:
                                                    () => _abrirCadastroConta(
                                                      contaInicial: conta,
                                                    ),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(
                                                  minWidth: 32,
                                                  minHeight: 32,
                                                ),
                                                tooltip:
                                                    isPago
                                                        ? 'Conta concluida'
                                                        : '$acaoLabel conta',
                                                onPressed:
                                                    isPago
                                                        ? null
                                                        : () => _marcarConta(conta),
                                                icon: Icon(
                                                  isPago
                                                      ? Icons.check_circle_outline
                                                      : _tipoAtual == 'Receber'
                                                      ? Icons
                                                          .arrow_circle_down_outlined
                                                      : Icons
                                                          .arrow_circle_up_outlined,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
              onPressed: _abrirAcoesAdicionar,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
            ),
          ),
        ],
      ),
    );
  }
}

class CadastroContaPage extends StatefulWidget {
  final String tipo;
  final Map<String, dynamic>? contaInicial;

  const CadastroContaPage({
    super.key,
    required this.tipo,
    this.contaInicial,
  });

  @override
  State<CadastroContaPage> createState() => _CadastroContaPageState();
}

class _CadastroContaPageState extends State<CadastroContaPage> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _currencyFormatter = MaskTextInputFormatter(
    mask: '###.###.###,##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  bool _isSaving = false;
  DateTime _dataEmissao = DateTime.now();
  DateTime _dataVencimento = DateTime.now();
  Map<String, dynamic>? _clienteSelecionado;
  String? _grupoSelecionado;
  String? _anexoPath;
  late Future<List<String>> _gruposFuture;

  bool get _isEditing => widget.contaInicial != null;

  @override
  void initState() {
    super.initState();
    final conta = widget.contaInicial;

    if (conta != null) {
      _descricaoController.text = conta['descricao'] as String? ?? '';
      _valorController.text = _formatCurrency((conta['valor'] as num).toDouble());
      _dataEmissao = DateTime.parse(conta['data_emissao'] as String);
      _dataVencimento = DateTime.parse(conta['data_vencimento'] as String);
      _grupoSelecionado = conta['grupo'] as String?;
      _anexoPath = conta['foto_path'] as String?;
      _clienteSelecionado = {
        'id': conta['cliente_id'],
        'nome': conta['cliente_nome'],
        'documento': conta['documento'],
        'telefones': conta['telefones'],
      };
    }

    _gruposFuture = DatabaseHelper.instance.getGruposByTipo(widget.tipo);
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _selecionarCliente() async {
    final cliente = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const SelecionarClientePage()),
    );

    if (cliente != null) {
      setState(() => _clienteSelecionado = cliente);
    }
  }

  Future<void> _selecionarVencimento() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dataVencimento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null) {
      setState(() => _dataVencimento = selected);
    }
  }

  Future<void> _selecionarOrigemAnexo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da galeria'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tirar foto agora'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) {
      return;
    }

    final copiedPath = await _copiarAnexoLocal(file.path);
    setState(() => _anexoPath = copiedPath);
  }

  Future<String> _copiarAnexoLocal(String originalPath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final anexosDir = Directory(p.join(docsDir.path, 'anexos'));
    await anexosDir.create(recursive: true);

    final extension = p.extension(originalPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'anexo_$timestamp$extension';
    final targetPath = p.join(anexosDir.path, fileName);

    final copied = await File(originalPath).copy(targetPath);
    return copied.path;
  }

  Future<void> _salvarConta() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_clienteSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um cliente para continuar.')),
      );
      return;
    }

    if (_grupoSelecionado == null || _grupoSelecionado!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um grupo para a conta.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final conta = ContaFinanceira(
        id: widget.contaInicial?['id'] as int?,
        clienteId: _clienteSelecionado!['id'] as int,
        tipo: widget.tipo,
        grupo: _grupoSelecionado!,
        descricao: _descricaoController.text.trim(),
        valor: _parseCurrency(_valorController.text),
        dataEmissao:
            _isEditing
                ? widget.contaInicial!['data_emissao'] as String
                : _dataEmissao.toIso8601String(),
        dataVencimento: _dataVencimento.toIso8601String(),
        status: widget.contaInicial?['status'] as String? ?? 'Pendente',
        dataPagamento: widget.contaInicial?['data_pagamento'] as String?,
        valorRecebido: (widget.contaInicial?['valor_recebido'] as num?)
            ?.toDouble(),
        fotoPath: _anexoPath ?? widget.contaInicial?['foto_path'] as String?,
      );

      if (_isEditing) {
        await DatabaseHelper.instance.updateConta(conta);
      } else {
        await DatabaseHelper.instance.insertConta(conta);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel salvar a conta: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vencimentoFormatado = DateFormat(
      'dd/MM/yyyy',
    ).format(_dataVencimento);
    final emissaoFormatada = DateFormat('dd/MM/yyyy').format(_dataEmissao);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Editar Conta ${widget.tipo}'
              : 'Cadastrar Conta ${widget.tipo}',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: _selecionarCliente,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Cliente',
                      suffixIcon: Icon(Icons.search),
                    ),
                    child: Text(
                      _clienteSelecionado == null
                          ? 'Selecione o cliente'
                          : _clienteSelecionado!['nome'] as String,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<String>>(
                  future: _gruposFuture,
                  builder: (context, snapshot) {
                    final grupos = snapshot.data ?? const <String>[];
                    return DropdownButtonFormField<String>(
                      value:
                          grupos.contains(_grupoSelecionado)
                              ? _grupoSelecionado
                              : null,
                      decoration: const InputDecoration(labelText: 'Grupo'),
                      items:
                          grupos
                              .map(
                                (grupo) => DropdownMenuItem(
                                  value: grupo,
                                  child: Text(grupo),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() => _grupoSelecionado = value);
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Selecione um grupo.';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descricaoController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descricao da conta',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe a descricao da conta.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valorController,
                  inputFormatters: [_currencyFormatter],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Valor'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o valor.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data de emissao'),
                  child: Text(emissaoFormatada),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dia de vencimento'),
                  subtitle: Text(vencimentoFormatado),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _selecionarVencimento,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _selecionarOrigemAnexo,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _anexoPath == null ? 'Adicionar anexo' : 'Trocar anexo',
                  ),
                ),
                if (_anexoPath != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Anexo: ${p.basename(_anexoPath!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _salvarConta,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving
                        ? 'Salvando...'
                        : _isEditing
                        ? 'Salvar Alteracoes'
                        : 'Salvar Conta',
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

class CadastroGrupoPage extends StatefulWidget {
  final String tipo;

  const CadastroGrupoPage({
    super.key,
    required this.tipo,
  });

  @override
  State<CadastroGrupoPage> createState() => _CadastroGrupoPageState();
}

class _CadastroGrupoPageState extends State<CadastroGrupoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _salvarGrupo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await DatabaseHelper.instance.insertGrupo(
        nome: _nomeController.text.trim(),
        tipo: widget.tipo,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel salvar o grupo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.tipo == 'Receber'
            ? 'Cadastrar Grupo de Recebimento'
            : 'Cadastrar Grupo de Pagamento';

    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nomeController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome do grupo'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome do grupo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _salvarGrupo,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Salvando...' : 'Salvar Grupo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SelecionarClientePage extends StatefulWidget {
  const SelecionarClientePage({super.key});

  @override
  State<SelecionarClientePage> createState() => _SelecionarClientePageState();
}

class _SelecionarClientePageState extends State<SelecionarClientePage> {
  final _searchController = TextEditingController();
  String _filtroAtual = 'todos';
  late Future<List<Map<String, dynamic>>> _clientesFuture;

  @override
  void initState() {
    super.initState();
    _clientesFuture = DatabaseHelper.instance.searchClientes('');
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
        filtro: _filtroAtual,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecionar Cliente')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Pesquisar cliente',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _FiltroClienteChip(
                    label: 'Todos',
                    value: 'todos',
                    currentValue: _filtroAtual,
                    onSelected: (value) {
                      setState(() => _filtroAtual = value);
                      _refreshClientes();
                    },
                  ),
                  _FiltroClienteChip(
                    label: 'Nome',
                    value: 'nome',
                    currentValue: _filtroAtual,
                    onSelected: (value) {
                      setState(() => _filtroAtual = value);
                      _refreshClientes();
                    },
                  ),
                  _FiltroClienteChip(
                    label: 'CPF/CNPJ',
                    value: 'documento',
                    currentValue: _filtroAtual,
                    onSelected: (value) {
                      setState(() => _filtroAtual = value);
                      _refreshClientes();
                    },
                  ),
                  _FiltroClienteChip(
                    label: 'Telefone',
                    value: 'telefone',
                    currentValue: _filtroAtual,
                    onSelected: (value) {
                      setState(() => _filtroAtual = value);
                      _refreshClientes();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _clientesFuture,
                  builder: (context, snapshot) {
                    final clientes = snapshot.data ?? const [];

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        clientes.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (clientes.isEmpty) {
                      return const Center(
                        child: Text('Nenhum cliente encontrado.'),
                      );
                    }

                    return ListView.builder(
                      itemCount: clientes.length,
                      itemBuilder: (context, index) {
                        final cliente = clientes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(cliente['nome'] as String),
                            subtitle: Text(
                              '${cliente['documento']}\n${cliente['telefones'] ?? '-'}',
                            ),
                            isThreeLine: true,
                            onTap: () => Navigator.of(context).pop(cliente),
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
      ),
    );
  }
}

class _FiltroClienteChip extends StatelessWidget {
  final String label;
  final String value;
  final String currentValue;
  final ValueChanged<String> onSelected;

  const _FiltroClienteChip({
    required this.label,
    required this.value,
    required this.currentValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: currentValue == value,
      onSelected: (_) => onSelected(value),
    );
  }
}

double _parseCurrency(String value) {
  final normalized = value.replaceAll('.', '').replaceAll(',', '.').trim();
  return double.tryParse(normalized) ?? 0;
}

String _formatCurrency(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}
