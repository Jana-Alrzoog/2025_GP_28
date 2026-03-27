import 'package:flutter/material.dart';

class ChatTrackCards extends StatefulWidget {
  final List<Map<String, dynamic>> reports;

  const ChatTrackCards({super.key, required this.reports});

  @override
  State<ChatTrackCards> createState() => _ChatTrackCardsState();
}

class _ChatTrackCardsState extends State<ChatTrackCards> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex != null) {
      final r = widget.reports[_selectedIndex!];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ← زر الرجوع للقائمة
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = null),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFF5B3FCB)),
                  SizedBox(width: 6),
                  Text(
                    "رجوع للبلاغات",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5B3FCB),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _DetailCard(report: r),
        ],
      );
    }

    // قائمة الاختيار
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(14),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFF5B3FCB)),
                SizedBox(width: 8),
                Text(
                  "اختاري بلاغ لعرض التفاصيل",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(widget.reports.length, (i) {
              final r = widget.reports[i];
              final itemType   = (r["item_type"]    ?? "").toString();
              final status     = (r["status"]       ?? "open").toString();
              final statusLabel= (r["status_label"] ?? "").toString();
              final ticketId   = (r["ticket_id"]    ?? "").toString();

              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.07)),
                  ),
                  child: Row(
                    children: [
                      // اسم الغرض + رقم التذكرة
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              itemType,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              ticketId,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.4),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusBadge(status: status, label: statusLabel),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── كارد التفاصيل + التايم لاين ───

class _DetailCard extends StatelessWidget {
  final Map<String, dynamic> report;
  const _DetailCard({required this.report});

  String _s(dynamic v) => (v ?? "").toString();

  @override
  Widget build(BuildContext context) {
    final ticketId    = _s(report["ticket_id"]);
    final itemType    = _s(report["item_type"]);
    final status      = _s(report["status"]);
    final statusLabel = _s(report["status_label"]);

    final timeline = (report["timeline"] is List)
        ? (report["timeline"] as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList()
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: اسم الغرض + ستيتس
            Row(
              children: [
                const Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFF5B3FCB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    itemType,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                _StatusBadge(status: status, label: statusLabel),
              ],
            ),

            const SizedBox(height: 6),

            // رقم التذكرة
            Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 13, color: Colors.black38),
                const SizedBox(width: 5),
                Text(
                  ticketId,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.black.withOpacity(0.08)),
            const SizedBox(height: 16),

            // التايم لاين
            _Timeline(steps: timeline),
          ],
        ),
      ),
    );
  }
}

// ─── Status Badge ───

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;
  const _StatusBadge({required this.status, required this.label});

  Color get _color {
    switch (status) {
      case "open":      return const Color(0xFF1976D2);
      case "matched":   return const Color(0xFFF57C00);
      case "awaiting":  return const Color(0xFF6A1B9A);
      case "collected": return const Color(0xFF2E7D32);
      default:          return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _color,
        ),
      ),
    );
  }
}

// ─── Timeline ───

class _Timeline extends StatelessWidget {
  final List<Map<String, dynamic>> steps;
  const _Timeline({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "مسار البلاغ",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ...List.generate(steps.length, (i) {
          final step   = steps[i];
          final label  = (step["label"]  ?? "").toString();
          final done   = step["done"]   == true;
          final active = step["active"] == true;
          final isLast = i == steps.length - 1;

          Color dotColor;
          IconData dotIcon;
          if (active) {
            dotColor = const Color(0xFF5B3FCB);
            dotIcon  = Icons.radio_button_checked_rounded;
          } else if (done) {
            dotColor = const Color(0xFF2E7D32);
            dotIcon  = Icons.check_circle_rounded;
          } else {
            dotColor = Colors.black26;
            dotIcon  = Icons.radio_button_unchecked_rounded;
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Icon(dotIcon, size: 20, color: dotColor),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 32,
                        color: done
                            ? const Color(0xFF2E7D32).withOpacity(0.35)
                            : Colors.black12,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1, bottom: 10),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                      color: active
                          ? const Color(0xFF5B3FCB)
                          : (done ? Colors.black87 : Colors.black38),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}