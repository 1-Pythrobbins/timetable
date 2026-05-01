import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static String? _customPath;

  static void setPath(String path) => _customPath = path;

  /// Call this at the start of any new isolate that needs database access.
  static void initializeForIsolate(String path) {
    if (Platform.isWindows || Platform.isLinux || Platform.isAndroid || Platform.isIOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      setPath(path);
    }
  }

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static void reset() => _database = null;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = _customPath ?? p.join(await getDatabasesPath(), 'exam_timetable.db');
    
    // Ensure the directory exists (important for FFI)
    await Directory(p.dirname(path)).create(recursive: true);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  // Ensure foreign keys are enabled and use WAL mode for concurrency
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    // On Android, some PRAGMAs return results and must be called via rawQuery
    await db.rawQuery('PRAGMA journal_mode = WAL');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Students Table
    await db.execute('''
      CREATE TABLE Students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        student_code TEXT UNIQUE NOT NULL
      )
    ''');

    // 2. Invigilators Table
    await db.execute('''
      CREATE TABLE Invigilators (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    // 3. Courses Table
    await db.execute('''
      CREATE TABLE Courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        course_code TEXT UNIQUE NOT NULL
      )
    ''');

    // 3. Venues Table
    await db.execute('''
      CREATE TABLE Venues (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        capacity INTEGER NOT NULL
      )
    ''');

    // 4. TimeSlots Table
    await db.execute('''
      CREATE TABLE TimeSlots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL
      )
    ''');

    // 5. StudentCourses (Join Table)
    await db.execute('''
      CREATE TABLE StudentCourses (
        student_id INTEGER NOT NULL,
        course_id INTEGER NOT NULL,
        PRIMARY KEY (student_id, course_id),
        FOREIGN KEY (student_id) REFERENCES Students (id) ON DELETE CASCADE,
        FOREIGN KEY (course_id) REFERENCES Courses (id) ON DELETE CASCADE
      )
    ''');

    // 6. Timetable Table
    await db.execute('''
      CREATE TABLE Timetable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL,
        venue_id INTEGER NOT NULL,
        timeslot_id INTEGER NOT NULL,
        invigilator_id INTEGER NOT NULL,
        FOREIGN KEY (course_id) REFERENCES Courses (id) ON DELETE CASCADE,
        FOREIGN KEY (venue_id) REFERENCES Venues (id) ON DELETE CASCADE,
        FOREIGN KEY (timeslot_id) REFERENCES TimeSlots (id) ON DELETE CASCADE,
        FOREIGN KEY (invigilator_id) REFERENCES Invigilators (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE Timetable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          course_id INTEGER NOT NULL,
          venue_id INTEGER NOT NULL,
          timeslot_id INTEGER NOT NULL,
          FOREIGN KEY (course_id) REFERENCES Courses (id) ON DELETE CASCADE,
          FOREIGN KEY (venue_id) REFERENCES Venues (id) ON DELETE CASCADE,
          FOREIGN KEY (timeslot_id) REFERENCES TimeSlots (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE Invigilators (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');
      await db.execute('DROP TABLE IF EXISTS Timetable');
      await db.execute('''
        CREATE TABLE Timetable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          course_id INTEGER NOT NULL,
          venue_id INTEGER NOT NULL,
          timeslot_id INTEGER NOT NULL,
          invigilator_id INTEGER NOT NULL,
          FOREIGN KEY (course_id) REFERENCES Courses (id) ON DELETE CASCADE,
          FOREIGN KEY (venue_id) REFERENCES Venues (id) ON DELETE CASCADE,
          FOREIGN KEY (timeslot_id) REFERENCES TimeSlots (id) ON DELETE CASCADE,
          FOREIGN KEY (invigilator_id) REFERENCES Invigilators (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // --- CRUD Operations ---

  // Generic Insert
  Future<int> insert(String table, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert(table, row);
  }

  // Generic Update
  Future<int> update(String table, Map<String, dynamic> row, String whereClause, List<dynamic> whereArgs) async {
    Database db = await database;
    return await db.update(table, row, where: whereClause, whereArgs: whereArgs);
  }

  // Generic Query All
  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    Database db = await database;
    return await db.query(table);
  }

  // Raw Query Wrapper
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    Database db = await database;
    return await db.rawQuery(sql, arguments);
  }

  // Specific Delete (Generic)
  Future<int> delete(String table, String whereClause, List<dynamic> whereArgs) async {
    Database db = await database;
    return await db.delete(table, where: whereClause, whereArgs: whereArgs);
  }

  // --- Specific Query: All Student IDs enrolled in a specific course_id ---
  
  /// Returns a list of all Student IDs enrolled in a specific [courseId].
  /// This is crucial for conflict-resolution algorithms.
  Future<List<int>> getStudentIdsByCourse(int courseId) async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'StudentCourses',
      columns: ['student_id'],
      where: 'course_id = ?',
      whereArgs: [courseId],
    );

    return result.map((row) => row['student_id'] as int).toList();
  }

  // --- Specific Query: Clear and Save Timetable ---
  
  Future<void> saveTimetable(List<Map<String, dynamic>> entries) async {
    Database db = await database;
    await db.transaction((txn) async {
      await txn.delete('Timetable');
      for (var entry in entries) {
        await txn.insert('Timetable', entry);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getTimetableWithDetails() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT 
        t.id, 
        c.name as course_name, 
        v.name as venue_name, 
        i.name as invigilator_name,
        ts.day || ' (' || ts.start_time || '-' || ts.end_time || ')' as timeslot_label
      FROM Timetable t
      JOIN Courses c ON t.course_id = c.id
      JOIN Venues v ON t.venue_id = v.id
      JOIN Invigilators i ON t.invigilator_id = i.id
      JOIN TimeSlots ts ON t.timeslot_id = ts.id
    ''');
  }
}
