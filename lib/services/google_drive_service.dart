import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const List<String> _scopes = <String>[
    drive.DriveApi.driveAppdataScope,
  ];

  static const String backupFileName = 'afin_backup.db';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
  );

  Future<void> authenticate() async {
    final account =
        await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Login Google cancelado pelo usuario.');
    }
  }

  Future<bool> _hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<drive.DriveApi> _getDriveApi() async {
    final account =
        await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Login Google cancelado pelo usuario.');
    }

    final authHeaders = await account.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    return drive.DriveApi(client);
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

  Future<void> uploadDatabase() async {
    if (!await _hasInternet()) {
      throw Exception('Sem conexao com a internet para enviar o backup.');
    }

    final api = await _getDriveApi();
    final dbFile = await _getDatabaseFile();
    final existingFileId = await _findBackupFileId(api);

    final media = drive.Media(dbFile.openRead(), await dbFile.length());
    final metadata = drive.File()
      ..name = backupFileName
      ..parents = ['appDataFolder']
      ..description = 'Backup manual criptografavel do banco local AFIN.';

    if (existingFileId != null) {
      await api.files.update(
        metadata,
        existingFileId,
        uploadMedia: media,
      );
      return;
    }

    await api.files.create(
      metadata,
      uploadMedia: media,
    );
  }

  Future<void> restoreDatabase() async {
    if (!await _hasInternet()) {
      throw Exception('Sem conexao com a internet para restaurar o backup.');
    }

    final api = await _getDriveApi();
    final fileId = await _findBackupFileId(api);

    if (fileId == null) {
      throw Exception('Nenhum arquivo de backup foi encontrado na nuvem.');
    }

    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    await DatabaseHelper.instance.closeDatabase();
    final dbFile = File(await _getDatabasePath());
    await dbFile.writeAsBytes(bytes, flush: true);
    await DatabaseHelper.instance.database;
  }

  Future<String?> _findBackupFileId(drive.DriveApi api) async {
    final files = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$backupFileName' and trashed = false",
      $fields: 'files(id, name, modifiedTime)',
    );

    if (files.files == null || files.files!.isEmpty) {
      return null;
    }

    files.files!.sort((a, b) {
      final aTime = a.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return files.files!.first.id;
  }

  Future<void> logout() async {
    await _googleSignIn.disconnect();
  }
}

class GoogleDriveService {
  GoogleDriveService._();

  static BackupService get instance => BackupService.instance;
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
