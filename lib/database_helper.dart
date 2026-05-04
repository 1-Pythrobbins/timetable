import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path = p.join(await getDatabasesPath(), 'exam_manager_v2.db');
    
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('''
        CREATE TABLE IF NOT EXISTS time_constraints (
          id INTEGER PRIMARY KEY DEFAULT 1,
          start_date TEXT,
          end_date TEXT,
          allow_weekends INTEGER DEFAULT 0,
          max_exams_per_day INTEGER DEFAULT 2
        )
      ''');
      await db.execute('INSERT OR IGNORE INTO time_constraints (id, allow_weekends, max_exams_per_day) VALUES (1, 0, 2)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS timeslots (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          start_time TEXT,
          end_time TEXT
        )
      ''');
      // Default slots if empty
      final slots = await db.query('timeslots');
      if (slots.isEmpty) {
        await db.insert('timeslots', {'start_time': '08:30', 'end_time': '11:30'});
        await db.insert('timeslots', {'start_time': '13:00', 'end_time': '16:00'});
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS blackout_dates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT UNIQUE
        )
      ''');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Courses Table
    await db.execute('''
      CREATE TABLE courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        headcount INTEGER NOT NULL,
        is_alias INTEGER NOT NULL DEFAULT 0,
        parent_course_code TEXT
      )
    ''');

    // 2. Venues Table
    await db.execute('''
      CREATE TABLE venues (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        capacity INTEGER NOT NULL
      )
    ''');

    // 3. Invigilators Table
    await db.execute('''
      CREATE TABLE invigilators (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        department TEXT NOT NULL,
        max_days_per_week INTEGER NOT NULL DEFAULT 3
      )
    ''');

    // 4. Timetable Output Table
    await db.execute('''
      CREATE TABLE timetable_output (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_code TEXT NOT NULL,
        venue_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        time_slot TEXT NOT NULL,
        invigilator_id INTEGER NOT NULL,
        FOREIGN KEY (venue_id) REFERENCES venues (id) ON DELETE CASCADE,
        FOREIGN KEY (invigilator_id) REFERENCES invigilators (id) ON DELETE CASCADE
      )
    ''');

    // 5. Students Table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL
      )
    ''');

    // 6. Student Courses Table
    await db.execute('''
      CREATE TABLE student_courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        course_code TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (student_id) ON DELETE CASCADE,
        FOREIGN KEY (course_code) REFERENCES courses (code) ON DELETE CASCADE
      )
    ''');
  }

  // --- CRUD Operations ---

  Future<int> insert(String table, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    Database db = await database;
    return await db.query(table);
  }

  Future<void> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    await db.delete(table, where: where, whereArgs: whereArgs);
  }

  // Time Constraints Helpers
  Future<Map<String, dynamic>> getTimeConstraints() async {
    final db = await database;
    final results = await db.query('time_constraints', where: 'id = 1');
    return results.isNotEmpty ? results.first : {};
  }

  Future<void> updateTimeConstraints(Map<String, dynamic> data) async {
    final db = await database;
    await db.update('time_constraints', data, where: 'id = 1');
  }

  Future<List<Map<String, dynamic>>> getTimeslots() async {
    final db = await database;
    return await db.query('timeslots');
  }

  Future<void> addTimeslot(String start, String end) async {
    final db = await database;
    await db.insert('timeslots', {'start_time': start, 'end_time': end});
  }

  Future<void> deleteTimeslot(int id) async {
    final db = await database;
    await db.delete('timeslots', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTimeslots() async {
    final db = await database;
    await db.delete('timeslots');
  }

  Future<List<String>> getBlackoutDates() async {
    final db = await database;
    final results = await db.query('blackout_dates');
    return results.map((e) => e['date'] as String).toList();
  }

  Future<void> addBlackoutDate(String date) async {
    final db = await database;
    await db.insert('blackout_dates', {'date': date}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeBlackoutDate(String date) async {
    final db = await database;
    await db.delete('blackout_dates', where: 'date = ?', whereArgs: [date]);
  }

  // --- Student Operations ---
  Future<List<Map<String, dynamic>>> getStudents() async {
    final db = await database;
    return await db.query('students');
  }

  Future<void> addStudent(String studentId, String name) async {
    final db = await database;
    await db.insert('students', {'student_id': studentId, 'name': name});
  }

  Future<void> deleteStudent(int id) async {
    final db = await database;
    await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getStudentCourses(String studentId) async {
    final db = await database;
    return await db.query('student_courses', where: 'student_id = ?', whereArgs: [studentId]);
  }

  Future<void> addStudentToCourse(String studentId, String courseCode) async {
    final db = await database;
    await db.insert('student_courses', {'student_id': studentId, 'course_code': courseCode});
  }

  Future<void> removeStudentFromCourse(String studentId, String courseCode) async {
    final db = await database;
    await db.delete('student_courses', where: 'student_id = ? AND course_code = ?', whereArgs: [studentId, courseCode]);
  }

  // Seed Data for Demo
  Future<void> seedData() async {
    final db = await database;
    await db.transaction((txn) async {
      // Clear existing
      await txn.delete('courses');
      await txn.delete('venues');
      await txn.delete('invigilators');
      await txn.delete('timetable_output');

      // Seed Venues
      final venues = [
        {'name': 'Great Hall', 'capacity': 500},
        {'name': 'Central Classroom', 'capacity': 150},
        {'name': 'Lecture Theatre 1', 'capacity': 200},
        {'name': 'Auditorium 2', 'capacity': 300},
      ];
      for (var v in venues) await txn.insert('venues', v);

      // Seed Courses
      final courses = [
        {'code': 'CS101', 'name': 'Intro to Programming', 'headcount': 450, 'is_alias': 0},
        {'code': 'MAT201', 'name': 'Calculus II', 'headcount': 120, 'is_alias': 0},
        {'code': 'CS302', 'name': 'Database Systems', 'headcount': 180, 'is_alias': 0},
        {'code': 'ENG101', 'name': 'Academic Writing', 'headcount': 300, 'is_alias': 0},
        {'code': 'CS404', 'name': 'Artificial Intelligence', 'headcount': 80, 'is_alias': 0},
        {'code': 'PHY202', 'name': 'Quantum Physics', 'headcount': 50, 'is_alias': 0},
      ];
      for (var c in courses) await txn.insert('courses', c);

      // Seed Invigilators
      final invigilators = [
        {'name': 'Dr. Smith', 'department': 'Computer Science', 'max_days_per_week': 3},
        {'name': 'Prof. Jones', 'department': 'Mathematics', 'max_days_per_week': 3},
        {'name': 'Dr. Mensah', 'department': 'Physics', 'max_days_per_week': 3},
        {'name': 'Ms. Araba', 'department': 'English', 'max_days_per_week': 3},
      ];
      for (var i in invigilators) await txn.insert('invigilators', i);

      // Seed Default Time Constraints
      final now = DateTime.now();
      await txn.update('time_constraints', {
        'start_date': now.toIso8601String(),
        'end_date': now.add(const Duration(days: 21)).toIso8601String(),
        'allow_weekends': 0,
        'max_exams_per_day': 2,
      }, where: 'id = 1');

      await txn.delete('blackout_dates');
      await txn.insert('blackout_dates', {'date': DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 5)))});

      // Seed Students
      final students = [
        {'student_id': 'STU001', 'name': 'Alice Johnson'},
        {'student_id': 'STU002', 'name': 'Bob Smith'},
        {'student_id': 'STU003', 'name': 'Charlie Brown'},
      ];
      for (var s in students) await txn.insert('students', s);

      // Seed Student-Course registrations
      await txn.insert('student_courses', {'student_id': 'STU001', 'course_code': 'CS101'});
      await txn.insert('student_courses', {'student_id': 'STU001', 'course_code': 'MAT201'});
      await txn.insert('student_courses', {'student_id': 'STU002', 'course_code': 'CS101'});
      await txn.insert('student_courses', {'student_id': 'STU003', 'course_code': 'CS302'});
    });
  }

  Future<int> update(String table, Map<String, dynamic> row, String where, List<dynamic> whereArgs) async {
    Database db = await database;
    return await db.update(table, row, where: where, whereArgs: whereArgs);
  }

  Future<void> clearAllData() async {
    Database db = await database;
    await db.transaction((txn) async {
      await txn.delete('courses');
      await txn.delete('venues');
      await txn.delete('invigilators');
      await txn.delete('timetable_output');
      await txn.delete('students');
      await txn.delete('student_courses');
    });
  }

  Future<void> clearTable(String table) async {
    Database db = await database;
    if (table == 'students') {
      await db.delete('student_courses');
    }
    await db.delete(table);
  }

  Future<void> saveTimetable(List<Map<String, dynamic>> entries) async {
    Database db = await database;
    await db.transaction((txn) async {
      await txn.delete('timetable_output');
      for (var entry in entries) {
        await txn.insert('timetable_output', entry);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getTimetableWithDetails() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT 
        t.id, 
        t.course_code,
        c.name as course_name, 
        v.name as venue_name, 
        i.name as invigilator_name,
        t.date,
        t.time_slot
      FROM timetable_output t
      LEFT JOIN courses c ON t.course_code = c.code
      JOIN venues v ON t.venue_id = v.id
      JOIN invigilators i ON t.invigilator_id = i.id
      ORDER BY t.date ASC, t.time_slot ASC
    ''');
  }

  Future<Map<String, List<String>>> getStudentCourseMap() async {
    final db = await database;
    final results = await db.query('student_courses');
    Map<String, List<String>> map = {};
    for (var r in results) {
      String sid = r['student_id'] as String;
      String code = r['course_code'] as String;
      map.putIfAbsent(code, () => []).add(sid);
    }
    return map;
  }

  Future<List<Course>> getAllCourses() async {
    final db = await database;
    final results = await db.query('courses');
    return results.map((e) => Course.fromMap(e)).toList();
  }
}


