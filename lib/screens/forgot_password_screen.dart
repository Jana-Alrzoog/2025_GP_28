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
  String? _customError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _customError = null;
    });

    try {
      final email = _emailController.text.trim();


      try {
        // نحاول نسوي حساب جديد بنفس الإيميل
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: 'TemporaryPassword123!', 
        );

        //لما يكون الايميل مو مسجل
        await FirebaseAuth.instance.currentUser!.delete();

        setState(() => _customError = 'خطأ في البريد الإلكتروني');
        _formKey.currentState!.validate();
        return;

      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // لما يكون الايميل مسجل
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(' تم إرسال رابط استعادة كلمة المرور إلى بريدك')),
          );
          Navigator.pop(context);
          return;
        }
        throw e; 
      }

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'invalid-email') {
        setState(() => _customError = 'صيغة البريد الإلكتروني غير صحيحة');
        _formKey.currentState!.validate();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'حدث خطأ أثناء إرسال البريد')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'الرجاء إدخال البريد الإلكتروني';
    if (!EmailValidator.validate(text)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    if (_customError != null) {
      return _customError;
    }
    return null;
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

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: _emailValidator,
                        onChanged: (value) {
                          if (_customError != null) {
                            setState(() => _customError = null);
                          }
                        },
                        decoration: _decoration(
                          label: 'البريد الإلكتروني',
                          hint: 'user@example.com',
                          focusColor: const Color(0xFF43B649),
                        ),
                      ),

                      const SizedBox(height: 30.0),

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
