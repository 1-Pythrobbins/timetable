import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

class TimetableAnalytics {
  static Future<double> calculateVenueUtilization() async {
    final db = DatabaseHelper();
    final timetable = await db.queryAll('Timetable');
    final venues = await db.queryAll('Venues');
    
    if (timetable.isEmpty || venues.isEmpty) return 0.0;

    int totalStudents = 0;
    int totalCapacity = 0;

    for (var entry in timetable) {
      final courseId = entry['course_id'];
      final students = await db.getStudentIdsByCourse(courseId);
      totalStudents += students.length;

      final venueId = entry['venue_id'];
      final venue = venues.firstWhere((v) => v['id'] == venueId);
      totalCapacity += (venue['capacity'] as int);
    }

    return totalCapacity == 0 ? 0.0 : (totalStudents / totalCapacity) * 100;
  }

  static Future<List<Map<String, dynamic>>> getStudentDensity() async {
    final db = DatabaseHelper();
    final timetable = await db.queryAll('Timetable');
    final students = await db.queryAll('Students');
    final timeslots = await db.queryAll('TimeSlots');

    Map<int, Map<String, int>> studentExamCounts = {}; // studentId -> {day: count}

    for (var entry in timetable) {
      final slot = timeslots.firstWhere((ts) => ts['id'] == entry['timeslot_id']);
      final day = slot['day'];
      final courseId = entry['course_id'];
      final enrolledStudentIds = await db.getStudentIdsByCourse(courseId);

      for (var sId in enrolledStudentIds) {
        studentExamCounts.putIfAbsent(sId, () => {});
        studentExamCounts[sId]![day] = (studentExamCounts[sId]![day] ?? 0) + 1;
      }
    }

    List<Map<String, dynamic>> densityList = [];
    studentExamCounts.forEach((sId, dayCounts) {
      dayCounts.forEach((day, count) {
        if (count > 1) {
          final student = students.firstWhere((s) => s['id'] == sId);
          densityList.add({
            'student_name': student['name'],
            'day': day,
            'exam_count': count,
          });
        }
      });
    });

    return densityList;
  }

  static Future<String> exportToCsv() async {
    final db = DatabaseHelper();
    final timetable = await db.getTimetableWithDetails();
    
    List<List<dynamic>> rows = [];
    rows.add(["ID", "Course", "Venue", "Invigilator", "Time Slot"]);

    for (var row in timetable) {
      rows.add([
        row['id'],
        row['course_name'],
        row['venue_name'],
        row['invigilator_name'],
        row['timeslot_label'],
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/timetable_export_${DateTime.now().millisecondsSinceEpoch}.csv";
    final file = File(path);
    await file.writeAsString(csvData);
    
    return path;
  }
}
