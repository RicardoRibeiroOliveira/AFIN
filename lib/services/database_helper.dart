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
  static const int dbVersion = 1;

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
        valor REAL NOT NULL,
        data_emissao TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        data_pagamento TEXT,
        status TEXT NOT NULL CHECK (status IN ('Pendente', 'Pago')),
        valor_recebido REAL,
        foto_path TEXT,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_clientes_documento ON clientes(documento)',
    );
    await db.execute(
      'CREATE INDEX idx_financeiro_tipo_status ON financeiro(tipo, status)',
    );
    await db.execute(
      'CREATE INDEX idx_financeiro_cliente ON financeiro(cliente_id)',
    );
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

      for (final numero in telefones) {
        await txn.insert(
          'telefones',
          Telefone(clienteId: clienteId, numero: numero).toMap(),
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

      for (final numero in telefones) {
        await txn.insert(
          'telefones',
          Telefone(clienteId: cliente.id!, numero: numero).toMap(),
        );
      }

      return updated;
    });
  }

  Future<int> deleteCliente(int clienteId) async {
    final db = await database;
    return db.delete('clientes', where: 'id = ?', whereArgs: [clienteId]);
  }

  Future<List<Map<String, dynamic>>> searchClientes(String query) async {
    final db = await database;
    final normalized = '%${query.trim()}%';

    return db.rawQuery('''
      SELECT c.id, c.nome, c.documento, c.tipo_pessoa,
             GROUP_CONCAT(t.numero, ' | ') AS telefones
      FROM clientes c
      LEFT JOIN telefones t ON t.cliente_id = c.id
      WHERE c.nome LIKE ? OR c.documento LIKE ?
      GROUP BY c.id
      ORDER BY c.nome ASC
    ''', [normalized, normalized]);
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

  Future<List<Map<String, dynamic>>> getContasByTipo(String tipo) async {
    final db = await database;

    return db.rawQuery('''
      SELECT f.*, c.nome AS cliente_nome, c.documento
      FROM financeiro f
      INNER JOIN clientes c ON c.id = f.cliente_id
      WHERE f.tipo = ?
      ORDER BY datetime(f.data_emissao) DESC
    ''', [tipo]);
  }

  Future<Map<String, double>> getResumoMensal() async {
    final db = await database;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final nextMonth = DateTime(now.year, now.month + 1, 1).toIso8601String();

    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN tipo = 'Receber' THEN valor ELSE 0 END), 0) AS total_receber,
        COALESCE(SUM(CASE WHEN tipo = 'Pagar' THEN valor ELSE 0 END), 0) AS total_pagar
      FROM financeiro
      WHERE data_emissao >= ? AND data_emissao < ?
    ''', [monthStart, nextMonth]);

    final row = result.first;
    return {
      'totalReceber': (row['total_receber'] as num).toDouble(),
      'totalPagar': (row['total_pagar'] as num).toDouble(),
    };
  }
}
