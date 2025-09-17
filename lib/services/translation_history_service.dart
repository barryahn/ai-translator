import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class TranslationHistoryItem {
  final int id;
  final String fromUiLanguage;
  final String toUiLanguage;
  final String inputText;
  final String resultText;
  final int createdAtMillis;

  TranslationHistoryItem({
    required this.id,
    required this.fromUiLanguage,
    required this.toUiLanguage,
    required this.inputText,
    required this.resultText,
    required this.createdAtMillis,
  });

  factory TranslationHistoryItem.fromMap(Map<String, Object?> map) {
    return TranslationHistoryItem(
      id: (map['id'] as int),
      fromUiLanguage: (map['from_ui'] as String),
      toUiLanguage: (map['to_ui'] as String),
      inputText: (map['input_text'] as String),
      resultText: (map['result_text'] as String),
      createdAtMillis: (map['created_at'] as int),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'from_ui': fromUiLanguage,
      'to_ui': toUiLanguage,
      'input_text': inputText,
      'result_text': resultText,
      'created_at': createdAtMillis,
    };
  }
}

class TranslationHistoryService {
  static final TranslationHistoryService instance =
      TranslationHistoryService._internal();
  TranslationHistoryService._internal() {
    _itemsController = StreamController<List<TranslationHistoryItem>>.broadcast(
      onListen: () {
        // 새로운 구독자가 생기면 최신 데이터를 즉시 한 번 내보냅니다.
        unawaited(_emitAll());
      },
    );
  }

  static const String _dbName = 'ai_translator.db';
  static const int _dbVersion = 1;
  static const String _table = 'translation_history';

  static bool _initialized = false;
  Database? _db;

  late final StreamController<List<TranslationHistoryItem>> _itemsController;

  static Future<void> initialize() async {
    if (_initialized) return;
    await instance._open();
    _initialized = true;
  }

  Future<void> _open() async {
    final String dbRoot = await getDatabasesPath();
    final String dbPath = p.join(dbRoot, _dbName);
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_ui TEXT NOT NULL,
            to_ui TEXT NOT NULL,
            input_text TEXT NOT NULL,
            result_text TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    await _emitAll();
  }

  Stream<List<TranslationHistoryItem>> watchAll() => _itemsController.stream;

  Future<List<TranslationHistoryItem>> getAll({int? limit, int? offset}) async {
    final db = _db;
    if (db == null) return [];
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(TranslationHistoryItem.fromMap).toList();
  }

  Future<int?> addHistory({
    required String fromUiLanguage,
    required String toUiLanguage,
    required String inputText,
    required String resultText,
  }) async {
    final db = _db;
    if (db == null) return null;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int id = await db.insert(_table, {
      'from_ui': fromUiLanguage,
      'to_ui': toUiLanguage,
      'input_text': inputText,
      'result_text': resultText,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _emitAll();
    return id;
  }

  Future<void> deleteById(int id) async {
    final db = _db;
    if (db == null) return;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    await _emitAll();
  }

  Future<void> clear() async {
    final db = _db;
    if (db == null) return;
    await db.delete(_table);
    await _emitAll();
  }

  Future<void> _emitAll() async {
    _itemsController.add(await getAll());
  }

  Future<void> close() async {
    await _itemsController.close();
    final db = _db;
    _db = null;
    await db?.close();
  }
}
