import 'models.dart';
import 'database_helper.dart';

class ConflictException implements Exception {
  final String message;
  ConflictException(this.message);
}

class TimetableGenerator {
  static Future<List<TimetableEntry>> generate() async {
    final db = DatabaseHelper();

    // 1. Fetch data
    final coursesData = await db.queryAll('Courses');
    final venuesData = await db.queryAll('Venues');
    final timeslotsData = await db.queryAll('TimeSlots');
    final invigilatorsData = await db.queryAll('Invigilators');

    final List<Course> courses = coursesData.map((m) => Course.fromMap(m)).toList();
    final List<Venue> venues = venuesData.map((m) => Venue.fromMap(m)).toList();
    final List<TimeSlot> timeslots = timeslotsData.map((m) => TimeSlot.fromMap(m)).toList();
    final List<Invigilator> invigilators = invigilatorsData.map((m) => Invigilator.fromMap(m)).toList();

    if (courses.isEmpty || venues.isEmpty || timeslots.isEmpty || invigilators.isEmpty) {
      throw ConflictException("Missing data: Courses, Venues, TimeSlots, and Invigilators must be populated.");
    }

    // 2. Fetch student sets for each course
    Map<int, Set<int>> courseStudents = {};
    for (var course in courses) {
      final studentIds = await db.getStudentIdsByCourse(course.id!);
      courseStudents[course.id!] = studentIds.toSet();
      course.enrolledCount = studentIds.length;
    }

    // Sort courses by difficulty (those with most students first)
    courses.sort((a, b) => b.enrolledCount.compareTo(a.enrolledCount));

    List<TimetableEntry> result = [];
    
    // 3. Backtracking Algorithm
    bool success = _backtrack(0, courses, venues, timeslots, invigilators, courseStudents, result);

    if (!success) {
      throw ConflictException("Constraint Violation: Unable to find a valid schedule for all courses with available invigilators.");
    }

    return result;
  }

  static bool _backtrack(
    int courseIdx,
    List<Course> courses,
    List<Venue> venues,
    List<TimeSlot> timeslots,
    List<Invigilator> invigilators,
    Map<int, Set<int>> courseStudents,
    List<TimetableEntry> currentSchedule,
  ) {
    if (courseIdx == courses.length) return true;

    final course = courses[courseIdx];
    final studentsInCourse = courseStudents[course.id!]!;

    // Try each TimeSlot
    for (var slot in timeslots) {
      // Check for student conflicts in this slot
      bool hasStudentConflict = false;
      for (var entry in currentSchedule) {
        if (entry.timeslotId == slot.id!) {
          final otherStudents = courseStudents[entry.courseId]!;
          if (studentsInCourse.intersection(otherStudents).isNotEmpty) {
            hasStudentConflict = true;
            break;
          }
        }
      }

      if (hasStudentConflict) continue;

      // Try each Venue in this slot
      for (var venue in venues) {
        // Capacity check
        if (venue.capacity < course.enrolledCount) continue;

        // Check if venue is already taken in this slot
        bool venueTaken = currentSchedule.any(
          (e) => e.timeslotId == slot.id! && e.venueId == venue.id!,
        );

        if (venueTaken) continue;

        // Try to assign an available invigilator
        for (var invigilator in invigilators) {
          bool invigilatorTaken = currentSchedule.any(
            (e) => e.timeslotId == slot.id! && e.invigilatorId == invigilator.id!,
          );

          if (invigilatorTaken) continue;

          // Assign and recurse
          final entry = TimetableEntry(
            courseId: course.id!,
            venueId: venue.id!,
            timeslotId: slot.id!,
            invigilatorId: invigilator.id!,
          );
          currentSchedule.add(entry);

          if (_backtrack(courseIdx + 1, courses, venues, timeslots, invigilators, courseStudents, currentSchedule)) {
            return true;
          }

          // Backtrack
          currentSchedule.removeLast();
        }
      }
    }

    return false;
  }
}
