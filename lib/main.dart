import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 👈 إضافة Firebase
import '../screens/welcome_screen.dart';
import '../theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // لازم قبل Firebase
  await Firebase.initializeApp(); // 👈 تهيئة Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        fontFamily: 'Handicrafts',
        fontFamilyFallback: ['Inter', 'Arial', 'SansSerif'],
        colorScheme: lightColorScheme, // ✅ استخدم الثيم الخاص فيك
      ),
      home: const WelcomeScreen(), // 👈 تبقى نفس واجهتك
    );
  }
}
