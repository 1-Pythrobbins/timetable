import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'models.dart';
import 'scheduler.dart';
import 'analytics.dart';
import 'package:flutter/foundation.dart'; // for compute/Isolates
import 'importer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam Timetable Manager',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📝 Offline Exam Manager'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
              Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
              Tab(text: 'Students', icon: Icon(Icons.person)),
              Tab(text: 'Courses', icon: Icon(Icons.book)),
              Tab(text: 'Venues', icon: Icon(Icons.room)),
              Tab(text: 'Invigilators', icon: Icon(Icons.security)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {}),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            DashboardTab(),
            AnalyticsTab(),
            DataListTab(table: 'Students', title: 'Student'),
            CoursesTab(),
            DataListTab(table: 'Venues', title: 'Venue'),
            DataListTab(table: 'Invigilators', title: 'Invigilator'),
          ],
        ),
      ),
    );
  }
}

// --- Dashboard Tab ---

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _isGenerating = false;
  String? _error;
  List<Map<String, dynamic>> _timetable = [];

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    final data = await DatabaseHelper().getTimetableWithDetails();
    setState(() {
      _timetable = data;
    });
  }

  bool _isImporting = false;

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    try {
      final results = await ExcelImporter.importFromExcel();
      if (!mounted) return;
      
      String summary = results.entries
          .where((e) => e.value > 0)
          .map((e) => "${e.key}: ${e.value}")
          .join(", ");
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import Successful: $summary'), backgroundColor: Colors.green),
      );
      setState(() {}); // Refresh UI
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _handleDownloadTemplate() async {
    try {
      final path = await ExcelImporter.downloadTemplate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template saved to: $path'), backgroundColor: Colors.blue),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save template: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _generateTimetable() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final entries = await compute(_runGeneratorInIsolate, null);
      await DatabaseHelper().saveTimetable(entries.map((e) => e.toMap()).toList());
      await _loadTimetable();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timetable generated successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  static Future<List<TimetableEntry>> _runGeneratorInIsolate(dynamic _) async {
    return await TimetableGenerator.generate();
  }

  Future<void> _seedData() async {
    final db = DatabaseHelper();
    
    // Clear all
    await db.delete('Students', '1=1', []);
    await db.delete('Courses', '1=1', []);
    await db.delete('Venues', '1=1', []);
    await db.delete('TimeSlots', '1=1', []);
    await db.delete('Invigilators', '1=1', []);

    // Students
    for(int i=1; i<=10; i++) await db.insert('Students', {'name': 'Student $i', 'student_code': 'S00$i'});
    
    // Invigilators
    await db.insert('Invigilators', {'name': 'Prof. Xavier'});
    await db.insert('Invigilators', {'name': 'Dr. Strange'});

    // Courses
    final c1 = await db.insert('Courses', {'name': 'Mathematics', 'course_code': 'MATH101'});
    final c2 = await db.insert('Courses', {'name': 'Physics', 'course_code': 'PHYS101'});
    final c3 = await db.insert('Courses', {'name': 'Chemistry', 'course_code': 'CHEM101'});

    // Enrolments
    for(int i=1; i<=5; i++) await db.insert('StudentCourses', {'student_id': i, 'course_id': c1});
    for(int i=4; i<=8; i++) await db.insert('StudentCourses', {'student_id': i, 'course_id': c2});
    for(int i=8; i<=10; i++) await db.insert('StudentCourses', {'student_id': i, 'course_id': c3});

    // Venues
    await db.insert('Venues', {'name': 'Main Hall', 'capacity': 50});
    await db.insert('Venues', {'name': 'Lab A', 'capacity': 5});

    // TimeSlots
    await db.insert('TimeSlots', {'day': 'Monday', 'start_time': '09:00', 'end_time': '11:00'});
    await db.insert('TimeSlots', {'day': 'Monday', 'start_time': '14:00', 'end_time': '16:00'});

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database Seeded!')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateTimetable,
                icon: _isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bolt),
                label: const Text('Generate Timetable'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              ),
              OutlinedButton.icon(
                onPressed: _isImporting ? null : _handleImport,
                icon: _isImporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Icon(Icons.upload_file),
                label: const Text('Import Excel'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _handleDownloadTemplate,
                icon: const Icon(Icons.download),
                label: const Text('Download Excel Template'),
              ),
              OutlinedButton(onPressed: _seedData, child: const Text('Seed Test Data')),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Card(
              color: Colors.red.withOpacity(0.2),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ),
          const Divider(),
          const Text('Final Schedule', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: _timetable.isEmpty
              ? const Center(child: Text('No timetable generated yet.'))
              : ListView.builder(
                  itemCount: _timetable.length,
                  itemBuilder: (context, index) {
                    final row = _timetable[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${index+1}')),
                        title: Text(row['course_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${row['venue_name']} • ${row['timeslot_label']}'),
                            Text('Invigilator: ${row['invigilator_name']}', style: const TextStyle(color: Colors.deepPurpleAccent)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

// --- Analytics Tab ---

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Timetable Insights', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        FutureBuilder<double>(
          future: TimetableAnalytics.calculateVenueUtilization(),
          builder: (context, snapshot) {
            final utilization = snapshot.data ?? 0.0;
            return Card(
              color: Colors.deepPurple.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('Venue Utilization Rate', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 10),
                    Text('${utilization.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: utilization / 100, color: Colors.deepPurpleAccent, backgroundColor: Colors.white10),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text('Student Density Issues (Daily)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: TimetableAnalytics.getStudentDensity(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Card(child: ListTile(title: Text('No students have multiple exams per day.'), leading: Icon(Icons.check_circle, color: Colors.green)));
            }
            final list = snapshot.data!;
            return Column(
              children: list.map((item) => Card(
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.amber),
                  title: Text(item['student_name']),
                  subtitle: Text('Day: ${item['day']}'),
                  trailing: Text('${item['exam_count']} Exams', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ),
              )).toList(),
            );
          },
        ),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          onPressed: _isExporting ? null : () async {
            setState(() => _isExporting = true);
            try {
              final path = await TimetableAnalytics.exportToCsv();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report saved to: $path')));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
              }
            } finally {
              setState(() => _isExporting = false);
            }
          },
          icon: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Icon(Icons.download),
          label: const Text('Download CSV Report'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.green, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}

// --- Data Management Generic Tab ---

class DataListTab extends StatelessWidget {
  final String table;
  final String title;
  const DataListTab({super.key, required this.table, required this.title});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper().queryAll(table),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              tileColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: Text(item['name'] ?? 'ID ${item['id']}'),
              subtitle: Text(item.containsKey('student_code') ? 'Code: ${item['student_code']}' : item.containsKey('capacity') ? 'Capacity: ${item['capacity']}' : ''),
            );
          },
        );
      },
    );
  }
}

// --- Courses Tab (Custom for Enrollment) ---

class CoursesTab extends StatelessWidget {
  const CoursesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseHelper();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: db.queryAll('Courses'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final courses = snapshot.data!;
        return ListView.builder(
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final course = courses[index];
            return FutureBuilder<List<int>>(
              future: db.getStudentIdsByCourse(course['id']),
              builder: (context, sSnapshot) {
                final count = sSnapshot.data?.length ?? 0;
                return ListTile(
                  title: Text(course['name']),
                  subtitle: Text('Code: ${course['course_code']}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(20)),
                    child: Text('$count Students', style: const TextStyle(fontSize: 12)),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}