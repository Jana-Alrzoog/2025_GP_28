import 'package:flutter/material.dart';
import 'signin_screen.dart';
import 'signup_screen.dart';
import '../widgets/custom_scaffold.dart';
import '../widgets/welcome_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      backgroundAsset: 'assets/images/welcomme.png',
      isSvg: false,
      appBarForeground: Colors.white,
      child: Column(
        children: [
          Flexible(
            flex: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 40.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 130),
                  Image.asset(
                    'assets/images/MasarLogo.png',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'مســـــــــار',
                          style: TextStyle(
                            fontSize: 64.0,
                            fontWeight: FontWeight.w600,
                            color: Color.fromARGB(255, 59, 59, 59),
                            fontFamily: 'Handicrafts',
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                      onTap: SignUpScreen(),
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
