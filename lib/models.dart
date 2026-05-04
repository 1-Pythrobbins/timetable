class Course {
  final int? id;
  final String code;
  final String name;
  final int headcount;
  final bool isAlias;
  final String? parentCourseCode;

  Course({
    this.id,
    required this.code,
    required this.name,
    required this.headcount,
    this.isAlias = false,
    this.parentCourseCode,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'name': name,
    'headcount': headcount,
    'is_alias': isAlias ? 1 : 0,
    'parent_course_code': parentCourseCode,
  };

  factory Course.fromMap(Map<String, dynamic> map) => Course(
    id: map['id'],
    code: map['code'],
    name: map['name'],
    headcount: map['headcount'],
    isAlias: map['is_alias'] == 1,
    parentCourseCode: map['parent_course_code'],
  );
}

class Venue {
  final int? id;
  final String name;
  final int capacity;

  Venue({this.id, required this.name, required this.capacity});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'capacity': capacity,
  };

  factory Venue.fromMap(Map<String, dynamic> map) => Venue(
    id: map['id'],
    name: map['name'],
    capacity: map['capacity'],
  );
}

class Invigilator {
  final int? id;
  final String name;
  final String department;
  final int maxDaysPerWeek;

  Invigilator({
    this.id, 
    required this.name, 
    required this.department, 
    this.maxDaysPerWeek = 3,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'department': department,
    'max_days_per_week': maxDaysPerWeek,
  };

  factory Invigilator.fromMap(Map<String, dynamic> map) => Invigilator(
    id: map['id'],
    name: map['name'],
    department: map['department'],
    maxDaysPerWeek: map['max_days_per_week'] ?? 3,
  );
}

class TimetableEntry {
  final int? id;
  final String courseCode;
  final int venueId;
  final DateTime date;
  final String timeSlot; // e.g., "09:00 - 11:00"
  final int invigilatorId;

  TimetableEntry({
    this.id,
    required this.courseCode,
    required this.venueId,
    required this.date,
    required this.timeSlot,
    required this.invigilatorId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'course_code': courseCode,
    'venue_id': venueId,
    'date': date.toIso8601String(),
    'time_slot': timeSlot,
    'invigilator_id': invigilatorId,
  };

  factory TimetableEntry.fromMap(Map<String, dynamic> map) => TimetableEntry(
    id: map['id'],
    courseCode: map['course_code'],
    venueId: map['venue_id'],
    date: DateTime.parse(map['date']),
    timeSlot: map['time_slot'],
    invigilatorId: map['invigilator_id'],
  );
}

class Student {
  final int? id;
  final String studentId;
  final String name;

  Student({this.id, required this.studentId, required this.name});

  Map<String, dynamic> toMap() => {
    'id': id,
    'student_id': studentId,
    'name': name,
  };

  factory Student.fromMap(Map<String, dynamic> map) => Student(
    id: map['id'],
    studentId: map['student_id'],
    name: map['name'],
  );
}

