import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/signin_screen.dart';
import '/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ✅ صفحة اختيار المحطات (ملف جديد داخل tabs)
import 'select_stations_screen.dart';

void showTopToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: 70,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF964C9B),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              )
            ],
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);
  Future.delayed(const Duration(seconds: 3), () => overlayEntry.remove());
}

void showBottomBlackSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String fullName = "الاسم غير متاح";
  String email = "البريد غير متاح";

  // مهم: يبدأ false عشان ما يظهر "تحديد المحطات" شغال بدون قراءة
  bool _notificationsOn = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('Passenger')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      setState(() {
        fullName = doc.data()?['name'] ?? "الاسم غير متاح";
        email = doc.data()?['email'] ?? "البريد غير متاح";
      });
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Dialog(
        alignment: Alignment.center,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 300,
          height: 200,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Column(
                children: [
                  Text(
                    "تأكيد تسجيل الخروج",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    "هل أنت متأكد أنك تريد تسجيل الخروج؟",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF964C9B),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("إلغاء"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF964C9B),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      "تسجيل خروج",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        showTopToast(context, "تم تسجيل الخروج");
        await Future.delayed(const Duration(milliseconds: 1500));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipPath(
                clipper: _BottomCurveClipper(),
                child: Container(
                  height: 290,
                  color: const Color(0xFFDADADA),
                ),
              ),
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/MasarLogo.png',
                      height: 80,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'مرحباً $fullName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Positioned(
                left: 36,
                right: 36,
                bottom: -145,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 210,
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: const Color(0xFF964C9B),
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'الاسم :',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    fullName,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Text(
                                    'الإيميل :',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Image.asset(
                              'assets/images/MasarLogo.png',
                              height: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 18,
                      bottom: -6,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF964C9B),
                            width: 4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 140),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                // ✅ الإشعارات
                _NotificationsToggleTile(
                  onSyncValue: (v) {
                    if (mounted) setState(() => _notificationsOn = v);
                  },
                ),

                const _LocationToggleTile(),

                // ✅ تحديد المحطات
                _NavTile(
                  title: 'تحديد المحطات',
                  icon: Icons.location_on_outlined,
                  enabled: _notificationsOn,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SelectStationsScreen(),
                      ),
                    );
                  },
                  onDisabledTap: () {
                    showBottomBlackSnack(
                      context,
                      'فعّلي الإشعارات أولاً ثم حددي المحطات.',
                    );
                  },
                ),

                _Tile(
                  title: 'تتبع البلاغات',
                  icon: Icons.alt_route,
                  onTap: () {},
                ),

                _Tile(
                  title: 'تسجيل خروج',
                  icon: Icons.logout,
                  onTap: () => _confirmSignOut(context),
                  color: Colors.white,
                  titleColor: const Color(0xFFD02020),
                  iconColor: const Color(0xFFD02020),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// ✅ الإشعارات
class _NotificationsToggleTile extends StatefulWidget {
  final ValueChanged<bool>? onSyncValue;

  const _NotificationsToggleTile({this.onSyncValue, super.key});

  @override
  State<_NotificationsToggleTile> createState() =>
      _NotificationsToggleTileState();
}

class _NotificationsToggleTileState extends State<_NotificationsToggleTile> {
  bool isOn = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _syncFromFirestore();
  }

  Future<void> _syncFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Passenger')
          .doc(user.uid)
          .get();

      final enabled = doc.data()?['notificationsEnabled'] == true;

      if (!mounted) return;

      if (isOn != enabled) {
        setState(() => isOn = enabled);
        widget.onSyncValue?.call(enabled);
      }
    } catch (_) {}
  }

  Future<bool> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _saveToFirestore({required bool enabled, String? token}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection('Passenger').doc(user.uid);

    await ref.set({
      'notificationsEnabled': enabled,
      'notificationsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (token != null && token.isNotEmpty) {
      await ref.set({
        'fcmTokens': {token: true},
      }, SetOptions(merge: true));
    }
  }

  Future<void> _onChanged(bool v) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (!v) {
        await _saveToFirestore(enabled: false);
        if (!mounted) return;
        setState(() => isOn = false);
        widget.onSyncValue?.call(false);
        return;
      }

      final granted = await _requestPermission();

      if (!granted) {
        await _saveToFirestore(enabled: false);
        if (!mounted) return;
        setState(() => isOn = false);
        widget.onSyncValue?.call(false);

        showBottomBlackSnack(
          context,
          'لا يمكن تفعيل الإشعارات بدون إذن. فعّليها من إعدادات الجهاز.',
        );
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      await _saveToFirestore(enabled: true, token: token);

      if (!mounted) return;
      setState(() => isOn = true);
      widget.onSyncValue?.call(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _busy ? 0.85 : 1.0,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: IgnorePointer(
          ignoring: _busy,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Switch(
                  value: isOn,
                  onChanged: _onChanged,
                  activeColor: const Color(0xFF964C9B),
                  trackOutlineColor: MaterialStateProperty.resolveWith<Color?>(
                    (Set<MaterialState> states) => const Color(0xFF964C9B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'الإشعارات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationToggleTile extends StatefulWidget {
  const _LocationToggleTile({super.key});

  @override
  State<_LocationToggleTile> createState() => _LocationToggleTileState();
}

class _LocationToggleTileState extends State<_LocationToggleTile> {
  bool _isOn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final v = await LocationService.getUseLocation();
    if (!mounted) return;
    setState(() {
      _isOn = v;
      _loading = false;
    });
  }

  Future<void> _onChanged(bool value) async {
    if (!value) {
      await LocationService.setUseLocation(false);
      if (!mounted) return;
      setState(() => _isOn = false);
      return;
    }

    final perm = await LocationService.requestPermission();
    final granted =
        perm == LocationPermission.always || perm == LocationPermission.whileInUse;

    if (!granted) {
      await LocationService.setUseLocation(false);
      if (!mounted) return;
      setState(() => _isOn = false);

      showBottomBlackSnack(
        context,
        'لم يتم منح صلاحية الموقع من النظام. فعّليها من إعدادات الجهاز.',
      );
      return;
    }

    await LocationService.setUseLocation(true);
    if (!mounted) return;
    setState(() => _isOn = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Switch(
              value: _isOn,
              onChanged: _onChanged,
              activeColor: const Color(0xFF964C9B),
              trackOutlineColor: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) => const Color(0xFF964C9B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'مشاركة الموقع',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color, titleColor, iconColor;

  const _Tile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.color,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: iconColor ?? Colors.black54),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: titleColor ?? Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final VoidCallback? onDisabledTap;

  const _NavTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.onDisabledTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.42,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : (onDisabledTap ?? () {}),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: Colors.black54),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
