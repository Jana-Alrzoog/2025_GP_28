import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_scaffold.dart';
import '../../theme/theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إرسال رابط استعادة كلمة المرور إلى بريدك')),
      );
      Navigator.pop(context); // الرجوع لصفحة تسجيل الدخول بعد الإرسال
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'حدث خطأ أثناء إرسال البريد')),
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
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'استعادة كلمة المرور',
                        style: TextStyle(
                          fontSize: 28.0,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Handicrafts',
                          color: lightColorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 40.0),

                      // حقل البريد الإلكتروني
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'الرجاء إدخال البريد الإلكتروني';
                          if (!EmailValidator.validate(text)) {
                            return 'صيغة البريد الإلكتروني غير صحيحة';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          hintText: 'user@example.com',
                          hintStyle: const TextStyle(color: Color(0x42000000)),

                          // 👇 تغيير لون عنوان الحقل عند التركيز/الخطأ
                          floatingLabelStyle: MaterialStateTextStyle.resolveWith((states) {
                            if (states.contains(MaterialState.error)) {
                              return const TextStyle(
                                color: Color(0xFFBA1A1A),
                                fontWeight: FontWeight.w600,
                              );
                            }
                            if (states.contains(MaterialState.focused)) {
                              return const TextStyle(
                                color: Color(0xFF43B649), // أخضر عند التركيز
                                fontWeight: FontWeight.w600,
                              );
                            }
                            return const TextStyle(color: Colors.grey);
                          }),

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0x1F000000)),
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

                      const SizedBox(height: 30.0),

                      // زر الإرسال
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lightColorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _resetPassword,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('إرسال رابط الاستعادة'),
                        ),
                      ),

                      const SizedBox(height: 20.0),

                      // رجوع
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('الرجوع لتسجيل الدخول'),
                      ),
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
