import 'package:flutter/material.dart';
import 'signin_screen.dart';
import 'signup_screen.dart';
import '../theme/theme.dart';
import '../widgets/custom_scaffold.dart';
import '../widgets/welcome_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Column(
        children: [
          Flexible(
            flex: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 40.0,
              ),
              // لا نستخدم Center عشان نقدر نرفع المحتوى لفوق
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start, // يخلي المحتوى يبدأ من أعلى
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 130), // تحكم بمسافة أعلى الشاشة

                  // صورة اللوقو
                  Image.asset(
                    'assets/images/MasarLogo.png',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 8), // مسافة صغيرة بين الصورة والنص

                  // النص "مسار"
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          // إذا سببت الكشيدة فراغات، جرّبي 'مسار' بدون تطويل
                          text: 'مســـــــــار',
                          style: TextStyle(
                            fontSize: 64.0,
                            fontWeight: FontWeight.w600, // غيّريها لـ w700 لو عندك وزن عربي فعلي
                            color: Color.fromARGB(255, 59, 59, 59),
                            fontFamily: 'Handicrafts', // لازم يطابق pubspec.yaml
                            height: 1.0, // يقلل التباعد العمودي حول النص
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // الأزرار بالأسفل
          Flexible(
            flex: 1,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Row(
                children: [
                  
                  const Expanded(
                    child: WelcomeButton(
                      buttonText: 'تسجيـل الدخـول',
                      onTap: SignInScreen(),
                      color: Colors.white,
                      textColor: Color.fromARGB(255, 59, 59, 59),
                    ),
                  ),
                  Expanded(
                    child: WelcomeButton(
                      buttonText: 'إنشـاء حسـاب',
                      onTap: const SignUpScreen(),
                      color: Color.fromARGB(255, 59, 59, 59),
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
