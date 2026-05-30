import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/cliente.dart';
import '../models/conta_financeira.dart';
import '../models/telefone.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  static const String dbName = 'afin.db';
  static const int dbVersion = 5;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, dbName);

    return openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _upgradeDatabase(db, oldVersion);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        documento TEXT NOT NULL UNIQUE,
        tipo_pessoa TEXT NOT NULL CHECK (tipo_pessoa IN ('CPF', 'CNPJ'))
      )
    ''');

    await db.execute('''
      CREATE TABLE telefones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        numero TEXT NOT NULL,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE financeiro (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        tipo TEXT NOT NULL CHECK (tipo IN ('Pagar', 'Receber')),
        grupo TEXT NOT NULL DEFAULT 'Sem grupo',
        descricao TEXT NOT NULL DEFAULT '',
        valor REAL NOT NULL,
        data_emissao TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        data_vencimento TEXT NOT NULL,
        data_pagamento TEXT,
        status TEXT NOT NULL CHECK (status IN ('Pendente', 'Pago')),
        valor_recebido REAL,
        foto_path TEXT,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE grupos_financeiros (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        tipo TEXT NOT NULL CHECK (tipo IN ('Pagar', 'Receber')),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(nome, tipo)
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clientes_documento ON clientes(documento)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_financeiro_tipo_status ON financeiro(tipo, status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_financeiro_cliente ON financeiro(cliente_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_financeiro_vencimento ON financeiro(data_vencimento)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_grupos_tipo_nome ON grupos_financeiros(tipo, nome)',
    );
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE financeiro ADD COLUMN descricao TEXT NOT NULL DEFAULT ''",
      );
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE financeiro ADD COLUMN grupo TEXT NOT NULL DEFAULT 'Sem grupo'",
      );
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS grupos_financeiros (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          tipo TEXT NOT NULL CHECK (tipo IN ('Pagar', 'Receber')),
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(nome, tipo)
        )
      ''');
    }

    if (oldVersion < 5) {
      await db.execute("ALTER TABLE financeiro ADD COLUMN data_vencimento TEXT");
      await db.execute('''
        UPDATE financeiro
        SET data_vencimento = data_emissao
        WHERE data_vencimento IS NULL OR TRIM(data_vencimento) = ''
      ''');
    }

    await _createIndexes(db);
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<int> insertCliente(Cliente cliente, List<String> telefones) async {
    final db = await database;

    return db.transaction<int>((txn) async {
      final clienteId = await txn.insert('clientes', cliente.toMap());

      for (final numero in telefones.where((item) => item.trim().isNotEmpty)) {
        await txn.insert(
          'telefones',
          Telefone(clienteId: clienteId, numero: numero.trim()).toMap(),
        );
      }

      return clienteId;
    });
  }

  Future<int> updateCliente(Cliente cliente, List<String> telefones) async {
    final db = await database;

    return db.transaction<int>((txn) async {
      final updated = await txn.update(
        'clientes',
        cliente.toMap(),
        where: 'id = ?',
        whereArgs: [cliente.id],
      );

      await txn.delete(
        'telefones',
        where: 'cliente_id = ?',
        whereArgs: [cliente.id],
      );

      for (final numero in telefones.where((item) => item.trim().isNotEmpty)) {
        await txn.insert(
          'telefones',
          Telefone(clienteId: cliente.id!, numero: numero.trim()).toMap(),
        );
      }

      return updated;
    });
  }

  Future<int> deleteCliente(int clienteId) async {
    final db = await database;
    return db.delete('clientes', where: 'id = ?', whereArgs: [clienteId]);
  }

  Future<List<Map<String, dynamic>>> searchClientes(
    String query, {
    String filtro = 'todos',
  }) async {
    final db = await database;
    final normalized = '%${query.trim()}%';

    String whereClause;
    List<Object?> whereArgs;

    switch (filtro) {
      case 'nome':
        whereClause = 'c.nome LIKE ?';
        whereArgs = [normalized];
        break;
      case 'documento':
        whereClause = 'c.documento LIKE ?';
        whereArgs = [normalized];
        break;
      case 'telefone':
        whereClause = 't.numero LIKE ?';
        whereArgs = [normalized];
        break;
      default:
        whereClause = '''
          c.nome LIKE ? OR
          c.documento LIKE ? OR
          t.numero LIKE ?
        ''';
        whereArgs = [normalized, normalized, normalized];
    }

    return db.rawQuery('''
      SELECT c.id, c.nome, c.documento, c.tipo_pessoa,
             GROUP_CONCAT(t.numero, ' | ') AS telefones
      FROM clientes c
      LEFT JOIN telefones t ON t.cliente_id = c.id
      WHERE $whereClause
      GROUP BY c.id
      ORDER BY c.nome ASC
    ''', whereArgs);
  }

  Future<List<Map<String, dynamic>>> getClientes() async {
    return searchClientes('');
  }

  Future<int> insertConta(ContaFinanceira conta) async {
    final db = await database;
    return db.insert('financeiro', conta.toMap());
  }

  Future<int> updateConta(ContaFinanceira conta) async {
    final db = await database;
    return db.update(
      'financeiro',
      conta.toMap(),
      where: 'id = ?',
      whereArgs: [conta.id],
    );
  }

  Future<int> deleteConta(int contaId) async {
    final db = await database;
    return db.delete('financeiro', where: 'id = ?', whereArgs: [contaId]);
  }

  Future<int> insertGrupo({
    required String nome,
    required String tipo,
  }) async {
    final db = await database;
    return db.insert('grupos_financeiros', {
      'nome': nome.trim(),
      'tipo': tipo,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<String>> getGruposByTipo(String tipo) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT nome FROM grupos_financeiros
      WHERE tipo = ?
      UNION
      SELECT grupo AS nome FROM financeiro
      WHERE tipo = ? AND TRIM(grupo) <> ''
      ORDER BY nome COLLATE NOCASE ASC
    ''', [tipo, tipo]);

    return rows
        .map((row) => (row['nome'] as String?)?.trim() ?? '')
        .where((nome) => nome.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getContasByTipo(
    String tipo, {
    String? grupo,
    String clienteQuery = '',
    String situacao = 'todas',
  }) async {
    final db = await database;
    final whereClauses = <String>['f.tipo = ?'];
    final whereArgs = <Object?>[tipo];

    if (grupo != null && grupo.trim().isNotEmpty) {
      whereClauses.add('f.grupo = ?');
      whereArgs.add(grupo.trim());
    }

    if (clienteQuery.trim().isNotEmpty) {
      final normalized = '%${clienteQuery.trim()}%';
      whereClauses.add('''
        (
          c.nome LIKE ? OR
          c.documento LIKE ? OR
          EXISTS (
            SELECT 1
            FROM telefones t
            WHERE t.cliente_id = c.id
              AND t.numero LIKE ?
          )
        )
      ''');
      whereArgs.addAll([normalized, normalized, normalized]);
    }

    switch (situacao) {
      case 'aberto':
        whereClauses.add("f.status <> 'Pago'");
        whereClauses.add("date(f.data_vencimento) >= date('now', 'localtime')");
        break;
      case 'pago':
        whereClauses.add("f.status = 'Pago'");
        break;
      case 'vencido':
        whereClauses.add("f.status <> 'Pago'");
        whereClauses.add("date(f.data_vencimento) < date('now', 'localtime')");
        break;
    }

    return db.rawQuery('''
      SELECT
        f.*,
        c.nome AS cliente_nome,
        c.documento,
        GROUP_CONCAT(t.numero, ' | ') AS telefones
      FROM financeiro f
      INNER JOIN clientes c ON c.id = f.cliente_id
      LEFT JOIN telefones t ON t.cliente_id = c.id
      WHERE ${whereClauses.join(' AND ')}
      GROUP BY f.id
      ORDER BY
        CASE WHEN f.status = 'Pendente' THEN 0 ELSE 1 END,
        date(f.data_vencimento) ASC,
        datetime(f.data_emissao) DESC
    ''', whereArgs);
  }

  Future<int> marcarContaComoPagaOuRecebida({
    required int contaId,
    required double valorRecebido,
    required DateTime dataPagamento,
  }) async {
    final db = await database;
    return db.update(
      'financeiro',
      {
        'status': 'Pago',
        'valor_recebido': valorRecebido,
        'data_pagamento': dataPagamento.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [contaId],
    );
  }

  Future<int> estornarConta(int contaId) async {
    final db = await database;
    return db.update(
      'financeiro',
      {
        'status': 'Pendente',
        'valor_recebido': null,
        'data_pagamento': null,
      },
      where: 'id = ?',
      whereArgs: [contaId],
    );
  }

  Future<Map<String, double>> getResumoMensal() async {
    final db = await database;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final nextMonth = DateTime(now.year, now.month + 1, 1).toIso8601String();

    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE
          WHEN tipo = 'Receber' AND data_vencimento >= ? AND data_vencimento < ? THEN valor
          ELSE 0
        END), 0) AS total_receber,
        COALESCE(SUM(CASE
          WHEN tipo = 'Pagar' AND data_vencimento >= ? AND data_vencimento < ? THEN valor
          ELSE 0
        END), 0) AS total_pagar,
        COALESCE(SUM(CASE
          WHEN tipo = 'Receber' AND status = 'Pago' AND data_pagamento >= ? AND data_pagamento < ?
            THEN COALESCE(valor_recebido, valor)
          ELSE 0
        END), 0) AS total_recebido,
        COALESCE(SUM(CASE
          WHEN tipo = 'Pagar' AND status = 'Pago' AND data_pagamento >= ? AND data_pagamento < ?
            THEN COALESCE(valor_recebido, valor)
          ELSE 0
        END), 0) AS total_pago
      FROM financeiro
    ''', [
      monthStart,
      nextMonth,
      monthStart,
      nextMonth,
      monthStart,
      nextMonth,
      monthStart,
      nextMonth,
    ]);

    final row = result.first;
    return {
      'totalReceber': (row['total_receber'] as num?)?.toDouble() ?? 0,
      'totalPagar': (row['total_pagar'] as num?)?.toDouble() ?? 0,
      'totalRecebido': (row['total_recebido'] as num?)?.toDouble() ?? 0,
      'totalPago': (row['total_pago'] as num?)?.toDouble() ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getLancamentosPorPeriodo({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;

    return db.rawQuery('''
      SELECT f.*, c.nome AS cliente_nome
      FROM financeiro f
      INNER JOIN clientes c ON c.id = f.cliente_id
      WHERE f.data_vencimento >= ? AND f.data_vencimento < ?
      ORDER BY date(f.data_vencimento) ASC, datetime(f.data_emissao) DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }
}
