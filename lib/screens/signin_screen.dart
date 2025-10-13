import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';
import '../widgets/custom_scaffold.dart';
import '../../theme/theme.dart';
import 'home_shell.dart';
import 'forgot_password_screen.dart'; // 👈 جديد

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formSignInKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formSignInKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'تعذر تسجيل الدخول')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      backgroundAsset: 'assets/images/RegistrationBG.svg',
      isSvg: true,
      child: Column(
        children: [
          const Expanded(flex: 1, child: SizedBox(height: 10)),
          Expanded(
            flex: 4,
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

                      // البريد الإلكتروني
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'الرجـاء إدخال البريد الإلكتروني';
                          if (!EmailValidator.validate(text)) {
                            return 'صيغة البريد الإلكتروني غير صحيحة';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          floatingLabelStyle:
                              MaterialStateTextStyle.resolveWith((states) {
                            if (states.contains(MaterialState.error)) {
                              return const TextStyle(
                                color: Color(0xFFBA1A1A),
                                fontWeight: FontWeight.w600,
                              );
                            }
                            if (states.contains(MaterialState.focused)) {
                              return const TextStyle(
                                color: Color(0xFF43B649),
                                fontWeight: FontWeight.w600,
                              );
                            }
                            return const TextStyle(color: Colors.grey);
                          }),
                          hintText: 'ادخـل بريدك الإلكتروني المسجـل',
                          hintStyle: const TextStyle(color: Colors.black26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black12),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFF43B649),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFBA1A1A),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFBA1A1A),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // كلمة المرور
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        obscuringCharacter: '*',
                        validator: (value) {
                          if ((value ?? '').isEmpty) return 'الرجاء إدخال رمز المرور';
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'رمز المـرور',
                          floatingLabelStyle:
                              MaterialStateTextStyle.resolveWith((states) {
                            if (states.contains(MaterialState.error)) {
                              return const TextStyle(
                                color: Color(0xFFBA1A1A),
                                fontWeight: FontWeight.w600,
                              );
                            }
                            if (states.contains(MaterialState.focused)) {
                              return const TextStyle(
                                color: Color(0xFF984C9D),
                                fontWeight: FontWeight.w600,
                              );
                            }
                            return const TextStyle(color: Colors.grey);
                          }),
                          hintText: 'ادخـل رمز المـرور',
                          hintStyle: const TextStyle(color: Colors.black26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black12),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFF984C9D),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFBA1A1A),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFBA1A1A),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // نسيت كلمة المرور → يفتح شاشة جديدة
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
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
                          onPressed: _isLoading ? null : _signIn,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('تسجيـل دخـول'),
                        ),
                      ),
                      const SizedBox(height: 25.0),

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
