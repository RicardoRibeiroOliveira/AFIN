import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class BackupFileInfo {
  final String path;
  final String fileName;
  final DateTime modifiedAt;
  final int sizeInBytes;

  const BackupFileInfo({
    required this.path,
    required this.fileName,
    required this.modifiedAt,
    required this.sizeInBytes,
  });
}

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const String _databaseArchivePath = 'banco/afin.db';
  static const String _manifestArchivePath = 'manifest.json';
  static const String _attachmentsFolderName = 'anexos';
  static const String _backupsFolderName = 'backups';
  static const String _restoredAttachmentsFolderName = 'anexos_restaurados';

  Future<String> createBackup() async {
    final timestamp = DateTime.now();
    final stamp = _formatTimestamp(timestamp);
    final backupsDir = await _ensureBackupsDirectory();
    final stagingDir = Directory(p.join(backupsDir.path, stamp));

    if (await stagingDir.exists()) {
      await stagingDir.delete(recursive: true);
    }
    await stagingDir.create(recursive: true);

    final stagingDatabaseDir = Directory(p.join(stagingDir.path, 'banco'));
    final stagingAttachmentsDir = Directory(
      p.join(stagingDir.path, _attachmentsFolderName),
    );
    await stagingDatabaseDir.create(recursive: true);
    await stagingAttachmentsDir.create(recursive: true);

    final databaseFile = await _getDatabaseFile();
    final stagedDatabaseFile = File(
      p.join(stagingDatabaseDir.path, DatabaseHelper.dbName),
    );
    await stagedDatabaseFile.writeAsBytes(
      await databaseFile.readAsBytes(),
      flush: true,
    );

    final attachments = await _collectAttachmentRecords();
    final manifest = <String, dynamic>{
      'created_at': timestamp.toIso8601String(),
      'database_path': _databaseArchivePath,
      'attachments': <Map<String, dynamic>>[],
    };

    for (final attachment in attachments) {
      final sourceFile = File(attachment.originalPath);
      if (!await sourceFile.exists()) {
        continue;
      }

      final sanitizedName = _buildAttachmentArchiveName(
        attachment.contaId,
        sourceFile.path,
      );
      final copiedFile = File(p.join(stagingAttachmentsDir.path, sanitizedName));
      await copiedFile.writeAsBytes(await sourceFile.readAsBytes(), flush: true);

      (manifest['attachments'] as List<Map<String, dynamic>>).add({
        'financeiro_id': attachment.contaId,
        'original_path': attachment.originalPath,
        'archive_path': '$_attachmentsFolderName/$sanitizedName',
      });
    }

    final manifestFile = File(p.join(stagingDir.path, _manifestArchivePath));
    await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

    final zipPath = p.join(backupsDir.path, 'afin_backup_$stamp.zip');
    final archive = Archive();

    archive.addFile(
      ArchiveFile(
        _databaseArchivePath,
        await stagedDatabaseFile.length(),
        await stagedDatabaseFile.readAsBytes(),
      ),
    );

    archive.addFile(
      ArchiveFile(
        _manifestArchivePath,
        await manifestFile.length(),
        utf8.encode(await manifestFile.readAsString()),
      ),
    );

    final copiedAttachments = stagingAttachmentsDir.list().where(
      (entity) => entity is File,
    );

    await for (final entity in copiedAttachments) {
      final file = entity as File;
      archive.addFile(
        ArchiveFile(
          '$_attachmentsFolderName/${p.basename(file.path)}',
          await file.length(),
          await file.readAsBytes(),
        ),
      );
    }

    final encodedZip = ZipEncoder().encode(archive);
    if (encodedZip == null) {
      throw Exception('Nao foi possivel compactar o backup.');
    }

    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(encodedZip, flush: true);
    return zipFile.path;
  }

  Future<List<BackupFileInfo>> listBackups() async {
    final backupsDir = await _ensureBackupsDirectory();
    final files = <BackupFileInfo>[];

    await for (final entity in backupsDir.list()) {
      if (entity is! File || p.extension(entity.path).toLowerCase() != '.zip') {
        continue;
      }

      final stat = await entity.stat();
      files.add(
        BackupFileInfo(
          path: entity.path,
          fileName: p.basename(entity.path),
          modifiedAt: stat.modified,
          sizeInBytes: stat.size,
        ),
      );
    }

    files.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return files;
  }

  Future<void> restoreBackup(String zipPath) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception('Arquivo de backup nao encontrado: $zipPath');
    }

    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    final manifest = _readManifest(archive);
    final dbEntry = archive.findFile(_databaseArchivePath);

    if (dbEntry == null) {
      throw Exception('O backup nao contem o banco de dados.');
    }

    await DatabaseHelper.instance.closeDatabase();
    final dbFile = File(await _getDatabasePath());
    await dbFile.writeAsBytes(dbEntry.content as List<int>, flush: true);

    final restoredAttachmentsDir = await _prepareRestoredAttachmentsDirectory();
    final restoredPathsById = <int, String>{};

    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith('$_attachmentsFolderName/')) {
        continue;
      }

      final outputPath = p.join(
        restoredAttachmentsDir.path,
        p.basename(file.name),
      );
      final outputFile = File(outputPath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsBytes(file.content as List<int>, flush: true);
    }

    for (final attachment in manifest) {
      final contaId = attachment['financeiro_id'];
      final archivePath = attachment['archive_path'];
      if (contaId is! int || archivePath is! String) {
        continue;
      }

      restoredPathsById[contaId] = p.join(
        restoredAttachmentsDir.path,
        p.basename(archivePath),
      );
    }

    final db = await DatabaseHelper.instance.database;
    for (final entry in restoredPathsById.entries) {
      await db.update(
        'financeiro',
        {'foto_path': entry.value},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
  }

  Future<String> getBackupDirectoryPath() async {
    final directory = await _ensureBackupsDirectory();
    return directory.path;
  }

  Future<File> _getDatabaseFile() async {
    final path = await _getDatabasePath();
    final file = File(path);

    if (!await file.exists()) {
      throw Exception('Arquivo local do banco nao encontrado: $path');
    }

    return file;
  }

  Future<String> _getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, DatabaseHelper.dbName);
  }

  Future<Directory> _ensureBackupsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, _backupsFolderName));
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _prepareRestoredAttachmentsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(root.path, _restoredAttachmentsFolderName),
    );

    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }

    await directory.create(recursive: true);
    return directory;
  }

  Future<List<_AttachmentRecord>> _collectAttachmentRecords() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'financeiro',
      columns: ['id', 'foto_path'],
      where: 'foto_path IS NOT NULL AND TRIM(foto_path) <> ?',
      whereArgs: [''],
    );

    return rows
        .map(
          (row) => _AttachmentRecord(
            contaId: row['id'] as int,
            originalPath: row['foto_path'] as String,
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>> _readManifest(Archive archive) {
    final manifestEntry = archive.findFile(_manifestArchivePath);
    if (manifestEntry == null) {
      return const <Map<String, dynamic>>[];
    }

    final decoded = jsonDecode(
      utf8.decode(manifestEntry.content as List<int>),
    ) as Map<String, dynamic>;

    final attachments = decoded['attachments'];
    if (attachments is! List) {
      return const <Map<String, dynamic>>[];
    }

    return attachments
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _buildAttachmentArchiveName(int contaId, String originalPath) {
    final extension = p.extension(originalPath);
    final baseName = p.basenameWithoutExtension(originalPath);
    final safeName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'financeiro_${contaId}_$safeName$extension';
  }

  String _formatTimestamp(DateTime timestamp) {
    final year = timestamp.year.toString().padLeft(4, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$year$month${day}_$hour$minute$second';
  }
}

class _AttachmentRecord {
  final int contaId;
  final String originalPath;

  const _AttachmentRecord({
    required this.contaId,
    required this.originalPath,
  });
}
