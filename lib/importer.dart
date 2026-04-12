import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

class ExcelImporter {
  static Future<Map<String, int>> importFromExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.single.path == null) {
      throw Exception("No file selected.");
    }

    var bytes = File(result.files.single.path!).readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);
    
    int studentsCount = 0;
    int coursesCount = 0;
    int venuesCount = 0;
    int invigilatorsCount = 0;

    final db = DatabaseHelper();

    // 1. Students
    if (excel.tables.containsKey('Students')) {
      var table = excel.tables['Students']!;
      for (var i = 1; i < table.maxRows; i++) {
        var row = table.rows[i];
        if (row.length >= 2 && row[0] != null && row[1] != null) {
          await db.insert('Students', {
            'name': row[0]!.value.toString(),
            'student_code': row[1]!.value.toString(),
          });
          studentsCount++;
        }
      }
    }

    // 2. Courses
    if (excel.tables.containsKey('Courses')) {
      var table = excel.tables['Courses']!;
      for (var i = 1; i < table.maxRows; i++) {
        var row = table.rows[i];
        if (row.length >= 2 && row[0] != null && row[1] != null) {
          await db.insert('Courses', {
            'name': row[0]!.value.toString(),
            'course_code': row[1]!.value.toString(),
          });
          coursesCount++;
        }
      }
    }

    // 3. Venues
    if (excel.tables.containsKey('Venues')) {
      var table = excel.tables['Venues']!;
      for (var i = 1; i < table.maxRows; i++) {
        var row = table.rows[i];
        if (row.length >= 2 && row[0] != null && row[1] != null) {
          await db.insert('Venues', {
            'name': row[0]!.value.toString(),
            'capacity': int.tryParse(row[1]!.value.toString()) ?? 0,
          });
          venuesCount++;
        }
      }
    }

    // 4. Invigilators
    if (excel.tables.containsKey('Invigilators')) {
      var table = excel.tables['Invigilators']!;
      for (var i = 1; i < table.maxRows; i++) {
        var row = table.rows[i];
        if (row.isNotEmpty && row[0] != null) {
          await db.insert('Invigilators', {
            'name': row[0]!.value.toString(),
          });
          invigilatorsCount++;
        }
      }
    }

    return {
      'Students': studentsCount,
      'Courses': coursesCount,
      'Venues': venuesCount,
      'Invigilators': invigilatorsCount,
    };
  }

  static Future<String> downloadTemplate() async {
    var excel = Excel.createExcel();

    // Students Sheet
    Sheet studentSheet = excel['Students'];
    studentSheet.appendRow([TextCellValue('Name'), TextCellValue('Student Code')]);
    studentSheet.appendRow([TextCellValue('John Doe'), TextCellValue('S001')]);

    // Courses Sheet
    Sheet courseSheet = excel['Courses'];
    courseSheet.appendRow([TextCellValue('Course Name'), TextCellValue('Course Code')]);
    courseSheet.appendRow([TextCellValue('Computer Science 101'), TextCellValue('CS101')]);

    // Venues Sheet
    Sheet venueSheet = excel['Venues'];
    venueSheet.appendRow([TextCellValue('Venue Name'), TextCellValue('Capacity')]);
    venueSheet.appendRow([TextCellValue('Main Hall'), TextCellValue('100')]);

    // Invigilators Sheet
    Sheet invigSheet = excel['Invigilators'];
    invigSheet.appendRow([TextCellValue('Invigilator Name')]);
    invigSheet.appendRow([TextCellValue('Dr. Smith')]);

    // Delete default sheet
    excel.delete('Sheet1');

    var fileBytes = excel.save();
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/timetable_template.xlsx";
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    return path;
  }
}
