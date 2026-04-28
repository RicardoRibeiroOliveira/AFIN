import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';
import '../services/google_drive_service.dart';
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

  @override
  void initState() {
    super.initState();
    _resumoFuture = DatabaseHelper.instance.getResumoMensal();
  }

  Future<void> _sincronizar() async {
    try {
      await BackupService.instance.uploadDatabase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup enviado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao sincronizar: $e')),
      );
    }
  }

  Future<void> _restaurar() async {
    try {
      await BackupService.instance.restoreDatabase();
      setState(() {
        _resumoFuture = DatabaseHelper.instance.getResumoMensal();
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
        onSync: _sincronizar,
        onRestore: _restaurar,
      ),
      const ClientesPage(),
      const FinanceiroPage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('AFIN')),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
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
  final Future<void> Function() onSync;
  final Future<void> Function() onRestore;

  const _DashboardTab({
    required this.resumoFuture,
    required this.onSync,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Padding(
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
                  title: const Text('Total a Receber'),
                  subtitle: Text(currency.format(totalReceber)),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFD9A441),
                    child: Icon(Icons.arrow_downward, color: Colors.white),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Total a Pagar'),
                  subtitle: Text(currency.format(totalPagar)),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF78909C),
                    child: Icon(Icons.arrow_upward, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onSync,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Sincronizar com Nuvem'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.restore),
                label: const Text('Utilizar Arquivo de Backup'),
              ),
            ],
          );
        },
      ),
    );
  }
}
