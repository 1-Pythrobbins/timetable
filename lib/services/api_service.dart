import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  static const String baseUrl = "http://10.0.2.2:5000"; 
  // use 127.0.0.1 if web, 10.0.2.2 for Android emulator

  static Future generateTimetable() async {
    final response = await http.get(Uri.parse("$baseUrl/generate_timetable"));
    return jsonDecode(response.body);
  }

  static Future getTimetable() async {
    final response = await http.get(Uri.parse("$baseUrl/get_timetable"));
    return jsonDecode(response.body);
  }
}