import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

class ExcelImporter {
  static Future<int> importTable({required String table, required List<String> extensions}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );

    if (result == null || result.files.single.path == null) {
      throw Exception("No file selected.");
    }

    final file = File(result.files.single.path!);
    final extension = result.files.single.extension?.toLowerCase();
    
    if (extension == 'csv') {
      return await _importCsv(table, file);
    } else if (extension == 'xlsx') {
      return await _importExcelSpecific(table, file);
    }
    
    return 0;
  }

  static Future<int> _importCsv(String table, File file) async {
    final input = file.openRead();
    final fields = await input.transform(utf8.decoder).transform(const CsvToListConverter()).toList();
    
    if (fields.isEmpty) return 0;
    
    final db = DatabaseHelper();
    int count = 0;

    // Skip header row
    for (var i = 1; i < fields.length; i++) {
      final row = fields[i];
      if (row.isEmpty) continue;

      try {
        if (table == 'Students' && row.length >= 2) {
          await db.insert('Students', {'name': row[0].toString(), 'student_code': row[1].toString()});
          count++;
        } else if (table == 'Courses' && row.length >= 2) {
          await db.insert('Courses', {'name': row[0].toString(), 'course_code': row[1].toString()});
          count++;
        } else if (table == 'Venues' && row.length >= 2) {
          await db.insert('Venues', {'name': row[0].toString(), 'capacity': int.tryParse(row[1].toString()) ?? 0});
          count++;
        } else if (table == 'Invigilators' && row.isNotEmpty) {
          await db.insert('Invigilators', {'name': row[0].toString()});
          count++;
        }
      } catch (_) {} // Skip duplicates/errors
    }
    return count;
  }

  static Future<int> _importExcelSpecific(String tableName, File file) async {
    var bytes = file.readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);
    final db = DatabaseHelper();
    int count = 0;

    // Use specific sheet if named like table, else use first sheet
    var sheetName = excel.tables.containsKey(tableName) ? tableName : excel.tables.keys.first;
    var table = excel.tables[sheetName]!;

    for (var i = 1; i < table.maxRows; i++) {
        var row = table.rows[i];
        if (row.isEmpty) continue;

        try {
          if (tableName == 'Students' && row.length >= 2 && row[0] != null && row[1] != null) {
            await db.insert('Students', {'name': row[0]!.value.toString(), 'student_code': row[1]!.value.toString()});
            count++;
          } else if (tableName == 'Courses' && row.length >= 2 && row[0] != null && row[1] != null) {
            await db.insert('Courses', {'name': row[0]!.value.toString(), 'course_code': row[1]!.value.toString()});
            count++;
          } else if (tableName == 'Venues' && row.length >= 2 && row[0] != null && row[1] != null) {
            await db.insert('Venues', {'name': row[0]!.value.toString(), 'capacity': int.tryParse(row[1]!.value.toString()) ?? 0});
            count++;
          } else if (tableName == 'Invigilators' && row.isNotEmpty && row[0] != null) {
            await db.insert('Invigilators', {'name': row[0]!.value.toString()});
            count++;
          }
        } catch (_) {}
    }
    return count;
  }

  static Future<Map<String, int>> importFromExcel() async {
    // Keep existing multi-sheet import logic...
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

  static Future<String> exportTimetable(List<Map<String, dynamic>> timetable) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Timetable'];
    
    // Header
    sheet.appendRow([
      TextCellValue('Course'),
      TextCellValue('Venue'),
      TextCellValue('Time Slot'),
      TextCellValue('Invigilator'),
    ]);
    
    // Data
    for (var row in timetable) {
      sheet.appendRow([
        TextCellValue(row['course_name']?.toString() ?? ''),
        TextCellValue(row['venue_name']?.toString() ?? ''),
        TextCellValue(row['timeslot_label']?.toString() ?? ''),
        TextCellValue(row['invigilator_name']?.toString() ?? ''),
      ]);
    }
    
    excel.delete('Sheet1');
    
    var fileBytes = excel.save();
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = "${directory.path}/timetable_export_$timestamp.xlsx";
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);
      
    return path;
  }
}
