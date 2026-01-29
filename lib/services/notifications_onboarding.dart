import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsOnboarding {
  static bool _globalLock = false;

  static Future<void> maybeRun(BuildContext context) async {
    if (_globalLock) return;
    _globalLock = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseFirestore.instance.collection('Passenger').doc(user.uid);
      final snap = await ref.get();

      final done = (snap.data()?['notificationsOnboardingDone'] == true);
      if (done) return;

      // 1) إذن النظام
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!granted) {
        await _savePrefs(
          ref: ref,
          enabled: false,
          onboardingDone: true,
          stationsSubscribedIds: <String>[],
        );
        return;
      }

      // 2) token
      final token = await FirebaseMessaging.instance.getToken();

      // 3) اختيار المحطات
      if (!context.mounted) return;
      final selectedIds = await _showStationsDialog(context);

      // 4) حفظ IDs فقط
      await _savePrefs(
        ref: ref,
        enabled: true,
        onboardingDone: true,
        token: token,
        stationsSubscribedIds: selectedIds ?? <String>[],
      );
    } catch (e) {
      debugPrint('🔥 Notifications onboarding error: $e');
    } finally {
      _globalLock = false;
    }
  }

  static Future<void> _savePrefs({
    required DocumentReference<Map<String, dynamic>> ref,
    required bool enabled,
    required bool onboardingDone,
    String? token,
    required List<String> stationsSubscribedIds,
  }) async {
    final data = <String, dynamic>{
      'notificationsEnabled': enabled,
      'notificationsOnboardingDone': onboardingDone,
      'notificationsUpdatedAt': FieldValue.serverTimestamp(),
      'notificationsOnboardingDoneAt': FieldValue.serverTimestamp(),

      // ✅ IDs فقط
      'stationsSubscribedIds': stationsSubscribedIds,
      'stationsSubscribedUpdatedAt': FieldValue.serverTimestamp(),
    };

    await ref.set(data, SetOptions(merge: true));

    if (token != null && token.isNotEmpty) {
      await ref.set({
        'fcmTokens': {token: true},
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // ✅ لو تبين نحذف الحقل القديم إذا كان موجود
    try {
      await ref.update({
        'stationsSubscribedNames': FieldValue.delete(),
      });
    } catch (_) {}
  }

  static Future<List<String>?> _showStationsDialog(BuildContext context) async {
    // تحميل station_id_map.json
    final raw = await rootBundle.loadString('assets/data/station_id_map.json');
    final map = (json.decode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v.toString()));

    // ترتيب ثابت
    final orderedIds = <String>['S1', 'S2', 'S3', 'S4', 'S5', 'S6']
      ..removeWhere((id) => !map.containsKey(id));

    final selected = <String>{};

    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (ctx, setStateDialog) {
              return AlertDialog(
                title: const Text('اختاري المحطات المهتمة بالإشعارات'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: orderedIds.length,
                    itemBuilder: (_, i) {
                      final id = orderedIds[i];
                      final rawName = map[id] ?? id;

                      final displayName = _preferArabicName(rawName);
                      final checked = selected.contains(id);

                      return CheckboxListTile(
                        value: checked,
                        activeColor: const Color(0xFF964C9B),
                        title: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (v) {
                          setStateDialog(() {
                            if (v == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(<String>[]),
                    child: const Text('تخطي'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF964C9B),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(selected.toList()),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static String _preferArabicName(String raw) {
    final s = raw.trim();
    if (!s.contains('/')) return s;

    final parts = s.split('/').map((e) => e.trim()).toList();

    final ar = parts.firstWhere(
      (p) => RegExp(r'[\u0600-\u06FF]').hasMatch(p),
      orElse: () => parts.first,
    );

    return ar;
  }
}
