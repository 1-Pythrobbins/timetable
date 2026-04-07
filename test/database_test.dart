import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_1/database_helper.dart';

void main() {
  // Init ffi loader
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper Tests', () {
    late DatabaseHelper dbHelper;

    setUp(() {
      dbHelper = DatabaseHelper();
    });

    test('Insert and Query Students', () async {
      await dbHelper.insert('Students', {
        'name': 'John Doe',
        'student_code': 'S123'
      });

      final students = await dbHelper.queryAll('Students');
      expect(students.length, 1);
      expect(students.first['name'], 'John Doe');
    });

    test('Insert Courses and StudentCourses join table', () async {
      final studentId = await dbHelper.insert('Students', {
        'name': 'Jane Smith',
        'student_code': 'S456'
      });

      final courseId = await dbHelper.insert('Courses', {
        'name': 'Computer Science 101',
        'course_code': 'CS101'
      });

      await dbHelper.insert('StudentCourses', {
        'student_id': studentId,
        'course_id': courseId,
      });

      final enrolledIds = await dbHelper.getStudentIdsByCourse(courseId);
      expect(enrolledIds.length, 1);
      expect(enrolledIds.first, studentId);
    });

    test('Conflict resolution query with multiple students', () async {
      final courseId = await dbHelper.insert('Courses', {
        'name': 'Advanced Math',
        'course_code': 'MATH202'
      });

      final s1 = await dbHelper.insert('Students', {'name': 'Alice', 'student_code': 'S1'});
      final s2 = await dbHelper.insert('Students', {'name': 'Bob', 'student_code': 'S2'});

      await dbHelper.insert('StudentCourses', {'student_id': s1, 'course_id': courseId});
      await dbHelper.insert('StudentCourses', {'student_id': s2, 'course_id': courseId});

      final ids = await dbHelper.getStudentIdsByCourse(courseId);
      expect(ids, containsAll([s1, s2]));
      expect(ids.length, 2);
    });
  });
}
