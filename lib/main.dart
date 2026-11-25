import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BambuLabTimelapseApp());
}

class BambuLabTimelapseApp extends StatelessWidget {
  const BambuLabTimelapseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BambuLab Timelapse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}
