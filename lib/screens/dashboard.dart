import 'package:flutter/material.dart';
import 'timetable_screen.dart';
import 'generate_screen.dart';

class Dashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Exam System Dashboard"),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            ElevatedButton(
              child: Text("Generate Timetable"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GenerateScreen()),
                );
              },
            ),

            SizedBox(height: 20),

            ElevatedButton(
              child: Text("View Timetable"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TimetableScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}