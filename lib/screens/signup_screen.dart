import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';           // 👈 Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart';       // 👈 Firestore
import '../screens/signin_screen.dart';
import '../theme/theme.dart';
import '../widgets/custom_scaffold.dart';
import 'home_shell.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formSignupKey = GlobalKey<FormState>();

  // 🔹 مضاف: متحكمات الاسم+الايميل+الباسورد+التأكيد
  final _nameController    = TextEditingController();
  final _emailController   = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formSignupKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // 1) إنشاء الحساب في Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = cred.user!.uid;

      // 2) تخزين البيانات في Firestore داخل Passenger/{uid}
      await FirebaseFirestore.instance.collection('Passenger').doc(uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3) الانتقال بعد النجاح
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'حدث خطأ أثناء التسجيل')),
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
                  key: _formSignupKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'مرحبًــا بـك',
                        style: TextStyle(
                          fontSize: 30.0,
                          fontWeight: FontWeight.w700,
                          color: lightColorScheme.primary,
                          fontFamily: 'Handicrafts',
                        ),
                      ),
                      const SizedBox(height: 40.0),

                      // الاسم
                      TextFormField(
                        controller: _nameController, // 👈 مضاف
                        validator: (value) =>
                            (value == null || value.isEmpty) ? 'الاســم مطلوب' : null,
                        decoration: _decoration(
                          label: 'الاســم',
                          hint: 'ادخـل اسمـك',
                          focusColor: const Color(0xFFF68D39),
                        ),
                      ), 
                      const SizedBox(height: 25.0),

                      // الايميل
                      TextFormField(
                        controller: _emailController, // 👈 مضاف
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
                        decoration: _decoration(
                          label: 'البريد  الإلكتروني ',
                          hint: 'user@example.com',
                          focusColor: const Color(0xFF43B649),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // كلمة المرور
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        obscuringCharacter: '*',
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) {
                          final password = value ?? '';
                          if (password.isEmpty) return 'الرجاء إدخال رمز المرور';
                          if (password.length < 8) return 'كلمة المرور يجب أن تكون 8 رموز على الأقل';
                          if (!RegExp(r'[0-9]').hasMatch(password)) return 'يجب أن تحتوي على رقم واحد على الأقل';
                          if (!RegExp(r'[A-Z]').hasMatch(password)) return 'يجب أن تحتوي على حرف كبير واحد على الأقل';
                          if (!RegExp(r'[!@#\$&*~]').hasMatch(password)) return 'يجب أن تحتوي على رمز خاص';
                          return null;
                        },
                        decoration: _decoration(
                          label: 'رمز المـرور',
                          hint: 'ادخـل رمز المـرور',
                          focusColor: const Color(0xFF984C9D),
                        ),
                      ),
                      const SizedBox(height: 20.0),

                      // تأكيد كلمة المرور (أزرق)
                      TextFormField(
                        controller: _confirmController,
                        obscureText: true,
                        obscuringCharacter: '*',
                        autofillHints: const [AutofillHints.newPassword],
                        cursorColor: const Color(0xFF00ADE5),
                        validator: (value) {
                          final confirm = value ?? '';
                          if (confirm.isEmpty) return 'الرجاء تأكيد رمز المرور';
                          if (confirm != _passwordController.text) return 'رمز المرور غير متطابق';
                          return null;
                        },
                        decoration: _decoration(
                          label: 'تأكيد رمز المـرور',
                          hint: 'أعد إدخال رمز المـرور',
                          focusColor: const Color(0xFF00ADE5),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // زر التسجيل
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lightColorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _register, // 👈 صار يسجّل
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('انشئ الحسـاب'),
                        ),
                      ),
                      const SizedBox(height: 30.0),

                      // التنقل إلى تسجيل الدخول
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (e) => const SignInScreen()),
                              );
                            },
                            child: Text(
                              'سجـل دخـول',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: lightColorScheme.primary,
                              ),
                            ),
                          ),
                          const Text(' لديـك حسـاب؟  ', style: TextStyle(color: Colors.black45)),
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

  InputDecoration _decoration({
    required String label,
    required String hint,
    required Color focusColor,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(26)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.black12),
        borderRadius: BorderRadius.circular(26),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: focusColor, width: 2.0),
        borderRadius: BorderRadius.circular(26),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 2.0),
        borderRadius: BorderRadius.circular(26),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 2.0),
        borderRadius: BorderRadius.circular(26),
      ),
      floatingLabelStyle: MaterialStateTextStyle.resolveWith((states) {
        if (states.contains(MaterialState.error)) {
          return const TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.w600);
        }
        if (states.contains(MaterialState.focused)) {
          return TextStyle(color: focusColor, fontWeight: FontWeight.w600);
        }
        return const TextStyle(color: Colors.grey);
      }),
    );
  }
}
