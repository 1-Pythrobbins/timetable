import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_1/database_helper.dart';
import 'package:flutter_application_1/scheduler.dart';
import 'package:flutter_application_1/models.dart';
import 'package:path/path.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('TimetableGenerator Tests (v3 with Invigilators)', () {
    late DatabaseHelper db;

    setUp(() async {
      final dbPath = join(await getDatabasesPath(), 'exam_timetable.db');
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }
      DatabaseHelper.reset();
      db = DatabaseHelper();
    });

    test('Invigilator: Must assign an invigilator and avoid double-booking', () async {
      // 2 courses
      await db.insert('Courses', {'name': 'C1', 'course_code': 'C1'});
      await db.insert('Courses', {'name': 'C2', 'course_code': 'C2'});

      // 1 Venue
      await db.insert('Venues', {'name': 'Room 1', 'capacity': 100});

      // 2 Timeslots
      await db.insert('TimeSlots', {'day': 'M', 'start_time': '9', 'end_time': '10'});
      await db.insert('TimeSlots', {'day': 'M', 'start_time': '11', 'end_time': '12'});

      // 1 Invigilator (Forces different timeslots if only 1 is available)
      final iId = await db.insert('Invigilators', {'name': 'Prof. X'});

      final result = await TimetableGenerator.generate();

      expect(result.length, 2);
      expect(result[0].invigilatorId, iId);
      expect(result[1].invigilatorId, iId);
      expect(result[0].timeslotId != result[1].timeslotId, true, reason: "One invigilator can't be in two places at once");
    });

    test('Invigilator Conflict: Should fail if not enough invigilators for simultaneous exams', () async {
      // 2 courses with NO student conflict (could be simultaneous)
      await db.insert('Courses', {'name': 'C1', 'course_code': 'C1'});
      await db.insert('Courses', {'name': 'C2', 'course_code': 'C2'});

      // 2 Venues
      await db.insert('Venues', {'name': 'Room 1', 'capacity': 100});
      await db.insert('Venues', {'name': 'Room 2', 'capacity': 100});

      // 1 Timeslot
      await db.insert('TimeSlots', {'day': 'M', 'start_time': '9', 'end_time': '10'});

      // 1 Invigilator
      await db.insert('Invigilators', {'name': 'Prof. X'});

      // Should fail because 2 simultaneous exams need 2 invigilators, but only 1 slot/1 invigilator exists
      expect(() => TimetableGenerator.generate(), throwsA(isA<ConflictException>()));
    });
  });
}
