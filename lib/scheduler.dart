import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';

class ConflictException implements Exception {
  final String message;
  ConflictException(this.message);
  @override
  String toString() => message;
}

class TimetableGenerator {
  static Future<List<TimetableEntry>> generate() async {
    final db = DatabaseHelper();
    
    // 1. Load Data
    final coursesData = await db.queryAll('courses');
    final venuesData = await db.queryAll('venues');
    final invigilatorsData = await db.queryAll('invigilators');
    
    // 2. Load Constraints
    final constraints = await db.getTimeConstraints();
    final timeslotsData = await db.getTimeslots();
    final blackoutDates = await db.getBlackoutDates();

    List<Course> courses = coursesData.map((m) => Course.fromMap(m)).toList();
    List<Venue> venues = venuesData.map((m) => Venue.fromMap(m)).toList();
    List<Invigilator> invigilators = invigilatorsData.map((m) => Invigilator.fromMap(m)).toList();

    if (courses.isEmpty || venues.isEmpty || invigilators.isEmpty) {
      throw ConflictException("Data missing: Ensure courses, venues, and invigilators are added.");
    }

    if (constraints['start_date'] == null || constraints['end_date'] == null) {
      throw ConflictException("Time constraints missing: Please set the exam period in Settings.");
    }

    if (timeslotsData.isEmpty) {
      throw ConflictException("No timeslots defined: Please add at least one exam session in Settings.");
    }

    DateTime startDate = DateTime.parse(constraints['start_date']);
    DateTime endDate = DateTime.parse(constraints['end_date']);
    int durationDays = endDate.difference(startDate).inDays + 1;
    bool allowWeekends = constraints['allow_weekends'] == 1;
    int maxExamsPerDayLimit = constraints['max_exams_per_day'] ?? 2;
    List<String> dynamicTimeSlots = timeslotsData.map((s) => "${s['start_time']} - ${s['end_time']}").toList();

    // Separate parent courses and aliases
    List<Course> mainCourses = courses.where((c) => !c.isAlias).toList();
    Map<String, List<Course>> aliases = {};
    for (var c in courses.where((c) => c.isAlias)) {
      if (c.parentCourseCode != null) {
        aliases.putIfAbsent(c.parentCourseCode!, () => []).add(c);
      }
    }

    // Sort courses by total group headcount descending (Most difficult first)
    mainCourses.sort((a, b) {
      int aTotal = a.headcount + (aliases[a.code]?.fold(0, (sum, c) => sum! + c.headcount) ?? 0);
      int bTotal = b.headcount + (aliases[b.code]?.fold(0, (sum, c) => sum! + c.headcount) ?? 0);
      return bTotal.compareTo(aTotal);
    });

    // 3. Load Student Data for Clash Detection
    final courseToStudents = await db.getStudentCourseMap();

    List<TimetableEntry> result = [];
    
    // Constraints tracking
    Map<int, Set<String>> invigilatorDays = {}; 
    Map<String, int> dailyExamsPerGroup = {}; 
    Map<String, Set<String>> studentSlots = {}; // "date_slot" -> Set of student IDs

    bool success = _backtrack(
      0, 
      mainCourses, 
      aliases, 
      venues, 
      invigilators, 
      startDate, 
      durationDays, 
      allowWeekends,
      Set.from(blackoutDates),
      dynamicTimeSlots,
      maxExamsPerDayLimit,
      invigilatorDays, 
      dailyExamsPerGroup, 
      studentSlots,
      courseToStudents,
      result
    );

    if (!success) {
      throw ConflictException("Could not satisfy all constraints. Try adding more venues/invigilators, increasing the duration, or allowing weekends.");
    }

    return result;
  }

