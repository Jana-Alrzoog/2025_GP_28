import 'package:flutter/material.dart';
import '../../theme/text_utils.dart';
import '/widgets/crowd_status_widget.dart';
import '/widgets/schedule_widget.dart';
import '../../models/station.dart';

class StationSheet extends StatefulWidget {
  final Station station;
  final ScrollController scrollController;
  final Map<String, String> stationIdMap;

  const StationSheet({
    required this.station,
    required this.scrollController,
    required this.stationIdMap,
  });

  @override
  State<StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<StationSheet> {
  String? _resolveStationId({
    required String stationNameAr,
    required String? stationNameEn,
    required Map<String, String> map,
  }) {
    final nAr = norm(stationNameAr);
    final nEn = norm(stationNameEn ?? '');

    bool keyLooksLikeId = false;
    if (map.isNotEmpty) {
      final k = map.keys.first;
      keyLooksLikeId =
          RegExp(r'^[A-Za-z]{1,4}\d{0,4}$').hasMatch(k) && !k.contains(' ');
    }

    for (final e in map.entries) {
      final k = e.key;
      final v = e.value;
      final nk = norm(k);
      final nv = norm(v);

      if (keyLooksLikeId) {
        if (nv == nAr ||
            nv == nEn ||
            nv.contains(nAr) ||
            nv.contains(nEn) ||
            nAr.contains(nv) ||
            nEn.contains(nv)) {
          return k;
        }
      } else {
        if (nk == nAr ||
            nk == nEn ||
            nk.contains(nAr) ||
            nk.contains(nEn) ||
            nAr.contains(nk) ||
            nEn.contains(nk)) {
          return v;
        }
      }
    }

    for (final e in map.entries) {
      final nk = norm(e.key);
      final nv = norm(e.value);
      if (nk.isNotEmpty && (nAr.contains(nk) || nEn.contains(nk))) {
        return e.value;
      }
      if (nv.isNotEmpty && (nAr.contains(nv) || nEn.contains(nv))) {
        return e.key;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Map<Color, int> colorToLineNumber = {
      const Color(0xFF00ADE5): 1,
      const Color(0xFFD12027): 2,
      const Color(0xFFF68D39): 3,
      const Color(0xFFFFC107): 4,
      const Color(0xFF43B649): 5,
      const Color(0xFF984C9D): 6,
    };

    final stationId = _resolveStationId(
      stationNameAr: widget.station.name,
      stationNameEn: widget.station.altName,
      map: widget.stationIdMap,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // اسم المحطة
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.station.name,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // المسارات
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'المسارات:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < widget.station.colors.length; i++)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: widget.station.colors[i],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${colorToLineNumber[widget.station.colors[i]] ?? (i + 1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // حالة الازدحام
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'حالة الازدحام',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 8),

          CrowdStatusWidget(stationId: stationId),

          const SizedBox(height: 24),

          const Divider(thickness: 1.1),

          const SizedBox(height: 10),
          const Text(
            'الجدول الزمني',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),

          if (stationId != null)
            ScheduleWidget(
              stationId: stationId,
              stationName: widget.station.name,
              colors: widget.station.colors,
              colorToLineNumber: colorToLineNumber,
              stationIdMap: widget.stationIdMap,
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'لا توجد بيانات جدولة متاحة لهذه المحطة',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
