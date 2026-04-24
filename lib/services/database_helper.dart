import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../utils/time_utils.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'med_reminder.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 薬テーブル
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL DEFAULT '',
        timings TEXT NOT NULL DEFAULT '',
        start_date TEXT NOT NULL,
        duration_days INTEGER NOT NULL DEFAULT 0,
        end_date TEXT,
        memo TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 服薬記録テーブル
    await db.execute('''
      CREATE TABLE dose_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        timing TEXT NOT NULL,
        scheduled_time TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        action_time TEXT,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id)
      )
    ''');
  }

  // ─────────────────────────────────────
  // 薬 CRUD
  // ─────────────────────────────────────

  // 薬を追加して新しい id を返す
  Future<int> insertMedicine(Medicine medicine) async {
    final db = await database;
    return await db.insert('medicines', medicine.toMap());
  }

  // 薬を更新
  Future<void> updateMedicine(Medicine medicine) async {
    final db = await database;
    await db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  // 薬を論理削除（is_active = 0）
  Future<void> deleteMedicine(int id) async {
    final db = await database;
    await db.update(
      'medicines',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 有効な薬を全件取得
  Future<List<Medicine>> getActiveMedicines() async {
    final db = await database;
    final maps = await db.query(
      'medicines',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'id ASC',
    );
    return maps.map((m) => Medicine.fromMap(m)).toList();
  }

  // ID で薬を1件取得
  Future<Medicine?> getMedicineById(int id) async {
    final db = await database;
    final maps = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Medicine.fromMap(maps.first);
  }

  // 今日が服用期間内の有効な薬を取得
  Future<List<Medicine>> getTodayMedicines() async {
    final db = await database;
    final today = todayString();

    // is_active = 1 かつ start_date <= today
    // かつ (end_date IS NULL または end_date >= today)
    final maps = await db.query(
      'medicines',
      where: '''
        is_active = 1
        AND start_date <= ?
        AND (end_date IS NULL OR end_date >= ?)
      ''',
      whereArgs: [today, today],
      orderBy: 'id ASC',
    );
    return maps.map((m) => Medicine.fromMap(m)).toList();
  }

  // もうすぐ終わる薬（終了日が今日から3日以内）を取得
  Future<List<Medicine>> getEndingSoonMedicines() async {
    final db = await database;
    final today = DateTime.now();
    final todayStr = todayString();

    // 3日後の日付文字列を作る
    final threeDaysLater = today.add(const Duration(days: 3));
    final threeDaysLaterStr =
        '${threeDaysLater.year}-${threeDaysLater.month.toString().padLeft(2, '0')}-${threeDaysLater.day.toString().padLeft(2, '0')}';

    final maps = await db.query(
      'medicines',
      where: '''
        is_active = 1
        AND end_date IS NOT NULL
        AND end_date >= ?
        AND end_date <= ?
      ''',
      whereArgs: [todayStr, threeDaysLaterStr],
      orderBy: 'end_date ASC',
    );
    return maps.map((m) => Medicine.fromMap(m)).toList();
  }

  // ─────────────────────────────────────
  // 服薬記録 CRUD
  // ─────────────────────────────────────

  // 服薬記録を追加（重複チェックあり）
  Future<void> insertOrUpdateDoseLog(DoseLog log) async {
    final db = await database;

    // 同じ薬・日付・タイミングのレコードがすでにあれば更新
    final existing = await db.query(
      'dose_logs',
      where: 'medicine_id = ? AND date = ? AND timing = ?',
      whereArgs: [log.medicineId, log.date, log.timing],
    );

    if (existing.isEmpty) {
      await db.insert('dose_logs', log.toMap());
    } else {
      await db.update(
        'dose_logs',
        log.toMap(),
        where: 'medicine_id = ? AND date = ? AND timing = ?',
        whereArgs: [log.medicineId, log.date, log.timing],
      );
    }
  }

  // 指定日の服薬記録を全件取得
  Future<List<DoseLog>> getDoseLogsByDate(String date) async {
    final db = await database;
    final maps = await db.query(
      'dose_logs',
      where: 'date = ?',
      whereArgs: [date],
    );
    return maps.map((m) => DoseLog.fromMap(m)).toList();
  }

  // 指定薬・指定日・指定タイミングの記録を1件取得
  Future<DoseLog?> getDoseLog({
    required int medicineId,
    required String date,
    required String timing,
  }) async {
    final db = await database;
    final maps = await db.query(
      'dose_logs',
      where: 'medicine_id = ? AND date = ? AND timing = ?',
      whereArgs: [medicineId, date, timing],
    );
    if (maps.isEmpty) return null;
    return DoseLog.fromMap(maps.first);
  }

  // 指定日の「飲んだ」件数を取得
  Future<int> getTakenCountByDate(String date) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM dose_logs WHERE date = ? AND status = 'taken'",
      [date],
    );
    return result.first['cnt'] as int;
  }
}