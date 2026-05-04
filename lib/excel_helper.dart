import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'database_helper.dart';

class ExcelHelper {
  static final _db = DatabaseHelper();

  static String? _getVal(Data? data) {
    if (data == null || data.value == null) return null;
    String val = data.value.toString().trim();
    return val.isEmpty ? null : val;
  }

  static int _parseInt(String? val, {int defaultValue = 0}) {
    if (val == null) return defaultValue;
    String clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? defaultValue;
  }

  static String? _getRowVal(List<Data?> row, int idx) {
    if (idx < 0 || idx >= row.length) return null;
    return _getVal(row[idx]);
  }

  static Future<Map<String, dynamic>> importData(String type) async {
    List<String> unknownCourses = [];
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) return {'count': 0, 'unknownCourses': []};

      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      int totalImported = 0;
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null || sheet.maxRows == 0) continue;

        // Default indices
        int nameIdx = 1, capIdx = 1, codeIdx = 0, headcountIdx = 2, deptIdx = 1, maxDaysIdx = 2;
        int studIdIdx = 0, studNameIdx = 1, studCoursesIdx = 2;
        bool headerFound = false;
        int headerRowIdx = -1;

        // Scan first 15 rows for a potential header
        int rowsToScan = sheet.maxRows > 15 ? 15 : sheet.maxRows;
        for (int i = 0; i < rowsToScan; i++) {
          var row = sheet.rows[i];
          int matches = 0;
          int tempCodeIdx = -1, tempNameIdx = -1, tempStudIdIdx = -1;
          
          for (int j = 0; j < row.length; j++) {
            String col = _getVal(row[j])?.toLowerCase() ?? '';
            if (col.isEmpty) continue;
            
            bool matched = false;
            if (col == 'code' || col == 'course code' || col == 'course_code' || col == 'course') { tempCodeIdx = j; matched = true; }
            else if (col == 'name' || col == 'course name' || col == 'title' || col == 'course title') { tempNameIdx = j; matched = true; }
            else if (col == 'id' || col == 'student id' || col == 'index' || col == 'student_id') { tempStudIdIdx = j; matched = true; }
            else if (col == 'capacity' || col == 'cap' || col == 'size' || col == 'seats') matched = true;
            else if (col == 'headcount' || col == 'students' || col == 'count' || col == 'total') matched = true;
            else if (col == 'dept' || col == 'department' || col == 'faculty') matched = true;
            else if (col == 'courses' || col == 'registered courses' || col == 'subjects') matched = true;
            
            if (matched) matches++;
          }

          // Require at least 2 matches to be a real header, unless it's a very simple sheet
          if (matches >= 2 || (matches >= 1 && sheet.maxRows < 10)) {
            headerFound = true;
            headerRowIdx = i;
            // Apply identified indices
            if (tempCodeIdx != -1) codeIdx = tempCodeIdx;
            if (tempNameIdx != -1) { nameIdx = tempNameIdx; studNameIdx = tempNameIdx; }
            if (tempStudIdIdx != -1) studIdIdx = tempStudIdIdx;
            break;
          }
        }

        print('--- Importing Sheet: $table | Header Found: $headerFound (Row $headerRowIdx) ---');
        if (headerFound) {
          // Re-scan the header row to set all specific indices correctly
          var hRow = sheet.rows[headerRowIdx];
          print('HEADER ROW DETECTED: ${hRow.map((cell) => _getVal(cell)).toList()}');
          for (int j = 0; j < hRow.length; j++) {
            String col = _getVal(hRow[j])?.toLowerCase() ?? '';
            if (col.contains('code') && !col.contains('stud')) codeIdx = j;
            if (col.contains('name') || col.contains('title')) { nameIdx = j; studNameIdx = j; }
            if (col.contains('cap') || col.contains('size') || col.contains('seats')) capIdx = j;
            if (col.contains('head') || col.contains('count') || col.contains('total') || col.contains('stud')) headcountIdx = j;
            if (col.contains('dept') || col.contains('faculty')) deptIdx = j;
            if (col.contains('max') && col.contains('day')) maxDaysIdx = j;
            if (col.contains('stud') || col.contains('id') || col.contains('index')) studIdIdx = j;
            if (col.contains('course') || col.contains('subject') || col.contains('register')) studCoursesIdx = j;
          }
        }
        print('Using indices: codeIdx=$codeIdx, nameIdx=$nameIdx, headcountIdx=$headcountIdx, studIdIdx=$studIdIdx, coursesIdx=$studCoursesIdx');

        int startRow = headerFound ? headerRowIdx + 1 : 0;
        int sheetCount = 0;

        // Pre-fetch all course codes for fast check
        final existingCourses = (await _db.queryAll('courses')).map((c) => c['code'].toString()).toSet();

        for (var i = startRow; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          if (row.isEmpty) continue;

          // Print a preview of the first data row to help debug
          if (i == startRow) {
            print('--- DATA PREVIEW (Row $i) ---');
            print(row.map((cell) => _getVal(cell)).toList());
          }

          try {
            if (type == 'courses') {
              String? code = _getRowVal(row, codeIdx);
              String? name = _getRowVal(row, nameIdx);
              final headcount = _parseInt(_getRowVal(row, headcountIdx));
              
              // Fallback: If code is 'None' but ID column has a value, try that
              if ((code == null || code.toLowerCase() == 'none') && studIdIdx != codeIdx) {
                final fallback = _getRowVal(row, studIdIdx);
                if (fallback != null && fallback.toLowerCase() != 'none') {
                  code = fallback;
                }
              }

              if (code != null && 
                  code.toLowerCase() != 'none' && 
                  code.toLowerCase() != 'n/a' && 
                  code.toLowerCase() != 'null') {
                await _db.insert('courses', {
                  'code': code, 
                  'name': name ?? code, 
                  'headcount': headcount, 
                  'is_alias': 0
                });
                sheetCount++;
                print('Row $i: Imported course $code');
              } else {
                print('Row $i: Skipped (invalid or null code: $code)');
              }
            } else if (type == 'venues') {
              final vName = _getRowVal(row, nameIdx);
              final capacity = _parseInt(_getRowVal(row, capIdx));
              if (vName != null) {
                await _db.insert('venues', {'name': vName, 'capacity': capacity});
                sheetCount++;
              }
            } else if (type == 'invigilators') {
              final invName = _getRowVal(row, nameIdx);
              final dept = _getRowVal(row, deptIdx);
              final maxDays = _parseInt(_getRowVal(row, maxDaysIdx), defaultValue: 3);
              if (invName != null) {
                String d = (dept == null || invName == dept) ? 'General' : dept;
                await _db.insert('invigilators', {'name': invName, 'department': d, 'max_days_per_week': maxDays});
                sheetCount++;
              }
            } else if (type == 'students') {
              final studentId = _getRowVal(row, studIdIdx);
              final studentName = _getRowVal(row, studNameIdx);
              if (studentId != null && studentName != null) {
                await _db.addStudent(studentId, studentName);
                if (studCoursesIdx < row.length) {
                  final coursesVal = _getRowVal(row, studCoursesIdx);
                  if (coursesVal != null) {
                    for (var code in coursesVal.split(RegExp(r'[,;]'))) {
                      final trimmed = code.trim();
                      if (trimmed.isEmpty) continue;
                      
                      if (!existingCourses.contains(trimmed)) {
                        await _db.insert('courses', {
                          'code': trimmed, 'name': trimmed, 'headcount': 0, 'is_alias': 0
                        });
                        if (!unknownCourses.contains(trimmed)) unknownCourses.add(trimmed);
                        existingCourses.add(trimmed);
                      }
                      await _db.addStudentToCourse(studentId, trimmed);
                    }
                  }
                }
                sheetCount++;
              }
            }
          } catch (e) {
            print('Error importing row $i: $e');
          }
        }
        totalImported += sheetCount;
      }
      return {'count': totalImported, 'unknownCourses': unknownCourses};
    } catch (e) {
      print('Import failed: $e');
      return {'count': 0, 'unknownCourses': [], 'error': e.toString()};
    }
  }
}
