import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/text_utils.dart'; // عشان norm
import '/screens/tabs/train_carriage_view.dart'; // عدّل المسار حسب مشروعك
import '../../models/station.dart';

/*==========================
   Schedule Widget
 ==========================*/

class ScheduleWidget extends StatelessWidget {
  final String stationName;
  final String stationId;
  final List<Color> colors;
  final Map<Color, int> colorToLineNumber;
  final Map<String, String> stationIdMap;

  const ScheduleWidget({
    required this.stationName,
    required this.stationId,
    required this.colors,
    required this.colorToLineNumber,
    required this.stationIdMap,
  });

  // ========= وجهة الرحلة (Destination) =========

  // كاش: tripId -> end_code
  static final Map<String, String?> _tripEndCache = {};

  // أسماء محتملة لحقل الوجهة داخل وثيقة الرحلة
  static const List<String> _tripEndCandidates = [
    'end_station_code',
    'endStationCode',
    'end_station',
    'destination',
    'dest',
    'dest_code',
    'end_code',
  ];

  // اقرأ الوجهة من وثيقة الرحلة الأم
  Future<String?> _getTripEndCodeFromTrip(DocumentReference tripRef) async {
    final tripId = tripRef.id;
    if (_tripEndCache.containsKey(tripId)) return _tripEndCache[tripId];

    final snap = await tripRef.get();
    final trip = snap.data() as Map<String, dynamic>?;

    String? code;
    for (final k in _tripEndCandidates) {
      final v = (trip?[k] as String?)?.trim();
      if (v != null && v.isNotEmpty) {
        code = v;
        break;
      }
    }

    _tripEndCache[tripId] = code;
    return code;
  }

  // حوّل كود الوجهة لاسم عربي من station_id_map (يدعم سلاسل متعددة مفصولة /)
  String? _resolveEndName(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    final cu = code.trim().toUpperCase();

    for (final entry in stationIdMap.entries) {
      final variants = entry.value
          .split('/')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      for (final v in variants) {
        final vv = v.trim().toUpperCase();
        if (vv == cu || vv.contains(cu) || cu.contains(vv)) {
          // رجّع أول نص عربي موجود
          for (final p in variants) {
            if (RegExp(r'[\u0600-\u06FF]').hasMatch(p)) {
              return p.trim();
            }
          }
          return variants.first;
        }
      }
    }
    return null;
  }
bool _isTerminalHere({
  String? destCode,
  String? destName,
}) {
  final currentId = stationId.trim().toUpperCase();

  // 1) مقارنة بالكود مباشرة
  if (destCode != null &&
      destCode.trim().isNotEmpty &&
      destCode.trim().toUpperCase() == currentId) {
    return true;
  }

  // 2) مقارنة بأسماء المحطة من الـ stationIdMap
  final mapping = stationIdMap[currentId];
  if (mapping != null && mapping.trim().isNotEmpty && destName != null) {
    final nd = norm(destName);
    for (final v in mapping.split('/')) {
      final vv = v.trim();
      if (vv.isEmpty) continue;
      if (nd == norm(vv)) {
        return true;
      }
    }
  }

  // 3) fallback: مقارنة بالاسم المباشر (نادرًا نحتاجه)
  if (destName != null &&
      norm(destName) == norm(stationName)) {
    return true;
  }

  return false;
}

