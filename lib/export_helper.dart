import 'package:intl/intl.dart';
import 'dart:io';
import 'package:excel/excel.dart' as ex;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class ExportHelper {
  static Future<void> showExportDialog(BuildContext context, List<Map<String, dynamic>> data) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Export Timetable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                exportToPdf(data);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Export as Excel & Share'),
              onTap: () {
                Navigator.pop(context);
                exportToExcel(data);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> exportToPdf(List<Map<String, dynamic>> data) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Examination Timetable')),
          pw.Table.fromTextArray(
            headers: ['Course Code', 'Course Name', 'Venue', 'Date', 'Time Slot', 'Invigilator'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellPadding: const pw.EdgeInsets.all(5),
            data: data.map((e) {
              final dateStr = e['date']?.toString() ?? '';
              String formattedDate = dateStr;
              try {
                final date = DateTime.parse(dateStr);
                formattedDate = DateFormat('yyyy-MM-dd').format(date);
              } catch (_) {}
              
              return [
                e['course_code'],
                e['course_name'] ?? 'N/A',
                e['venue_name'],
                formattedDate,
                e['time_slot'],
                e['invigilator_name']
              ];
            }).toList(),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  static Future<void> exportToExcel(List<Map<String, dynamic>> data) async {
    var excel = ex.Excel.createExcel();
    var sheet = excel['Timetable'];
    sheet.appendRow([
      ex.TextCellValue('Course Code'),
      ex.TextCellValue('Course Name'),
      ex.TextCellValue('Venue'),
      ex.TextCellValue('Date'),
      ex.TextCellValue('Time Slot'),
      ex.TextCellValue('Invigilator'),
    ]);
    for (var row in data) {
      final dateStr = row['date']?.toString() ?? '';
      String formattedDate = dateStr;
      try {
        final date = DateTime.parse(dateStr);
        formattedDate = DateFormat('yyyy-MM-dd').format(date);
      } catch (_) {}

      sheet.appendRow([
        ex.TextCellValue(row['course_code']?.toString() ?? ''),
        ex.TextCellValue(row['course_name']?.toString() ?? 'N/A'),
        ex.TextCellValue(row['venue_name']?.toString() ?? ''),
        ex.TextCellValue(formattedDate),
        ex.TextCellValue(row['time_slot']?.toString() ?? ''),
        ex.TextCellValue(row['invigilator_name']?.toString() ?? ''),
      ]);
    }
    final bytes = excel.save();
    if (bytes == null) return;
    
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/timetable.xlsx');
    await file.writeAsBytes(bytes);
    
    await Share.shareXFiles([XFile(file.path)], text: 'Examination Timetable');
  }
}
