import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'admin_screens.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SQLite for Desktop (Windows) if needed
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Pre-initialize database to ensure it's ready
  await DatabaseHelper().database;

  runApp(const ExamTimetableApp());
}

class ExamTimetableApp extends StatelessWidget {
  const ExamTimetableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Intelligent Exam Timetable Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Inter', // Premium look
        cardTheme: CardThemeData(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        ),
      ),
      home: const AdminDashboard(),
    );
  }
}
