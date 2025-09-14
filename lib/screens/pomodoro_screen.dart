import 'package:flutter/material.dart';
import '../widgets/timer_widget.dart';

class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SafeArea(
        child: Center(
          child: TimerWidget(), // Pastikan widget timer berada di tengah
        ),
      ),
    );
  }
}
