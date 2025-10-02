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
                child: Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text:  TextSpan(
                      children: [
                        TextSpan(
                            text: 'مســـــــــار\n',
                            style: TextStyle(
                              fontSize: 64.0,
                               color: Color.fromARGB(255, 59, 59, 59),
                              
                            )),
                        
                      ],
                    ),
                  ),
                ),
              )),
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
                      color: Color.fromARGB(255, 59, 59, 59),
                      textColor: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: WelcomeButton(
                      buttonText: 'إنشـاء حسـاب',
                      onTap: const SignUpScreen(),
                      color: Colors.white,
                      textColor: Color.fromARGB(255, 59, 59, 59),
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