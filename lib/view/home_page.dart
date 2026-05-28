import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/backup_service.dart';
import '../services/database_helper.dart';
import 'clientes_page.dart';
import 'financeiro_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late Future<Map<String, double>> _resumoFuture;
  late Future<List<Map<String, dynamic>>> _lancamentosMesFuture;
  late Future<List<Map<String, dynamic>>> _lancamentosProximoMesFuture;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }

  void _refreshDashboard() {
    final now = DateTime.now();
    final mesInicio = DateTime(now.year, now.month, 1);
    final proximoMesInicio = DateTime(now.year, now.month + 1, 1);
    final mesSeguinteInicio = DateTime(now.year, now.month + 2, 1);
    _resumoFuture = DatabaseHelper.instance.getResumoMensal();
    _lancamentosMesFuture = DatabaseHelper.instance.getLancamentosPorPeriodo(
      start: mesInicio,
      end: proximoMesInicio,
    );
    _lancamentosProximoMesFuture =
        DatabaseHelper.instance.getLancamentosPorPeriodo(
          start: proximoMesInicio,
          end: mesSeguinteInicio,
        );
  }

  void _handleFinanceiroChanged() {
    if (!mounted) return;
    setState(_refreshDashboard);
  }

  Future<void> _criarBackup() async {
    try {
      final backupPath = await BackupService.instance.createBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup criado em: $backupPath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao criar backup: $e')),
      );
    }
  }

  Future<void> _restaurar() async {
    final backups = await BackupService.instance.listBackups();
    if (!mounted) return;

    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum backup local encontrado.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<BackupFileInfo>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: backups.length,
            itemBuilder: (context, index) {
              final backup = backups[index];
              final sizeKb = (backup.sizeInBytes / 1024).toStringAsFixed(1);
              final modifiedAt = DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(backup.modifiedAt);

              return ListTile(
                leading: const Icon(Icons.folder_zip_outlined),
                title: Text(backup.fileName),
                subtitle: Text('Alterado em $modifiedAt - $sizeKb KB'),
                onTap: () => Navigator.pop(context, backup),
              );
            },
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    try {
      await BackupService.instance.restoreBackup(selected.path);
      setState(() {
        _refreshDashboard();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao restaurar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardTab(
        resumoFuture: _resumoFuture,
        lancamentosMesFuture: _lancamentosMesFuture,
        lancamentosProximoMesFuture: _lancamentosProximoMesFuture,
        onSync: _criarBackup,
        onRestore: _restaurar,
      ),
      const ClientesPage(),
      FinanceiroPage(onDataChanged: _handleFinanceiroChanged),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('AFIN')),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 0) {
              _refreshDashboard();
            }
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Contas',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final Future<Map<String, double>> resumoFuture;
  final Future<List<Map<String, dynamic>>> lancamentosMesFuture;
  final Future<List<Map<String, dynamic>>> lancamentosProximoMesFuture;
  final Future<void> Function() onSync;
  final Future<void> Function() onRestore;

  const _DashboardTab({
    required this.resumoFuture,
    required this.lancamentosMesFuture,
    required this.lancamentosProximoMesFuture,
    required this.onSync,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, double>>(
          future: resumoFuture,
          builder: (context, snapshot) {
            final totalReceber = snapshot.data?['totalReceber'] ?? 0;
            final totalPagar = snapshot.data?['totalPagar'] ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    title: const Text('Total a Receber do Mes'),
                    subtitle: Text(currency.format(totalReceber)),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFD9A441),
                      child: Icon(Icons.arrow_downward, color: Colors.white),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Total a Pagar do Mes'),
                    subtitle: Text(currency.format(totalPagar)),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF78909C),
                      child: Icon(Icons.arrow_upward, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const TabBar(
                  tabs: [
                    Tab(text: 'Vencimentos do Mes'),
                    Tab(text: 'Lancamentos Futuros'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      _LancamentosList(
                        future: lancamentosMesFuture,
                        currency: currency,
                        emptyMessage: 'Nenhum vencimento neste mes.',
                      ),
                      _LancamentosList(
                        future: lancamentosProximoMesFuture,
                        currency: currency,
                        emptyMessage: 'Nenhum lancamento para o proximo mes.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onSync,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Criar Backup Compactado'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore),
                  label: const Text('Restaurar Backup Local'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LancamentosList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final NumberFormat currency;
  final String emptyMessage;

  const _LancamentosList({
    required this.future,
    required this.currency,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(child: Text(emptyMessage));
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final vencimento = DateFormat(
              'dd/MM/yyyy',
            ).format(DateTime.parse(item['data_vencimento'] as String));
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(item['cliente_nome'] as String),
                subtitle: Text(
                  '${item['tipo']} | ${item['descricao']}\nVencimento: $vencimento | Status: ${item['status']}',
                ),
                isThreeLine: true,
                trailing: Text(
                  currency.format(item['valor']),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
