import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'pick_models.dart';

class PickRepository {
  PickRepository._();

  static final PickRepository instance = PickRepository._();

  Database? _database;
  List<PickPhoto>? _cachedPhotos;

  Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, 'photo_lab_pick.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pick_sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            is_active INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE pick_photos(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            asset_id TEXT NOT NULL,
            group_name TEXT,
            tag1 INTEGER,
            tag2 INTEGER,
            tag3 INTEGER,
            created_at TEXT NOT NULL,
            UNIQUE(session_id, asset_id)
          )
        ''');
      },
    );
    return _database!;
  }

  Future<PickSession?> fetchActiveSession() async {
    final db = await _getDatabase();
    final rows = await db.query(
      'pick_sessions',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return PickSession(
      id: rows.first['id'] as int,
      createdAt: DateTime.parse(rows.first['created_at'] as String),
      isActive: (rows.first['is_active'] as int) == 1,
    );
  }

  Future<PickSession> createSession() async {
    final db = await _getDatabase();
    await db.update('pick_sessions', {'is_active': 0});
    final id = await db.insert('pick_sessions', {
      'created_at': DateTime.now().toIso8601String(),
      'is_active': 1,
    });
    _cachedPhotos = null;
    return PickSession(id: id, createdAt: DateTime.now(), isActive: true);
  }

  Future<void> addPhotos({
    required int sessionId,
    required List<String> assetIds,
  }) async {
    final db = await _getDatabase();
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final assetId in assetIds) {
      batch.insert('pick_photos', {
        'session_id': sessionId,
        'asset_id': assetId,
        'group_name': null,
        'tag1': null,
        'tag2': null,
        'tag3': null,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
    _cachedPhotos = null;
  }

  Future<List<PickPhoto>> fetchPhotos(int sessionId) async {
    if (_cachedPhotos != null) {
      return _cachedPhotos!;
    }
    final db = await _getDatabase();
    final rows = await db.query(
      'pick_photos',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'id DESC',
    );
    final photos = rows
        .map(
          (row) => PickPhoto(
            id: row['id'] as int,
            assetId: row['asset_id'] as String,
            sessionId: row['session_id'] as int,
            groupName: row['group_name'] as String?,
            tag1: row['tag1'] as int?,
            tag2: row['tag2'] as int?,
            tag3: row['tag3'] as int?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
    _cachedPhotos = photos;
    return photos;
  }

  Future<void> updateGroup({
    required int photoId,
    required String groupName,
  }) async {
    final db = await _getDatabase();
    await db.update(
      'pick_photos',
      {'group_name': groupName},
      where: 'id = ?',
      whereArgs: [photoId],
    );
    _cachedPhotos = null;
  }

  Future<void> updateTags({
    required int photoId,
    int? tag1,
    int? tag2,
    int? tag3,
  }) async {
    final db = await _getDatabase();
    await db.update(
      'pick_photos',
      {'tag1': tag1, 'tag2': tag2, 'tag3': tag3},
      where: 'id = ?',
      whereArgs: [photoId],
    );
    _cachedPhotos = null;
  }

  Future<void> resetGroup({required int photoId}) async {
    final db = await _getDatabase();
    await db.update(
      'pick_photos',
      {'group_name': null},
      where: 'id = ?',
      whereArgs: [photoId],
    );
    _cachedPhotos = null;
  }

  Future<List<PickGroupSummary>> fetchGroupSummaries(int sessionId) async {
    final db = await _getDatabase();
    final rows = await db.rawQuery(
      '''
      SELECT group_name as groupName, COUNT(*) as count
      FROM pick_photos
      WHERE session_id = ? AND group_name IS NOT NULL
      GROUP BY group_name
      ORDER BY count DESC
    ''',
      [sessionId],
    );
    return rows
        .map(
          (row) => PickGroupSummary(
            groupName: row['groupName'] as String,
            count: row['count'] as int,
          ),
        )
        .toList();
  }

  Future<void> removePhotosByGroup({
    required int sessionId,
    required String groupName,
  }) async {
    final db = await _getDatabase();
    await db.delete(
      'pick_photos',
      where: 'session_id = ? AND group_name = ?',
      whereArgs: [sessionId, groupName],
    );
    _cachedPhotos = null;
  }
}
