import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/welcome_screen.dart';
import 'screens/home_shell.dart';   // 👈 مهم! فيها BottomNavigationBar
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Masar',
      theme: ThemeData(
        fontFamily: 'Handicrafts',
        fontFamilyFallback: ['Inter', 'Arial', 'SansSerif'],
        colorScheme: lightColorScheme,
      ),
      home: const AuthGate(), // 👈 هذا بدل WelcomeScreen
    );
  }
}

/// ---------------------------------------------------------------------
///  AuthGate
/// ---------------------------------------------------------------------
/// هذا الودجت هو “البوابة”
/// - لو فيه مستخدم → روح لـ HomeShell (اللي فيها التابات)
/// - لو ما فيه مستخدم → روح لـ WelcomeScreen (تسجيل الدخول)
///
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1) لسه نحمّل حالة المستخدم
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2) ما فيه مستخدم → واجهة الترحيب
        if (!snapshot.hasData) {
          return const WelcomeScreen();
        }

        // 3) فيه مستخدم → الهوم الأساسي (اللي فيه Navigation Bar)
        return const HomeShell();
      },
    );
  }
}
