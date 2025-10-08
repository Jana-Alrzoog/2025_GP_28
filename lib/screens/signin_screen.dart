import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'signup_screen.dart';
import '../widgets/custom_scaffold.dart';
import 'package:email_validator/email_validator.dart';
import '../../theme/theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formSignInKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
   return CustomScaffold(
        backgroundAsset: 'assets/images/RegistrationBG.svg',
        isSvg: true,
        child: Column(
        children: [
          const Expanded(flex: 1, child: SizedBox(height: 10)),
          Expanded(
            flex: 7,
            child: Container(
              padding: const EdgeInsets.fromLTRB(25.0, 50.0, 25.0, 20.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40.0),
                  topRight: Radius.circular(40.0),
                ),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formSignInKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // العنوان
                      Text(
                        'مرحبًــا بعودتـك',
                        style: TextStyle(
                          fontSize: 30.0,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Handicrafts', 
                          color: lightColorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 40.0),

                      // الايميل
                      TextFormField(
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'الرجـاء إدخال الإيميـل';
                          if (!EmailValidator.validate(text)) {
                            return 'صيغة الإيميـل غير صحيحة';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'الايميـل',
                          floatingLabelStyle:
                              MaterialStateTextStyle.resolveWith((states) {
                            if (states.contains(MaterialState.error)) {
                              return const TextStyle(
                                  color: Color(0xFFBA1A1A),
                                  fontWeight: FontWeight.w600);
                            }
                            if (states.contains(MaterialState.focused)) {
                              return const TextStyle(
                                  color: Color(0xFF43B649),
                                  fontWeight: FontWeight.w600); // أخضر
                            }
                            return const TextStyle(color: Colors.grey);
                          }),
                          hintText: 'ادخـل ايميـلك المسجـل',
                          hintStyle: const TextStyle(color: Colors.black26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFF43B649),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFBA1A1A),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFBA1A1A),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // كلمة المرور
                      TextFormField(
                        obscureText: true,
                        obscuringCharacter: '*',
                        validator: (value) {
                          final password = value ?? '';
                          if (password.isEmpty) {
                            return 'الرجاء إدخال رمز المرور';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'رمز المـرور',
                          floatingLabelStyle:
                              MaterialStateTextStyle.resolveWith((states) {
                            if (states.contains(MaterialState.error)) {
                              return const TextStyle(
                                  color: Color(0xFFBA1A1A),
                                  fontWeight: FontWeight.w600);
                            }
                            if (states.contains(MaterialState.focused)) {
                              return const TextStyle(
                                  color: Color(0xFF984C9D),
                                  fontWeight: FontWeight.w600); // بنفسجي
                            }
                            return const TextStyle(color: Colors.grey);
                          }),
                          hintText: 'ادخـل رمز المـرور',
                          hintStyle: const TextStyle(color: Colors.black26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFF984C9D),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFBA1A1A),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFBA1A1A),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // نسيت كلمة المرور
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            child: Text(
                              'نسيت رمز المـرور؟',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: lightColorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25.0),

                      // زر تسجيل الدخول
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lightColorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (_formSignInKey.currentState!.validate()) {
                              // ✅ بدون SnackBar
                            }
                          },
                          child: const Text('تسجيـل دخـول'),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // Divider
                     

                      // ما عندك حساب؟
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (e) => const SignUpScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'انشئ حسـاب',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: lightColorScheme.primary,
                              ),
                            ),
                          ),
                          const Text(
                            ' ليس لديك حساب؟ ',
                            style: TextStyle(color: Colors.black45),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}