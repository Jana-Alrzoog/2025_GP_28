import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_shell.dart';
import 'signin_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isLoading = false;
  bool _isResending = false;

  int _resendCooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _timer?.cancel();

    setState(() {
      _resendCooldown = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _resendCooldown = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _resendCooldown--;
          });
        }
      }
    });
  }

  Future<void> _checkEmailVerified() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد مستخدم مسجل حاليًا')),
        );
        return;
      }

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('البريد الإلكتروني غير مفعّل حتى الآن'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'حدث خطأ أثناء التحقق')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resendCooldown > 0) return;

    setState(() => _isResending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد مستخدم مسجل حاليًا')),
        );
        return;
      }

      await user.sendEmailVerification();
      _startResendCooldown();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال رابط التفعيل مرة أخرى'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = e.message ?? 'حدث خطأ أثناء إعادة الإرسال';

      if (e.code == 'too-many-requests') {
        message = 'تمت المحاولة عدة مرات. انتظر قليلًا ثم حاول مرة أخرى.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _goToSignIn() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('تفعيل البريد الإلكتروني'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 90,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                const Text(
                  'تم إرسال رابط التفعيل',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userEmail.isEmpty
                      ? 'تحقق من بريدك الإلكتروني واضغط على رابط التفعيل.'
                      : 'أرسلنا رابط التفعيل إلى:\n$userEmail\n\nافتح بريدك الإلكتروني واضغط على الرابط ثم ارجع هنا.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _checkEmailVerified,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('تم التفعيل'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: (_isResending || _resendCooldown > 0)
                      ? null
                      : _resendVerificationEmail,
                  child: _isResending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _resendCooldown > 0
                              ? 'إعادة إرسال الرابط بعد $_resendCooldown ثانية'
                              : 'إعادة إرسال الرابط',
                        ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _goToSignIn,
                  child: const Text('العودة لتسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}