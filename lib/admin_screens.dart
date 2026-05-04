import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'models.dart';
import 'scheduler.dart';
import 'time_constraints_screen.dart';
import 'excel_helper.dart';
import 'export_helper.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Schedule', icon: Icon(Icons.calendar_month)),
              Tab(text: 'Courses', icon: Icon(Icons.book)),
              Tab(text: 'Venues', icon: Icon(Icons.room)),
              Tab(text: 'Invigilators', icon: Icon(Icons.security)),
              Tab(text: 'Students', icon: Icon(Icons.people)),
              Tab(text: 'Settings', icon: Icon(Icons.settings)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Global refresh could be implemented here
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            ScheduleGenerationTab(),
            DataManagementTab<Course>(
              table: 'courses',
              title: 'Course',
              icon: Icons.book,
            ),
            DataManagementTab<Venue>(
              table: 'venues',
              title: 'Venue',
              icon: Icons.room,
            ),
            DataManagementTab<Invigilator>(
              table: 'invigilators',
              title: 'Invigilator',
              icon: Icons.security,
            ),
            const StudentManagementTab(),
            const TimeConstraintsScreen(),
          ],
        ),
      ),
    );
  }
}

class ScheduleGenerationTab extends StatefulWidget {
  const ScheduleGenerationTab({super.key});

  @override
  State<ScheduleGenerationTab> createState() => _ScheduleGenerationTabState();
}

class _ScheduleGenerationTabState extends State<ScheduleGenerationTab> {
  bool _isGenerating = false;
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