  Widget _scheduleRow({
    required int i,
    required int total,
    required String timeStr,
    required int lineNumber,
    required Color color,
    required String destName,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: i == total - 1 ? 0 : 1,
          ),
        ),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Icon(Icons.chevron_left, color: Colors.grey[600], size: 22),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            destName,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '$lineNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForLine(String lineId) {
    switch (lineId.toLowerCase()) {
      case 'blue':
        return const Color(0xFF00ADE5);
      case 'red':
        return const Color(0xFFD12027);
      case 'orange':
        return const Color(0xFFF68D39);
      case 'yellow':
        return const Color(0xFFFFC107);
      case 'green':
        return const Color(0xFF43B649);
      case 'purple':
        return const Color(0xFF984C9D);
      default:
        return Colors.grey;
    }
  }

  // "09:32AM"
  String _formatArrivalTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        int hour24 = int.parse(parts[0]);
        final minute = parts[1].padLeft(2, '0');

        final isPM = hour24 >= 12;
        int hour12 = hour24 % 12;
        if (hour12 == 0) hour12 = 12;

        final hh = hour12.toString().padLeft(2, '0');
        final suffix = isPM ? 'PM' : 'AM';
        return '$hh:$minute$suffix';
      }
    } catch (_) {}
    return time;
  }

  String _formatFromTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    int hour24 = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');

    final isPM = hour24 >= 12;
    int hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;

    final hh = hour12.toString().padLeft(2, '0');
    final suffix = isPM ? 'PM' : 'AM';
    return '$hh:$minute$suffix';
  }

  Widget _boxed(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime end = now.add(const Duration(minutes: 30));

    final stream = FirebaseFirestore.instance
        .collectionGroup('stops')
        .where('station_id', isEqualTo: stationId)
        .where('arrival_timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('arrival_timestamp',
        isLessThan: Timestamp.fromDate(end))
        .orderBy('arrival_timestamp')
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _boxed(
            Text(
              'خطأ في تحميل البيانات: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _boxed(const Center(child: CircularProgressIndicator()));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _boxed(const Text(
            'لا توجد رحلات خلال الساعة القادمة',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ));
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: List.generate(docs.length, (i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              final lineId = (data['line_id'] as String?) ?? '';
              final Color color = _getColorForLine(lineId);
              final int lineNumber = colorToLineNumber[color] ?? 0;

              String timeStr = '';
              final ts = data['arrival_timestamp'];
              if (data['arrival_time'] is String &&
                  (data['arrival_time'] as String).isNotEmpty) {
                timeStr = _formatArrivalTime(
                    data['arrival_time'] as String);
              } else if (ts is Timestamp) {
                timeStr = _formatFromTimestamp(ts);
              }

              // 1) نحاول نقرأ الوجهة مباشرة من stop
              String? endCode =
              (data['end_station_code'] as String?)?.trim();
              if (endCode == null || endCode.isEmpty) {
                for (final k in [
                  'end_station',
                  'endStation',
                  'destination',
                  'dest',
                  'dest_code',
                  'end_code'
                ]) {
                  final v = (data[k] as String?)?.trim();
                  if (v != null && v.isNotEmpty) {
                    endCode = v;
                    break;
                  }
                }
              }

              final tripRef = doc.reference.parent.parent;
              Future<String?> futureEndCode;

              if (endCode != null) {
                futureEndCode = Future.value(endCode);
              } else if (tripRef != null) {
                futureEndCode = _getTripEndCodeFromTrip(tripRef);
              } else {
                futureEndCode = Future.value(null);
              }

              return FutureBuilder<String?>(
                future: futureEndCode,
                builder: (context, snap) {
                  final code = snap.data;
                  final destName =
                      _resolveEndName(code) ?? 'وجهة غير معروفة';

                  // لو الوجهة هي نفس المحطة ما نعرض الصف
                 if (_isTerminalHere(destCode: code, destName: destName)) {
                  return const SizedBox.shrink();
                }

                  return InkWell(
                    onTap: () {
                      final tripId = tripRef?.id ?? '';

                      if (tripId.isEmpty) return;

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TrainCarriageView(
                            stationName: stationName,
                            tripId: tripId,
                            lineId: lineId,
                            lineNumber: lineNumber,
                            lineColor: color,
                            departureTime: timeStr,
                            destination: destName,
                            stationId: stationId,
                          ),
                        ),
                      );
                    },
                    child: _scheduleRow(
                      i: i,
                      total: docs.length,
                      timeStr: timeStr,
                      lineNumber: lineNumber,
                      color: color,
                      destName: destName,
                    ),
                  );
                },
              );
            }),
          ),
        );
      },
    );
  }
}
