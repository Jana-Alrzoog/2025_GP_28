import 'package:flutter/material.dart';

class RouteCard extends StatelessWidget {
  final Map<String, dynamic> route;

  const RouteCard({super.key, required this.route});

  // ---------- helpers ----------
  String _s(dynamic v) => (v ?? "").toString();

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? fallback;
  }

  int? _i(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString());
  }

  Color _hexColor(String hex, {Color fallback = const Color(0xFF9E9E9E)}) {
    try {
      var h = hex.trim();
      if (h.isEmpty) return fallback;
      if (h.startsWith("#")) h = h.substring(1);
      if (h.length == 6) h = "FF$h";
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  IconData _iconForLine(String? lineIconOrId) {
    final t = (lineIconOrId ?? "").toLowerCase();
    if (t.contains("yellow") || t.contains("line4")) return Icons.circle;
    if (t.contains("purple") || t.contains("line6")) return Icons.circle;
    if (t.contains("blue") || t.contains("line1")) return Icons.circle;
    if (t.contains("red") || t.contains("line2")) return Icons.circle;
    if (t.contains("green") || t.contains("line3")) return Icons.circle;
    return Icons.circle;
  }

  Widget _pill(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.black54),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.left, // ✅ عكس الجهة
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String label, int minutes, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            "$label: $minutes د",
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.left, // ✅ عكس الجهة
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _stepRowRide(Map<String, dynamic> st) {
    final from = _s(st["from"]);
    final to = _s(st["to"]);
    final stops = _i(st["stops"]);

    final lineName = _s(st["line_name"]);
    final lineColor = _hexColor(_s(st["line_color"]), fallback: const Color(0xFF9E9E9E));
    final lineIcon = _s(st["line_icon"]);
    final lineId = _s(st["line_id"]);

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // badge (يبقى يمين بصريًا لأننا rtl بالrow)
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: lineColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: lineColor.withOpacity(0.35)),
            ),
            child: Center(
              child: Icon(
                _iconForLine(lineIcon.isNotEmpty ? lineIcon : lineId),
                size: 16,
                color: lineColor,
              ),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // ✅ عكس الجهة
              children: [
                Text(
                  "اركب $lineName",
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.left, // ✅
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  "من $from إلى $to",
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.left, // ✅
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                if (stops != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    "عدد المحطات: $stops",
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.left, // ✅
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.65),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRowTransfer(Map<String, dynamic> st) {
    final at = _s(st["at"]);
    final toLineName = _s(st["to_line_name"]);
    final toLineColor = _hexColor(_s(st["to_line_color"]), fallback: const Color(0xFF9E9E9E));
    final toLineIcon = _s(st["to_line_icon"]);
    final toLineId = _s(st["to_line_id"]);

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: toLineColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: toLineColor.withOpacity(0.35)),
            ),
            child: Center(
              child: Icon(Icons.swap_horiz_rounded, size: 16, color: toLineColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // ✅ عكس الجهة
              children: [
                const Text(
                  "تحويل",
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.left,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  "عند: $at",
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                const SizedBox(height: 5),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(
                      _iconForLine(toLineIcon.isNotEmpty ? toLineIcon : toLineId),
                      size: 14,
                      color: toLineColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "إلى: $toLineName",
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.75),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final dest = _s(route["destination_label"]);

    final start = (route["start_station"] is Map)
        ? (route["start_station"] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final end = (route["end_station"] is Map)
        ? (route["end_station"] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final times = (route["times"] is Map)
        ? (route["times"] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final startName = _s(start["name"]);
    final endName = _s(end["name"]);

    final metroMin = _asInt(times["metro_min"], fallback: 0);
    final transferMin = _asInt(times["transfer_min"], fallback: 0);

    final walkFrom = _i(times["walk_from_end_min"]);
    final driveFrom = _i(times["drive_from_end_min"]);

    // ✅ total uses MIN(after drop-off)
    int bestAfter = 0;
    String bestMode = "—";
    final w = walkFrom ?? 0;
    final d = driveFrom ?? 0;

    if (w > 0 && d > 0) {
      if (w <= d) {
        bestAfter = w;
        bestMode = "مشي";
      } else {
        bestAfter = d;
        bestMode = "سيارة";
      }
    } else if (w > 0) {
      bestAfter = w;
      bestMode = "مشي";
    } else if (d > 0) {
      bestAfter = d;
      bestMode = "سيارة";
    }

    final totalMin = metroMin + transferMin + bestAfter;

    final stepsRaw = route["steps"];
    final steps = (stepsRaw is List)
        ? stepsRaw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 360, // تقدرين تقللينها لو تبين
        ),
        child: Container(
          margin: const EdgeInsets.only(top: 6, bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min, // ✅ ما فيه سحب
              crossAxisAlignment: CrossAxisAlignment.start, // ✅ عكس الجهة
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  children: const [
                    Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF5B3FCB)),
                    SizedBox(width: 8),
                    Text("تفاصيل المسار", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 10),

                // ✅ الوقت الكلي (الأقل) فقط
                if (totalMin > 0)
                  Align(
                    alignment: Alignment.centerRight, // ✅ عكس
                    child: _pill(
                      "الوقت الكلي (الأقل): $totalMin د — حسب $bestMode",
                      icon: Icons.timer_outlined,
                    ),
                  ),

                const SizedBox(height: 10),

                Text(
                  "الوجهة: $dest",
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.left, // ✅
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  "من: $startName  →  إلى: $endName",
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right, // ✅
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.75),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  alignment: WrapAlignment.start, // ✅ عكس
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (metroMin > 0) _pill("مترو: $metroMin د", icon: Icons.train_outlined),
                    if (transferMin > 0) _pill("تحويل: $transferMin د", icon: Icons.swap_horiz_rounded),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                const SizedBox(height: 10),

                const Text(
                  "الخطوات",
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.left, // ✅
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 8),

                if (steps.isEmpty)
                  Text(
                    "ما وصلتني خطوات للرحلة.",
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),

                for (final st in steps) ...[
                  if (_s(st["type"]) == "ride") _stepRowRide(st),
                  if (_s(st["type"]) == "transfer") _stepRowTransfer(st),
                ],

                // ✅ بعد النزول: مشي + سيارة (لكن الوقت الكلي فقط يحسب الأقل)
                if ((walkFrom ?? 0) > 0 || (driveFrom ?? 0) > 0) ...[
                  const SizedBox(height: 6),
                  Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                  const SizedBox(height: 10),
                  const Text(
                    "بعد النزول",
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.left,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((walkFrom ?? 0) > 0)
                        _timeChip("المشي", walkFrom!, Icons.directions_walk_rounded),
                      if ((driveFrom ?? 0) > 0)
                        _timeChip("السيارة", driveFrom!, Icons.directions_car_rounded),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "الوقت الكلي يحسب الأقل بينهم (${bestMode == "مشي" ? "المشي" : "السيارة"}).",
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}