import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Move this OUTSIDE the widget class (file-level private class)
class _RowVM {
  final String timeStr;
  final String destName;
  final String lineId;
  final String? directionId;

  _RowVM({
    required this.timeStr,
    required this.destName,
    required this.lineId,
    required this.directionId,
  });
}

class ChatScheduleInline extends StatelessWidget {
  final String stationName;
  final String stationId;
  final Map<String, String> stationIdMap;
  final int windowMinutes;
  final int limitTrips;
  final String stationFieldName;

  const ChatScheduleInline({
    super.key,
    required this.stationName,
    required this.stationId,
    required this.stationIdMap,
    this.windowMinutes = 10,
    this.limitTrips = 4,
    this.stationFieldName = 'station_id',
  });

  static final Map<String, String?> _tripEndCache = {};
  static final Map<String, String?> _tripDirCache = {};

  static const List<String> _tripEndCandidates = [
    'end_station_code',
    'endStationCode',
    'end_station',
    'destination',
    'dest',
    'dest_code',
    'end_code',
  ];

  static const List<String> _tripDirCandidates = [
    'direction_id',
    'directionId',
    'direction',
  ];

  Future<Map<String, dynamic>?> _getTripDoc(
    DocumentReference<Map<String, dynamic>> tripRef,
  ) async {
    final snap = await tripRef.get();
    return snap.data();
  }

  Future<String?> _getTripEndCode(
    DocumentReference<Map<String, dynamic>> tripRef,
  ) async {
    final tripId = tripRef.id;
    if (_tripEndCache.containsKey(tripId)) return _tripEndCache[tripId];

    final trip = await _getTripDoc(tripRef);
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

  Future<String?> _getTripDirection(
    DocumentReference<Map<String, dynamic>> tripRef,
  ) async {
    final tripId = tripRef.id;
    if (_tripDirCache.containsKey(tripId)) return _tripDirCache[tripId];

    final trip = await _getTripDoc(tripRef);
    String? dir;
    for (final k in _tripDirCandidates) {
      final v = (trip?[k] ?? '').toString().trim();
      if (v.isNotEmpty) {
        dir = v;
        break;
      }
    }
    _tripDirCache[tripId] = dir;
    return dir;
  }

  String _norm(String s) {
    final t = s.trim().toLowerCase();
    return t
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

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
        final vv = v.toUpperCase();
        if (vv == cu || vv.contains(cu) || cu.contains(vv)) {
          for (final p in variants) {
            if (RegExp(r'[\u0600-\u06FF]').hasMatch(p)) return p.trim();
          }
          return variants.first;
        }
      }
    }
    return null;
  }

  bool _isTerminalHere({required String? destCode, required String destName}) {
    return _norm(destName) == _norm(stationName);
  }

  Color _lineColor(String lineId) {
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

  String _formatFromTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    final minute = dt.minute.toString().padLeft(2, '0');

    final isPM = dt.hour >= 12;
    int hour12 = dt.hour % 12;
    if (hour12 == 0) hour12 = 12;

    final hh = hour12.toString().padLeft(2, '0');
    final suffix = isPM ? 'PM' : 'AM';
    return '$hh:$minute$suffix';
  }

  IconData _directionIcon(String? dir) {
    final d = (dir ?? '').trim();
    if (d == '1') return Icons.arrow_back_rounded;
    if (d == '0') return Icons.arrow_forward_rounded;
    return Icons.swap_horiz_rounded;
  }

  String _directionLabel(String? dir) {
    final d = (dir ?? '').trim();
    if (d == '1') return 'راجع';
    if (d == '0') return 'رايح';
    return 'اتجاه';
  }

  Widget _header(int count) {
    return Row(
      children: [
        const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF2F2F2F)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "أقرب رحلات خلال $windowMinutes دقايق — $stationName",
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Text(
            "$count",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _row({
    required String timeStr,
    required String destName,
    required String lineId,
    required String? directionId,
  }) {
    final c = _lineColor(lineId);
    final dirIcon = _directionIcon(directionId);
    final dirText = _directionLabel(directionId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06), width: 1),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            child: const Center(
              child: Icon(Icons.train_rounded, size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              destName,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.clip,
              softWrap: true,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(dirIcon, size: 18, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            dirText,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              timeStr,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _boxed(Widget child) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F0FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = now.add(Duration(minutes: windowMinutes));

    final stream = FirebaseFirestore.instance
        .collectionGroup('stops')
        .where(stationFieldName, isEqualTo: stationId)
        .where('arrival_timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('arrival_timestamp', isLessThan: Timestamp.fromDate(end))
        .orderBy('arrival_timestamp')
        .limit(120)
        .snapshots();

    return _boxed(
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'Error loading data: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Text(
              'ما فيه رحلات خلال $windowMinutes دقايق.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
            );
          }

          final picked = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final seenTrips = <String>{};

          for (final d in docs) {
            final tripRef = d.reference.parent.parent;
            if (tripRef == null) continue;

            final tripId = tripRef.id;
            if (tripId.isEmpty) continue;
            if (seenTrips.contains(tripId)) continue;

            seenTrips.add(tripId);
            picked.add(d);

            if (picked.length >= limitTrips) break;
          }

          Future<List<_RowVM>> buildVisibleRows() async {
            final out = <_RowVM>[];
            for (final doc in picked) {
              final data = doc.data();

              final ts = data['arrival_timestamp'];
              final timeStr = (ts is Timestamp) ? _formatFromTimestamp(ts) : "وقت غير معروف";

              final lineId = (data['line_id'] ?? '').toString().trim();
              final stopDir = (data['direction_id'] ?? '').toString().trim();

              final tripRefRaw = doc.reference.parent.parent;
              final tripRef = tripRefRaw as DocumentReference<Map<String, dynamic>>?;

              String? endCode = (data['end_station_code'] as String?)?.trim();
              endCode ??= (data['endStationCode'] as String?)?.trim();

              final code = (endCode != null && endCode.isNotEmpty)
                  ? endCode
                  : (tripRef != null ? await _getTripEndCode(tripRef) : null);

              final dir = stopDir.isNotEmpty
                  ? stopDir
                  : (tripRef != null ? await _getTripDirection(tripRef) : null);

              final destName = _resolveEndName(code) ?? (code ?? 'وجهة غير معروفة');

              if (_isTerminalHere(destCode: code, destName: destName)) continue;

              out.add(_RowVM(
                timeStr: timeStr,
                destName: destName,
                lineId: lineId,
                directionId: dir,
              ));
            }
            return out;
          }

          return FutureBuilder<List<_RowVM>>(
            future: buildVisibleRows(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final rows = snap.data ?? [];
              if (rows.isEmpty) {
                return Text(
                  'ما فيه رحلات خلال $windowMinutes دقايق.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                );
              }

              return Column(
                children: [
                  _header(rows.length),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: Column(
                      children: List.generate(rows.length, (i) {
                        final r = rows[i];
                        return _row(
                          timeStr: r.timeStr,
                          destName: r.destName,
                          lineId: r.lineId,
                          directionId: r.directionId,
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}