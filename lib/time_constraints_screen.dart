import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

class TimeConstraintsScreen extends StatefulWidget {
  const TimeConstraintsScreen({super.key});

  @override
  State<TimeConstraintsScreen> createState() => _TimeConstraintsScreenState();
}

class _TimeConstraintsScreenState extends State<TimeConstraintsScreen> {
  final _db = DatabaseHelper();
  
  DateTime? _startDate;
  DateTime? _endDate;
  bool _allowWeekends = false;
  int _maxExamsPerDay = 2;
  
  List<Map<String, dynamic>> _timeslots = [];
  List<String> _blackoutDates = [];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final constraints = await _db.getTimeConstraints();
    final timeslots = await _db.getTimeslots();
    final blackouts = await _db.getBlackoutDates();

    setState(() {
      if (constraints['start_date'] != null) {
        _startDate = DateTime.parse(constraints['start_date']);
      }
      if (constraints['end_date'] != null) {
        _endDate = DateTime.parse(constraints['end_date']);
      }
      _allowWeekends = constraints['allow_weekends'] == 1;
      _maxExamsPerDay = constraints['max_exams_per_day'] ?? 2;
      _timeslots = List.from(timeslots);
      _blackoutDates = List.from(blackouts);
      _isLoading = false;
    });
  }

  Future<void> _saveConstraints() async {
    await _db.updateTimeConstraints({
      'start_date': _startDate?.toIso8601String(),
      'end_date': _endDate?.toIso8601String(),
      'allow_weekends': _allowWeekends ? 1 : 0,
      'max_exams_per_day': _maxExamsPerDay,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('General constraints saved')));
    }
  }

  void _addBlackoutDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      await _db.addBlackoutDate(dateStr);
      _loadAll();
    }
  }

  void _addTimeslot() async {
    final startTime = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 30));
    if (startTime == null) return;
    
    final endTime = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 11, minute: 30));
    if (endTime == null) return;

    final startStr = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
    final endStr = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}";
    
    await _db.addTimeslot(startStr, endStr);
    _loadAll();
  }

  void _loadGhanaianHolidays() async {
    final holidays = [
      '2024-01-01', '2024-01-07', '2024-03-06', '2024-03-29', '2024-04-01',
      '2024-05-01', '2024-08-04', '2024-09-21', '2024-12-06', '2024-12-25', '2024-12-26',
      '2025-01-01', '2025-01-07', '2025-03-06', '2025-04-18', '2025-04-21',
      '2025-05-01', '2025-08-04', '2025-09-21', '2025-12-05', '2025-12-25', '2025-12-26',
    ];
    for (var h in holidays) {
      await _db.addBlackoutDate(h);
    }
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Exam Period'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.date_range),
              title: Text(_startDate == null || _endDate == null 
                ? 'Select Date Range' 
                : '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2035),
                  initialDateRange: _startDate != null && _endDate != null 
                    ? DateTimeRange(start: _startDate!, end: _endDate!) 
                    : null,
                );
                if (range != null) {
                  setState(() {
                    _startDate = range.start;
                    _endDate = range.end;
                  });
                  _saveConstraints();
                }
              },
            ),
          ),
          
          const SizedBox(height: 16),
          _buildSectionTitle('General Constraints'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Allow Weekend Exams'),
                  subtitle: const Text('Include Saturdays and Sundays'),
                  value: _allowWeekends,
                  onChanged: (val) {
                    setState(() => _allowWeekends = val);
                    _saveConstraints();
                  },
                ),
                ListTile(
                  title: const Text('Max Exams per Day per Student Group'),
                  subtitle: Text('Current limit: $_maxExamsPerDay'),
                  trailing: SizedBox(
                    width: 130, // Increased width to prevent overflow
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Use min size
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline), 
                          onPressed: () {
                            if (_maxExamsPerDay > 1) {
                              setState(() => _maxExamsPerDay--);
                              _saveConstraints();
                            }
                          }
                        ),
                        Text('$_maxExamsPerDay', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline), 
                          onPressed: () {
                            setState(() => _maxExamsPerDay++);
                            _saveConstraints();
                          }
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildSectionTitle('Daily Sessions (Timeslots)'),
              IconButton(onPressed: _addTimeslot, icon: const Icon(Icons.add_circle, color: Colors.deepPurple)),
            ],
          ),
          ..._timeslots.map((slot) => Card(
            child: ListTile(
              leading: const Icon(Icons.access_time),
              title: Text('${slot['start_time']} - ${slot['end_time']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  await _db.deleteTimeslot(slot['id']);
                  _loadAll();
                },
              ),
            ),
          )),

          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildSectionTitle('Blackout Dates (Holidays)'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _loadGhanaianHolidays, 
                    child: const Text('Load Ghana Holidays', style: TextStyle(fontSize: 13)),
                  ),
                  IconButton(onPressed: _addBlackoutDate, icon: const Icon(Icons.add_circle, color: Colors.deepPurple)),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: _blackoutDates.map((date) => Chip(
              label: Text(date),
              onDeleted: () async {
                await _db.removeBlackoutDate(date);
                _loadAll();
              },
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
    );
  }
}
