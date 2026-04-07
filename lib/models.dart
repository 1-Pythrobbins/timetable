class Student {
  final int? id;
  final String name;
  final String studentCode;

  Student({this.id, required this.name, required this.studentCode});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'student_code': studentCode,
  };

  factory Student.fromMap(Map<String, dynamic> map) => Student(
    id: map['id'],
    name: map['name'],
    studentCode: map['student_code'],
  );
}

class Course {
  final int? id;
  final String name;
  final String courseCode;
  int enrolledCount; // populated later

  Course({this.id, required this.name, required this.courseCode, this.enrolledCount = 0});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'course_code': courseCode,
  };

  factory Course.fromMap(Map<String, dynamic> map) => Course(
    id: map['id'],
    name: map['name'],
    courseCode: map['course_code'],
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

class TimeSlot {
  final int? id;
  final String day;
  final String startTime;
  final String endTime;

  TimeSlot({this.id, required this.day, required this.startTime, required this.endTime});

  Map<String, dynamic> toMap() => {
    'id': id,
    'day': day,
    'start_time': startTime,
    'end_time': endTime,
  };

  factory TimeSlot.fromMap(Map<String, dynamic> map) => TimeSlot(
    id: map['id'],
    day: map['day'],
    startTime: map['start_time'],
    endTime: map['end_time'],
  );

  @override
  String toString() => '$day ($startTime - $endTime)';
}

class Invigilator {
  final int? id;
  final String name;

  Invigilator({this.id, required this.name});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
  };

  factory Invigilator.fromMap(Map<String, dynamic> map) => Invigilator(
    id: map['id'],
    name: map['name'],
  );
}

class TimetableEntry {
  final int? id;
  final int courseId;
  final int venueId;
  final int timeslotId;
  final int invigilatorId;
  
  // Helper fields for UI
  String? courseName;
  String? venueName;
  String? timeslotLabel;
  String? invigilatorName;

  TimetableEntry({
    this.id,
    required this.courseId,
    required this.venueId,
    required this.timeslotId,
    required this.invigilatorId,
    this.courseName,
    this.venueName,
    this.timeslotLabel,
    this.invigilatorName,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'course_id': courseId,
    'venue_id': venueId,
    'timeslot_id': timeslotId,
    'invigilator_id': invigilatorId,
  };

  factory TimetableEntry.fromMap(Map<String, dynamic> map) => TimetableEntry(
    id: map['id'],
    courseId: map['course_id'],
    venueId: map['venue_id'],
    timeslotId: map['timeslot_id'],
    invigilatorId: map['invigilator_id'],
  );
}