  Future<void> _generate() async {
    setState(() => _isGenerating = true);
    try {
      final results = await TimetableGenerator.generate();
      await DatabaseHelper().saveTimetable(results.map((e) => e.toMap()).toList());
      await _loadTimetable();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timetable generated successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Generation Failed'),
          content: Text(e.toString()),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Entries',
                  value: _timetable.length.toString(),
                  icon: Icons.assignment,
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _StatCard(
                  title: 'Status',
                  value: _timetable.isEmpty ? 'Empty' : 'Active',
                  icon: _timetable.isEmpty ? Icons.warning_amber : Icons.check_circle,
                  color: _timetable.isEmpty ? Colors.orange : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.withOpacity(0.8), Colors.indigo.withOpacity(0.8)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('Scheduling Engine', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text(
                      'Automated conflict-free timetable generation using native Dart backtracking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating ? null : _generate,
                            icon: _isGenerating 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple)) 
                                : const Icon(Icons.auto_awesome),
                            label: Text(_isGenerating ? 'Generating...' : 'Generate Timetable'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        if (_timetable.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: () => ExportHelper.showExportDialog(context, _timetable),
                            icon: const Icon(Icons.share),
                            style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepPurple),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _timetable.isEmpty
                ? const Center(child: Text('No schedule generated.'))
                : ListView.builder(
                    itemCount: _timetable.length,
                    itemBuilder: (context, index) {
                      final item = _timetable[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${item['course_code']}: ${item['course_name']}'),
                          subtitle: Text('Venue: ${item['venue_name']} • Date: ${item['date']} • Time: ${item['time_slot']}'),
                          trailing: Text(item['invigilator_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
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

class DataManagementTab<T> extends StatefulWidget {
  final String table;
  final String title;
  final IconData icon;

  const DataManagementTab({
    super.key,
    required this.table,
    required this.title,
    required this.icon,
  });

  @override
  State<DataManagementTab<T>> createState() => _DataManagementTabState<T>();
}

class _DataManagementTabState<T> extends State<DataManagementTab<T>> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final data = await DatabaseHelper().queryAll(widget.table);
    setState(() {
      _items = data;
    });
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final headController = TextEditingController();
    final deptController = TextEditingController();
    final capController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${widget.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.table == 'courses') ...[
                TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Course Code')),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Course Name')),
                TextField(controller: headController, decoration: const InputDecoration(labelText: 'Headcount'), keyboardType: TextInputType.number),
              ] else if (widget.table == 'venues') ...[
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Venue Name')),
                TextField(controller: capController, decoration: const InputDecoration(labelText: 'Capacity'), keyboardType: TextInputType.number),
              ] else if (widget.table == 'invigilators') ...[
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: deptController, decoration: const InputDecoration(labelText: 'Department')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Map<String, dynamic> data = {};
              if (widget.table == 'courses') {
                data = {
                  'code': codeController.text,
                  'name': nameController.text,
                  'headcount': int.tryParse(headController.text) ?? 0,
                  'is_alias': 0,
                };
              } else if (widget.table == 'venues') {
                data = {
                  'name': nameController.text,
                  'capacity': int.tryParse(capController.text) ?? 0,
                };
              } else if (widget.table == 'invigilators') {
                data = {
                  'name': nameController.text,
                  'department': deptController.text,
                  'max_days_per_week': 3,
                };
              }
              await DatabaseHelper().insert(widget.table, data);
              if (!mounted) return;
              Navigator.pop(context);
              _refresh();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'excel_${widget.table}',
            onPressed: () async {
              final result = await ExcelHelper.importData(widget.table);
              _refresh();
              if (mounted) {
                if (result.containsKey('error')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${result['error']}'), backgroundColor: Colors.red),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${result['count']} ${widget.title}s imported from Excel')),
                  );
                }
              }
            },
            mini: true,
            backgroundColor: Colors.green,
            child: const Icon(Icons.upload_file),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_${widget.table}',
            onPressed: _showAddDialog,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'clear_${widget.table}',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Data?'),
                  content: Text('Are you sure you want to delete all ${widget.title}s?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear All', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                await DatabaseHelper().clearTable(widget.table);
                _refresh();
              }
            },
            mini: true,
            backgroundColor: Colors.red,
            child: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No data entry yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  child: ListTile(
                    leading: Icon(widget.icon),
                    title: Text(widget.table == 'courses' ? '${item['code']}: ${item['name']}' : (item['name'] ?? 'Unknown')),
                    subtitle: Text(widget.table == 'courses' 
                        ? 'Code: ${item['code']} • Students: ${item['headcount']}'
                        : widget.table == 'venues'
                            ? 'Capacity: ${item['capacity']}'
                            : 'Dept: ${item['department']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await DatabaseHelper().delete(widget.table, where: 'id = ?', whereArgs: [item['id']]);
                        _refresh();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
class StudentManagementTab extends StatefulWidget {
  const StudentManagementTab({super.key});

  @override
  State<StudentManagementTab> createState() => _StudentManagementTabState();
}

class _StudentManagementTabState extends State<StudentManagementTab> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final data = await _db.getStudents();
    setState(() => _students = data);
  }

  void _showAddStudentDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: idController, decoration: const InputDecoration(labelText: 'Student ID')),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _db.addStudent(idController.text, nameController.text);
              if (!mounted) return;
              Navigator.pop(context);
              _refresh();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showManageCoursesDialog(Map<String, dynamic> student) async {
    final allCourses = await _db.queryAll('courses');
    final registeredCourses = await _db.getStudentCourses(student['student_id']);
    final registeredCodes = registeredCourses.map((e) => e['course_code']).toSet();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Manage Courses for ${student['name']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allCourses.length,
              itemBuilder: (context, index) {
                final course = allCourses[index];
                final isRegistered = registeredCodes.contains(course['code']);
                return CheckboxListTile(
                  title: Text('${course['code']}: ${course['name']}'),
                  value: isRegistered,
                  onChanged: (val) async {
                    if (val == true) {
                      await _db.addStudentToCourse(student['student_id'], course['code']);
                      registeredCodes.add(course['code']);
                    } else {
                      await _db.removeStudentFromCourse(student['student_id'], course['code']);
                      registeredCodes.remove(course['code']);
                    }
                    setDialogState(() {});
                  },
                );
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'excel_students',
            onPressed: () async {
              final result = await ExcelHelper.importData('students');
              _refresh();
              if (mounted) {
                final unknown = result['unknownCourses'] as List<String>;
                if (unknown.isNotEmpty) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Unknown Courses Found'),
                      content: Text(
                        'The following courses were mentioned in the student data but were not in your official course list. They have been automatically added with 0 headcount:\n\n${unknown.join(", ")}'
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Students imported from Excel')),
                  );
                }
              }
            },
            mini: true,
            backgroundColor: Colors.green,
            child: const Icon(Icons.upload_file),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_student',
            onPressed: _showAddStudentDialog,
            child: const Icon(Icons.person_add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'clear_students',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Students?'),
                  content: const Text('Are you sure you want to delete all students and their course registrations?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear All', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                await _db.clearTable('students');
                _refresh();
              }
            },
            mini: true,
            backgroundColor: Colors.red,
            child: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: _students.isEmpty
          ? const Center(child: Text('No students added.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(student['name']),
                    subtitle: Text('ID: ${student['student_id']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.book, color: Colors.blue),
                          onPressed: () => _showManageCoursesDialog(student),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await _db.deleteStudent(student['id']);
                            _refresh();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
