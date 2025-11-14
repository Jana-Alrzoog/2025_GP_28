import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const _prefKey = 'use_location';
  static const _askedKey = 'asked_location'; // هل سبق وسألناه؟

  /// قراءة إعداد استخدام الموقع من الجهاز
  static Future<bool> getUseLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// حفظ إعداد استخدام الموقع في الجهاز
  static Future<void> setUseLocation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// هل قد سألناه قبل؟
  static Future<bool> getHasAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_askedKey) ?? false;
  }

  static Future<void> setHasAsked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askedKey, value);
  }

  /// طلب صلاحية الموقع من النظام
  static Future<LocationPermission> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// جلب موقع المستخدم الحالي بالطريقة الجديدة (بدون تحذير)
  static Future<Position?> getCurrentPosition() async {
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      print("Location error: $e");
      return null;
    }
  }
}
