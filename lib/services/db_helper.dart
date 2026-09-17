import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('solargrid.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE chart_data (
  _id       INTEGER PRIMARY KEY AUTOINCREMENT,
  logger_id TEXT    NOT NULL,
  timestamp INTEGER NOT NULL,
  battery_soc INTEGER NOT NULL,
  grid_status INTEGER NOT NULL
)
''');

    await db.execute('''
CREATE TABLE event_logs (
  _id        INTEGER PRIMARY KEY AUTOINCREMENT,
  logger_id  TEXT    NOT NULL,
  timestamp  INTEGER NOT NULL,
  event_type TEXT    NOT NULL,
  message    TEXT    NOT NULL
)
''');

    // Index for fast per-logger time-ordered queries
    await db.execute(
        'CREATE INDEX idx_chart_logger ON chart_data(logger_id, timestamp)');
    await db.execute(
        'CREATE INDEX idx_event_logger ON event_logs(logger_id, timestamp)');
  }

  // ──────────────────────────────────────────────
  // Chart data
  // ──────────────────────────────────────────────

  Future<void> insertChartData(
      String loggerId, int batterySoc, bool gridStatus) async {
    final db = await database;
    await db.insert('chart_data', {
      'logger_id': loggerId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'battery_soc': batterySoc,
      'grid_status': gridStatus ? 1 : 0,
    });
    // Prune entries older than 7 days
    final cutoff =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    await db.delete('chart_data',
        where: 'logger_id = ? AND timestamp < ?',
        whereArgs: [loggerId, cutoff]);
  }

  Future<List<Map<String, dynamic>>> getChartData(String loggerId,
      {int limit = 1000}) async {
    final db = await database;
    return db.query(
      'chart_data',
      where: 'logger_id = ?',
      whereArgs: [loggerId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
  }

  /// Returns the last 24 h of data for a logger.
  Future<List<Map<String, dynamic>>> getChartData24h(String loggerId) async {
    final db = await database;
    final since =
        DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    return db.query(
      'chart_data',
      where: 'logger_id = ? AND timestamp >= ?',
      whereArgs: [loggerId, since],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> clearChartData(String loggerId) async {
    final db = await database;
    await db.delete('chart_data',
        where: 'logger_id = ?', whereArgs: [loggerId]);
  }

  // ──────────────────────────────────────────────
  // Event logs
  // ──────────────────────────────────────────────

  Future<void> insertEventLog(
      String loggerId, String eventType, String message) async {
    final db = await database;
    await db.insert('event_logs', {
      'logger_id': loggerId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'event_type': eventType,
      'message': message,
    });
  }

  Future<List<Map<String, dynamic>>> getEventLogs(String loggerId,
      {int limit = 200, String? eventTypeFilter}) async {
    final db = await database;
    final where = eventTypeFilter != null
        ? 'logger_id = ? AND event_type = ?'
        : 'logger_id = ?';
    final args = eventTypeFilter != null
        ? [loggerId, eventTypeFilter]
        : [loggerId];
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
    await db.delete('event_logs',
        where: 'logger_id = ?', whereArgs: [loggerId]);
  }

  /// Delete all data for a logger (called when logger is removed).
  Future<void> deleteLoggerData(String loggerId) async {
    await clearChartData(loggerId);
    await clearEventLogs(loggerId);
  }
}
