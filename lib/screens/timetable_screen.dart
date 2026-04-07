import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TimetableScreen extends StatefulWidget {
  @override
  _TimetableScreenState createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {

  List timetable = [];

  @override
  void initState() {
    super.initState();
    loadTimetable();
  }

  void loadTimetable() async {
    var data = await ApiService.getTimetable();
    setState(() {
      timetable = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Timetable")),
      body: ListView.builder(
        itemCount: timetable.length,
        itemBuilder: (context, index) {
          var item = timetable[index];
          return ListTile(
            title: Text(item['canonical_name']),
            subtitle: Text("${item['date']} | ${item['start_time']}"),
          );
        },
      ),
    );
  }
}