  static bool _backtrack(
    int idx,
    List<Course> mainCourses,
    Map<String, List<Course>> aliases,
    List<Venue> venues,
    List<Invigilator> invigilators,
    DateTime start,
    int duration,
    bool allowWeekends,
    Set<String> blackouts,
    List<String> timeSlots,
    int maxExamsPerDayLimit,
    Map<int, Set<String>> invigilatorDays,
    Map<String, int> dailyExamsPerGroup,
    Map<String, Set<String>> studentSlots,
    Map<String, List<String>> courseToStudents,
    List<TimetableEntry> result,
  ) {
    if (idx == mainCourses.length) return true;

    Course course = mainCourses[idx];
    List<Course> group = [course, ...(aliases[course.code] ?? [])];
    int totalHeadcount = group.fold(0, (sum, c) => sum + c.headcount);

    // Get all students in this group
    Set<String> groupStudents = {};
    for (var c in group) {
      groupStudents.addAll(courseToStudents[c.code] ?? []);
    }

    for (int d = 0; d < duration; d++) {
      DateTime date = start.add(Duration(days: d));
      
      // Weekend Check
      if (!allowWeekends && (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)) continue;
      
      // Blackout Check
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      if (blackouts.contains(dateKey)) continue;

      String groupKey = "${dateKey}_$totalHeadcount";
      if ((dailyExamsPerGroup[groupKey] ?? 0) >= maxExamsPerDayLimit) continue;

      for (String slot in timeSlots) {
        String slotKey = "${dateKey}_$slot";
        
        // Student Clash Check
        bool studentClash = false;
        if (studentSlots.containsKey(slotKey)) {
          for (var sid in groupStudents) {
            if (studentSlots[slotKey]!.contains(sid)) {
              studentClash = true;
              break;
            }
          }
        }
        if (studentClash) continue;

        for (var venue in venues) {
          if (venue.capacity < totalHeadcount) continue;

          bool venueBusy = result.any((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateKey && e.timeSlot == slot && e.venueId == venue.id);
          if (venueBusy) continue;

          for (var invigilator in invigilators) {
            bool invBusy = result.any((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateKey && e.timeSlot == slot && e.invigilatorId == invigilator.id);
            if (invBusy) continue;

            int weekOfYear = _getWeekOfYear(date);
            Set<String> assignedDates = invigilatorDays[invigilator.id!] ?? {};
            
            int daysThisWeek = assignedDates.where((dStr) => _getWeekOfYear(DateTime.parse(dStr)) == weekOfYear).length;
            bool alreadyAssignedToday = assignedDates.contains(dateKey);

            if (!alreadyAssignedToday && daysThisWeek >= invigilator.maxDaysPerWeek) continue;

            // Tentatively assign
            List<TimetableEntry> groupEntries = [];
            for (var c in group) {
              groupEntries.add(TimetableEntry(
                courseCode: c.code,
                venueId: venue.id!,
                date: date,
                timeSlot: slot,
                invigilatorId: invigilator.id!,
              ));
            }
            result.addAll(groupEntries);
            
            invigilatorDays.putIfAbsent(invigilator.id!, () => {}).add(dateKey);
            dailyExamsPerGroup[groupKey] = (dailyExamsPerGroup[groupKey] ?? 0) + 1;
            studentSlots.putIfAbsent(slotKey, () => {}).addAll(groupStudents);

            if (_backtrack(idx + 1, mainCourses, aliases, venues, invigilators, start, duration, allowWeekends, blackouts, timeSlots, maxExamsPerDayLimit, invigilatorDays, dailyExamsPerGroup, studentSlots, courseToStudents, result)) {
              return true;
            }

            // Backtrack
            for (var _ in groupEntries) result.removeLast();
            if (!alreadyAssignedToday) {
               if (!result.any((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateKey && e.invigilatorId == invigilator.id)) {
                 invigilatorDays[invigilator.id]!.remove(dateKey);
               }
            }
            dailyExamsPerGroup[groupKey] = dailyExamsPerGroup[groupKey]! - 1;
            for (var sid in groupStudents) {
              studentSlots[slotKey]!.remove(sid);
            }
          }
        }
      }
    }
    return false;

  }

  static int _getWeekOfYear(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    int w = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (w < 1) return 52;
    if (w > 52) return 1;
    return w;
  }
}

