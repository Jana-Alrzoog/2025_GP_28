import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/station.dart';
import '../theme/text_utils.dart'; // عشان norm لو احتجتيه

class StationLoader {
  static const Color _blueHex   = Color(0xFF00ADE5);
  static const Color _redHex    = Color(0xFFD12027);
  static const Color _orangeHex = Color(0xFFF68D39);
  static const Color _greenHex  = Color(0xFF43B649);
  static const Color _yellowHex = Color(0xFFFFC107);
  static const Color _purpleHex = Color(0xFF984C9D);

  static Future<List<Station>> loadStations() async {
    final raw =
        await rootBundle.loadString('assets/data/metro_stations.json');
    final data = json.decode(raw);
    final List list = (data is Map && data['results'] is List)
        ? data['results'] as List
        : (data as List);

    final Map<String, Map<String, dynamic>> byName = {};

    for (final s in list) {
      final String nameAr =
          (s['metrostationnamear'] ?? '').toString().trim();
      final String nameEn =
          (s['metrostationname'] ?? '').toString().trim();
      final String displayName =
          nameAr.isNotEmpty ? nameAr : (nameEn.isNotEmpty ? nameEn : 'محطة');
      final String key = norm(displayName);

      final String lineFull =
          (s['metrolinenamear'] ?? s['metrolinename'] ?? '').toString();
      final String lineShort = _shortLineName(lineFull);
      final Color color = _colorForLine(lineFull);

      double? lat, lon;
      if (s['geo_point_2d'] is Map) {
        lat = (s['geo_point_2d']['lat'] as num?)?.toDouble();
        lon = (s['geo_point_2d']['lon'] as num?)?.toDouble();
      }
      if ((lat == null || lon == null) && s['geoshape'] is Map) {
        final geom = s['geoshape']['geometry'];
        if (geom is Map &&
            geom['type'] == 'Point' &&
            geom['coordinates'] is List &&
            (geom['coordinates'] as List).length >= 2) {
          final coords = geom['coordinates'] as List;
          lon = (coords[0] as num).toDouble();
          lat = (coords[1] as num).toDouble();
        }
      }
      if (lat == null || lon == null) continue;

      final bucket = byName.putIfAbsent(key, () => {
            'nameArOrEn': displayName,
            'nameEn': nameEn,
            'lats': <double>[],
            'lons': <double>[],
            'lines': <String>{},
            'colors': <int>{},
          });

      (bucket['lats'] as List<double>).add(lat);
      (bucket['lons'] as List<double>).add(lon);
      (bucket['lines'] as Set<String>).add(lineShort);
      (bucket['colors'] as Set<int>).add(color.value);
    }

    final stations = byName.values.map((b) {
      final lats = (b['lats'] as List<double>);
      final lons = (b['lons'] as List<double>);
      final avgLat = lats.reduce((a, c) => a + c) / lats.length;
      final avgLon = lons.reduce((a, c) => a + c) / lons.length;

      final lines = (b['lines'] as Set<String>).toList()..sort();
      final colors =
          (b['colors'] as Set<int>).map((v) => Color(v)).toList()
            ..sort((a, b) => a.value.compareTo(b.value));

      return Station(
        name: b['nameArOrEn'] as String,
        altName: (b['nameEn'] as String?) ?? '',
        position: LatLng(avgLat, avgLon),
        lines: lines.toSet(),
        colors: colors,
      );
    }).toList();

    return stations;
  }

  static String _shortLineName(String line) {
    if (line.contains('الأزرق') || line.toLowerCase().contains('blue')) return 'الأزرق';
    if (line.contains('الأحمر') || line.toLowerCase().contains('red')) return 'الأحمر';
    if (line.contains('البرتقالي') || line.toLowerCase().contains('orange')) return 'البرتقالي';
    if (line.contains('الأخضر') || line.toLowerCase().contains('green')) return 'الأخضر';
    if (line.contains('الأصفر') || line.toLowerCase().contains('yellow')) return 'الأصفر';
    if (line.contains('البنفسجي') || line.toLowerCase().contains('purple')) return 'البنفسجي';
    return line;
  }

  static Color _colorForLine(String lineAr) {
    final ln = lineAr.toLowerCase();
    if (lineAr.contains('الأزرق') || ln.contains('blue')) return _blueHex;
    if (lineAr.contains('الأحمر') || ln.contains('red')) return _redHex;
    if (lineAr.contains('البرتقالي') || ln.contains('orange')) return _orangeHex;
    if (lineAr.contains('الأخضر') || ln.contains('green')) return _greenHex;
    if (lineAr.contains('الأصفر') || ln.contains('yellow')) return _yellowHex;
    if (lineAr.contains('البنفسجي') || ln.contains('purple')) return _purpleHex;
    return Colors.grey;
  }
}
