import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GenerateScreen extends StatefulWidget {
  @override
  _GenerateScreenState createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen> {

  String message = "";

  void generate() async {
    var res = await ApiService.generateTimetable();
    setState(() {
      message = res["message"];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Generate Timetable")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            ElevatedButton(
              onPressed: generate,
              child: Text("Generate"),
            ),

            SizedBox(height: 20),

            Text(message, style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}