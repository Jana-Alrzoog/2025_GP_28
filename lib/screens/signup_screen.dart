import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import '../screens/signin_screen.dart';
import '../theme/theme.dart';
import 'package:email_validator/email_validator.dart';
import '../widgets/custom_scaffold.dart';
import 'home_shell.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formSignupKey = GlobalKey<FormState>();

  // ✅ مضاف: متحكمات كلمة المرور والتأكيد
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
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
                  key: _formSignupKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // العنوان
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الاســم مطلوب';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'الاســم',
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
                                color: Color(0xFFF68D39),
                                fontWeight: FontWeight.w600,
                              );
                            }
                            return const TextStyle(color: Colors.grey);
                          }),
                          hintText: 'ادخـل اسمـك',
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
                              color: Color(0xFFF68D39),
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
                          hintText: 'user@example.com',
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
                        controller: _passwordController,
                        obscureText: true,
                        obscuringCharacter: '*',
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) {
                          final password = value ?? '';
                          if (password.isEmpty) {
                            return 'الرجاء إدخال رمز المرور';
                          }
                          if (password.length < 8) {
                            return 'كلمة المرور يجب أن تكون 8 رموز على الأقل';
                          }
                          if (!RegExp(r'[0-9]').hasMatch(password)) {
                            return 'كلمة المرور يجب أن تحتوي على رقم واحد على الأقل';
                          }
                          if (!RegExp(r'[A-Z]').hasMatch(password)) {
                            return 'كلمة المرور يجب أن تحتوي على حرف كبير واحد على الأقل';
                          }
                          if (!RegExp(r'[!@#\$&*~]').hasMatch(password)) {
                            return 'كلمة المرور يجب أن تحتوي على رمز خاص';
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

                      const SizedBox(height: 20.0),

                      // ✅ تأكيد كلمة المرور باللون الأزرق
                      TextFormField(
                        controller: _confirmController,
                        obscureText: true,
                        obscuringCharacter: '*',
                        autofillHints: const [AutofillHints.newPassword],
                        cursorColor: const Color(0xFF00ADE5), // الكيرسر أزرق
                        validator: (value) {
                          final confirm = value ?? '';
                          if (confirm.isEmpty) {
                            return 'الرجاء تأكيد رمز المرور';
                          }
                          if (confirm != _passwordController.text) {
                            return 'رمز المرور غير متطابق';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'تأكيد رمز المـرور',
                          hintText: 'أعد إدخال رمز المـرور',
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
                                color: Color(0xFF00ADE5), // أزرق عند التركيز
                                fontWeight: FontWeight.w600,
                              );
                            }
                            return const TextStyle(color: Colors.grey);
                          }),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFF00ADE5), // إطار أزرق
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

                      // زر التسجيل
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lightColorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (_formSignupKey.currentState!.validate()) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const HomeShell(),
                                ),
                              );
                            }
                          },
                          child: const Text('انشئ الحسـاب'),
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
                                MaterialPageRoute(
                                  builder: (e) => const SignInScreen(),
                                ),
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
                          const Text(
                            ' لديـك حسـاب؟  ',
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
