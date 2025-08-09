import 'package:flutter/material.dart';
import 'shell/main_shell.dart';

class TrainMateApp extends StatelessWidget {
  const TrainMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrainMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}
