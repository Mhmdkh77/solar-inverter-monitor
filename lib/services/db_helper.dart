import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('solar_inverter_monitor.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return openDatabase(path,
        version: 3, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE event_logs (
  _id        INTEGER PRIMARY KEY AUTOINCREMENT,
  logger_id  TEXT    NOT NULL,
  timestamp  INTEGER NOT NULL,
  event_type TEXT    NOT NULL,
  message    TEXT    NOT NULL
)
''');

    await _createGridStateTable(db);

    await db.execute(
        'CREATE INDEX idx_event_logger ON event_logs(logger_id, timestamp)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createGridStateTable(db);
      // Version 1 stored its latest grid state in chart_data.
      await db.execute('''
INSERT INTO grid_state (logger_id, grid_status)
SELECT c.logger_id, c.grid_status
FROM chart_data c
JOIN (
  SELECT logger_id, MAX(_id) AS last_id
  FROM chart_data
  GROUP BY logger_id
) latest ON c._id = latest.last_id
''');
    }
    if (oldVersion < 3) {
      // SQLite also removes the chart index when its table is dropped.
      await db.execute('DROP TABLE IF EXISTS chart_data');
    }
  }

  Future<void> _createGridStateTable(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE grid_state (
  logger_id TEXT PRIMARY KEY,
  grid_status INTEGER NOT NULL
)
''');
  }

  // ──────────────────────────────────────────────
  // Grid state
  // ──────────────────────────────────────────────

  /// Records a reading and returns the new grid state only when it changed.
  /// A transaction prevents foreground and background polls from logging or
  /// notifying about the same transition twice.
  Future<bool?> recordReading(
      String loggerId, int batterySoc, bool gridStatus) async {
    final db = await database;
    return db.transaction((txn) async {
      final current = gridStatus ? 1 : 0;
      final previous = await txn.query(
        'grid_state',
        columns: ['grid_status'],
        where: 'logger_id = ?',
        whereArgs: [loggerId],
        limit: 1,
      );
      bool? transition;
      if (previous.isEmpty) {
        await txn.insert('grid_state', {
          'logger_id': loggerId,
          'grid_status': current,
        });
      } else if (previous.first['grid_status'] != current) {
        transition = gridStatus;
        await txn.update(
          'grid_state',
          {'grid_status': current},
          where: 'logger_id = ?',
          whereArgs: [loggerId],
        );
        await txn.insert('event_logs', {
          'logger_id': loggerId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'event_type': gridStatus ? 'GRID_ON' : 'GRID_OFF',
          'message': gridStatus
              ? 'Grid power is back ON. Battery at $batterySoc%.'
              : 'The grid has gone OFF. Check your inverter!',
        });
      }

      return transition;
    });
  }

  // ──────────────────────────────────────────────
  // Event logs
  // ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEventLogs(String loggerId,
      {int limit = 200, String? eventTypeFilter}) async {
    final db = await database;
    final where = eventTypeFilter != null
        ? 'logger_id = ? AND event_type = ?'
        : 'logger_id = ?';
    final args =
        eventTypeFilter != null ? [loggerId, eventTypeFilter] : [loggerId];
    return db.query(
      'event_logs',
      where: where,
      whereArgs: args,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  Future<void> clearEventLogs(String loggerId) async {
    final db = await database;
    await db
        .delete('event_logs', where: 'logger_id = ?', whereArgs: [loggerId]);
  }

  /// Delete all data for a logger (called when logger is removed).
  Future<void> deleteLoggerData(String loggerId) async {
    await clearEventLogs(loggerId);
    final db = await database;
    await db
        .delete('grid_state', where: 'logger_id = ?', whereArgs: [loggerId]);
  }
}
