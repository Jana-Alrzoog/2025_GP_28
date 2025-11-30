import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';          
import 'package:cloud_firestore/cloud_firestore.dart';       
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

  // متحكمات الحقول
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();


  final FocusNode _pwFocusNode = FocusNode();
  bool _showPwRules = false;

  bool _isLoading = false;

 
  bool _pwHasMinLen = false;
  bool _pwHasDigit  = false;
  bool _pwHasUpper  = false;
  bool _pwHasLower  = false; 
  bool _pwHasSpecial= false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordRules);


    _pwFocusNode.addListener(() {
      setState(() {
        _showPwRules = _pwFocusNode.hasFocus;
      });
    });
  }

  void _updatePasswordRules() {
    final p = _passwordController.text;
    setState(() {
      _pwHasMinLen  = p.length >= 12 ;
      _pwHasDigit   = RegExp(r'[0-9\u0660-\u0669]').hasMatch(p); 
      _pwHasUpper   = RegExp(r'[A-Z]').hasMatch(p);
      _pwHasLower   = RegExp(r'[a-z]').hasMatch(p);             
      _pwHasSpecial = RegExp(r'[!@#\$&*~]').hasMatch(p);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _pwFocusNode.dispose();
    super.dispose();
  }


  String? _passwordValidator(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'الرجاء إدخال رمز المرور';
    if (!_pwHasMinLen)   return 'كلمة المرور يجب أن تكون 12 رموز على الأقل';
    if (!_pwHasDigit)    return 'يجب أن تحتوي على رقم واحد على الأقل';
    if (!_pwHasUpper)    return 'يجب أن تحتوي على حرف كبير واحد على الأقل';
    if (!_pwHasLower)    return 'يجب أن تحتوي على حرف صغير واحد على الأقل'; 
    if (!_pwHasSpecial)  return 'يجب أن تحتوي على رمز خاص (! @ # \$ & * ~)';
    return null;
  }

  //  فحص الاسم:  تسمح بس بحروف عربي/إنجليزي + أرقام + مسافات 
  final RegExp _nameAllowed = RegExp(r'^[a-zA-Z\u0621-\u064A0-9\u0660-\u0669\s]+$');

  Future<void> _register() async {
    if (!_formSignupKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      //  إنشاء الحساب في Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = cred.user!.uid;

      // passenger تخزين البيانات في  
      await FirebaseFirestore.instance.collection('Passenger').doc(uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      //  الانتقال بعد النجاح
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
                        controller: _nameController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) return 'الاســم مطلوب';
                          if (!_nameAllowed.hasMatch(v)) {
                            return 'الاسم يجب أن يحتوي على حروف عربي/إنجليزي وأرقام فقط';
                          }
                          return null;
                        },
                        decoration: _decoration(
                          label: 'الاســم',
                          hint: 'ادخـل اسمـك',
                          focusColor: const Color(0xFFF68D39),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // الايميل
                      TextFormField(
                        controller: _emailController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
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
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: _passwordController,
                        focusNode: _pwFocusNode,
                        obscureText: true,
                        obscuringCharacter: '*',
                        autofillHints: const [AutofillHints.newPassword],
                        validator: _passwordValidator, 
                        onChanged: (_) => _updatePasswordRules(), 
                        onTap: () => setState(() => _showPwRules = true), 
                        decoration: _decoration(
                          label: 'رمز المـرور',
                          hint: 'ادخـل رمز المـرور',
                          focusColor: const Color(0xFF984C9D),
                        ),
                      ),

                     
                      if (_showPwRules) ...[
                        const SizedBox(height: 12.0),
                        _PasswordRules(
                          hasMinLen: _pwHasMinLen,
                          hasDigit: _pwHasDigit,
                          hasUpper: _pwHasUpper,
                          hasLower: _pwHasLower,   
                          hasSpecial: _pwHasSpecial,
                        ),
                      ],

                      const SizedBox(height: 20.0),

                      TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
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

                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lightColorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('انشئ الحسـاب'),
                        ),
                      ),
                      const SizedBox(height: 30.0),

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


class _PasswordRules extends StatelessWidget {
  final bool hasMinLen;
  final bool hasDigit;
  final bool hasUpper;
  final bool hasLower;  
  final bool hasSpecial;

  const _PasswordRules({
    required this.hasMinLen,
    required this.hasDigit,
    required this.hasUpper,
    required this.hasLower,
    required this.hasSpecial,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ruleRow('12 رموز فأكثر', hasMinLen, style: textStyle),
        _ruleRow('رقم واحد على الأقل', hasDigit, style: textStyle),
        _ruleRow('حرف كبير واحد على الأقل (A-Z)', hasUpper, style: textStyle),
        _ruleRow('حرف صغير واحد على الأقل (a-z)', hasLower, style: textStyle), 
        _ruleRow('رمز خاص واحد على الأقل (! @ # \$ & * ~)', hasSpecial, style: textStyle),
      ],
    );
  }

  Widget _ruleRow(String text, bool ok, {TextStyle? style}) {
    final color = ok ? const Color(0xFF2E7D32) : Colors.black38; 
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: style?.copyWith(color: color))),
        ],
      ),
    );
  }
}
