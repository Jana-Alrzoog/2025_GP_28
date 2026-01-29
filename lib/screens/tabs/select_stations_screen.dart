import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectStationsScreen extends StatefulWidget {
  const SelectStationsScreen({super.key});

  @override
  State<SelectStationsScreen> createState() => _SelectStationsScreenState();
}

class _SelectStationsScreenState extends State<SelectStationsScreen> {
  bool _loading = true;
  bool _saving = false;

  Map<String, String> _stationIdMap = {};

  // key = normalized station name (ar or en) -> list of lines
  final Map<String, List<_LineInfo>> _linesByStationNameKey = {};

  final Set<String> _selectedIds = {};

  final List<String> _orderedIds = const ['S1', 'S2', 'S3', 'S4', 'S5', 'S6'];

  // gradient endpoints (blue -> purple)
  static const Color _gradStart = Color(0xFF00ADE5);
  static const Color _gradEnd = Color(0xFF984C9D);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      _stationIdMap = await _loadStationIdMap();
      await _loadMetroStationsLines();

      final doc = await FirebaseFirestore.instance
          .collection('Passenger')
          .doc(user.uid)
          .get();

      final ids = (doc.data()?['stationsSubscribedIds'] as List?) ?? const [];
      _selectedIds
        ..clear()
        ..addAll(ids.map((e) => e.toString()));

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<Map<String, String>> _loadStationIdMap() async {
    try {
      final raw = await rootBundle.loadString('assets/data/station_id_map.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {
        'S1': 'المركز المالي/KAFD',
        'S2': 'stc/STC',
        'S3': 'قصر الحكم/Qasr Al Hokm',
        'S4': 'المتحف الوطني/National Museum',
        'S5': 'صالة 1-2/Terminal 1-2',
        'S6': 'المدينة الصناعية الأولى/First Industrial City',
      };
    }
  }

  Future<void> _loadMetroStationsLines() async {
    try {
      final raw = await rootBundle.loadString('assets/data/metro_stations.json');
      final decoded = json.decode(raw);

      final List list = decoded is List
          ? decoded
          : (decoded['stations'] as List? ?? const []);

      _linesByStationNameKey.clear();

      for (final item in list) {
        if (item is! Map) continue;

        final arName = (item['metrostationnamear'] ?? '').toString().trim();
        final enName = (item['metrostationname'] ?? '').toString().trim();
        final metroline = (item['metroline'] ?? '').toString().trim(); // "Line2"

        final lineNumber = _parseLineNumber(metroline);
        if (lineNumber == null) continue;

        final lineInfo = _LineInfo(
          number: lineNumber,
          color: _colorForLineNumber(lineNumber),
        );

        if (arName.isNotEmpty) {
          final k = _norm(arName);
          (_linesByStationNameKey[k] ??= []).add(lineInfo);
        }
        if (enName.isNotEmpty) {
          final k = _norm(enName);
          (_linesByStationNameKey[k] ??= []).add(lineInfo);
        }
      }

      // unique + sort
      _linesByStationNameKey.forEach((_, lines) {
        final uniq = <int, _LineInfo>{};
        for (final l in lines) {
          uniq[l.number] = l;
        }
        lines
          ..clear()
          ..addAll(uniq.values.toList()
            ..sort((a, b) => a.number.compareTo(b.number)));
      });
    } catch (_) {
      _linesByStationNameKey.clear();
    }
  }

  int? _parseLineNumber(String metroline) {
    final m = RegExp(r'line\s*([0-9]+)', caseSensitive: false).firstMatch(metroline);
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? '');
  }

  Color _colorForLineNumber(int line) {
    switch (line) {
      case 1:
        return const Color(0xFF00ADE5); // Blue
      case 2:
        return const Color(0xFFD12027); // Red
      case 3:
        return const Color(0xFFF68D39); // Orange
      case 4:
        return const Color(0xFFFFC107); // Yellow
      case 5:
        return const Color(0xFF43B649); // Green
      case 6:
        return const Color(0xFF984C9D); // Purple
      default:
        return Colors.grey;
    }
  }

String _preferArabicName(String raw) {
  final parts = raw.split('/').map((e) => e.trim()).where((e) => e.isNotEmpty);

  // خذي أول عربي "قصير ونظيف"
  for (final p in parts) {
    if (!RegExp(r'[\u0600-\u06FF]').hasMatch(p)) continue;

    var s = p.replaceAll('الصاله', 'صالة').replaceAll('صاله', 'صالة').trim();
    s = s.replaceAll('المطار', '').trim();

    if (s.isNotEmpty) return s;
  }

  // fallback
  return raw.split('/').first.trim();
}


  String _preferEnglishName(String raw) {
    final s = raw.trim();
    if (!s.contains('/')) return s;

    final parts = s.split('/').map((e) => e.trim()).toList();
    final en = parts.firstWhere(
      (p) => RegExp(r'[A-Za-z]').hasMatch(p),
      orElse: () => parts.last,
    );
    return en;
  }

  String _norm(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }

List<_LineInfo> _linesForStationId(String stationId) {
  final raw = (_stationIdMap[stationId] ?? stationId).trim();

  // ✅ جرّبي كل الأسماء داخل S5 بدل اسم واحد
  final aliases = _aliasesFromRaw(raw);

  for (final a in aliases) {
    final key = _norm(a);
    final lines = _linesByStationNameKey[key];
    if (lines != null && lines.isNotEmpty) return lines;
  }

  return const [];
}


 Color _activeColorForIndex(int index, int total) {
  // Metro gradient stops
  const stops = <Color>[
    Color(0xFF00ADE5), // Blue
    Color(0xFFD12027), // Red
    Color(0xFFF68D39), // Orange
    Color(0xFFFFC107), // Yellow
    Color(0xFF43B649), // Green
    Color(0xFF984C9D), // Purple
  ];

  if (total <= 1) return stops.last;

  final t = (index / (total - 1)).clamp(0.0, 1.0);
  final segments = stops.length - 1;

  final segFloat = t * segments;
  final segIndex = segFloat.floor().clamp(0, segments - 1);
  final segT = segFloat - segIndex;

  return Color.lerp(stops[segIndex], stops[segIndex + 1], segT)!;
}


  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      final ref = FirebaseFirestore.instance.collection('Passenger').doc(user.uid);

      await ref.set({
        // ✅ نخزن IDs فقط
        'stationsSubscribedIds': _selectedIds.toList(),
        'stationsSubscribedUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ ونحذف الأسماء لو كانت موجودة
      try {
        await ref.update({'stationsSubscribedNames': FieldValue.delete()});
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("صار خطأ أثناء الحفظ")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectAll() {
    final available = _orderedIds.where((id) => _stationIdMap.containsKey(id));
    setState(() => _selectedIds.addAll(available));
  }

  void _clearAll() {
    setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final visibleIds = _orderedIds.where((id) => _stationIdMap.containsKey(id)).toList();
    final total = visibleIds.length;

    // ✅ theme: غير مختار = بوردر أسود
    final themed = Theme.of(context).copyWith(
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        side: MaterialStateBorderSide.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const BorderSide(color: Colors.transparent, width: 0);
          }
          return const BorderSide(color: Colors.black, width: 1.6);
        }),
      ),
    );

    return Theme(
      data: themed,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('تحديد المحطات'),
            backgroundColor: const Color(0xFF964C9B),
            foregroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: _loading || _saving ? null : _selectAll,
                child: const Text("تحديد الكل", style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: _loading || _saving ? null : _clearAll,
                child: const Text("مسح", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: visibleIds.length,
                        itemBuilder: (_, i) {
                          final id = visibleIds[i];
                          final rawName = _stationIdMap[id] ?? id;

                          final displayName = _preferArabicName(rawName); // ✅ عربي (المتحف الوطني)
                          final checked = _selectedIds.contains(id);

                          final lines = _linesForStationId(id);

                          // ✅ لون مختار تدريجي
                          final activeColor = _activeColorForIndex(i, total);

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: CheckboxListTile(
                              value: checked,
                              activeColor: activeColor,
                              checkColor: Colors.white,
                              title: Row(
                                children: [
                                  if (lines.isNotEmpty) ...[
                                    _LineBadges(lines: lines),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                              // ✅ ما نعرض ID
                              subtitle: null,
                              onChanged: _saving
                                  ? null
                                  : (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedIds.add(id);
                                        } else {
                                          _selectedIds.remove(id);
                                        }
                                      });
                                    },
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF964C9B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'حفظ',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
        ),
      ),
    );
  }
}

class _LineInfo {
  final int number;
  final Color color;
  const _LineInfo({required this.number, required this.color});
}

class _LineBadges extends StatelessWidget {
  final List<_LineInfo> lines;
  const _LineBadges({required this.lines});

  @override
  Widget build(BuildContext context) {
    // نعرض أكثر من 2 إذا تبين (الكافد أحيانًا ينقصه لون لأنه >2)
    // خليها 3 مثلاً:
    final shown = lines.take(3).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: shown.map((l) {
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Container(
            width: 26,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: l.color,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              l.number.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

List<String> _aliasesFromRaw(String raw) {
  final parts = raw
      .split('/')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  final out = <String>{};

  for (final p in parts) {
    out.add(p);

    // تنظيفات تساعد المطابقة
    out.add(p.replaceAll('الصاله', 'صالة'));
    out.add(p.replaceAll('صاله', 'صالة'));
    out.add(p.replaceAll('المطار', '').trim());

    // لو فيها 1-2، جرّبي 2-1 بعد
    out.add(_swapTwoNumbersOrder(p));
  }

  // شيل الفراغات الزايدة بعد التنظيف
  return out.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

String _swapTwoNumbersOrder(String s) {
  final m = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(s);
  if (m == null) return s;
  final a = m.group(1)!;
  final b = m.group(2)!;
  return s.replaceFirst(m.group(0)!, '$b-$a');
}
