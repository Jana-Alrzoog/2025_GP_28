import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrackReportsScreen extends StatefulWidget {
  const TrackReportsScreen({super.key});

  @override
  State<TrackReportsScreen> createState() => _TrackReportsScreenState();
}

class _TrackReportsScreenState extends State<TrackReportsScreen> {
  int? _selectedIndex;

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream(String uid) {
    return FirebaseFirestore.instance
        .collection('lost_found_reports')
        .where('passenger_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  static const _steps = [
    _StepMeta('تم التسجيل',          'open',      Icons.assignment_turned_in_rounded),
    _StepMeta('تم العثور على تطابق', 'matched',   Icons.search_rounded),
    _StepMeta('بانتظار الاستلام',    'awaiting',  Icons.hourglass_top_rounded),
    _StepMeta('تم الاستلام',         'collected', Icons.check_circle_rounded),
  ];

  static int _statusToIndex(String status) {
    switch (status) {
      case 'matched':   return 1;
      case 'awaiting':  return 2;
      case 'collected': return 3;
      default:          return 0;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'open':      return 'جاري البحث';
      case 'matched':   return 'تم العثور على تطابق';
      case 'awaiting':  return 'بانتظار الاستلام';
      case 'collected': return 'تم الاستلام';
      default:          return 'جاري البحث';
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'open':      return const Color(0xFF1976D2);
      case 'matched':   return const Color(0xFFF57C00);
      case 'awaiting':  return const Color(0xFF6A1B9A);
      case 'collected': return const Color(0xFF2E7D32);
      default:          return const Color(0xFF1976D2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F5F5),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: const Text(
            'تتبع بلاغاتي',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
        body: user == null
            ? const Center(child: Text('الرجاء تسجيل الدخول'))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stream(user.uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return const Center(child: Text('صار خطأ في تحميل البلاغات'));
                  }

                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.black26),
                          const SizedBox(height: 12),
                          const Text(
                            'لا توجد بلاغات حتى الآن',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) {
                      final data = docs[i].data();
                      final ticketId   = (data['ticket_id'] ?? docs[i].id).toString();
                      final createdAt  = (data['created_at'] ?? '').toString();
                      final status     = (data['status'] ?? 'open').toString();
                      final itemType   = (data['item_type'] ?? '').toString();
                      final description= (data['description'] ?? '').toString();
                      final stationName= (data['station_name'] ?? '').toString();
                      final photoUrl   = (data['photo_url'] ?? '').toString();
                      final phone      = (data['phone'] ?? '').toString();
                      final color      = (data['color'] ?? '').toString();

                      final dt = _tryParseIso(createdAt);
                      final dateText = dt != null ? _formatDate(dt) : '—';
                      final timeText = dt != null ? _formatTime(dt) : '—';

                      final statusIndex = _statusToIndex(status);
                      final statusText  = _statusLabel(status);
                      final statusClr   = _statusColor(status);
                      final isSelected  = _selectedIndex == i;

                      return _ReportCard(
                        selected: isSelected,
                        onTap: () => setState(() =>
                            _selectedIndex = isSelected ? null : i),
                        onDetailsTap: () => _openDetailsSheet(
                          context,
                          ticketId:    ticketId,
                          dateText:    dateText,
                          timeText:    timeText,
                          statusText:  statusText,
                          statusColor: statusClr,
                          photoUrl:    photoUrl.isEmpty ? null : photoUrl,
                          stationName: stationName.isEmpty ? null : stationName,
                          itemType:    itemType.isEmpty ? null : itemType,
                          description: description.isEmpty ? null : description,
                          phone:       phone.isEmpty ? null : phone,
                          color:       color.isEmpty ? null : color,
                        ),
                        ticketId:    ticketId,
                        itemType:    itemType,
                        dateText:    dateText,
                        statusText:  statusText,
                        statusColor: statusClr,
                        statusIndex: statusIndex,
                        steps:       _steps,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  void _openDetailsSheet(
    BuildContext context, {
    required String ticketId,
    required String dateText,
    required String timeText,
    required String statusText,
    required Color statusColor,
    String? photoUrl,
    String? stationName,
    String? itemType,
    String? description,
    String? phone,
    String? color,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 38, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'تفاصيل البلاغ',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.black45),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // صورة
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 170,
                  width: double.infinity,
                  color: const Color(0xFFF0F0F0),
                  child: photoUrl == null
                      ? const Center(child: Icon(Icons.image_outlined, size: 60, color: Colors.black26))
                      : Image.network(
                          photoUrl, fit: BoxFit.cover,
                          loadingBuilder: (c, child, p) =>
                              p == null ? child : const Center(child: CircularProgressIndicator()),
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 60, color: Colors.black26),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Status badge
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _SheetRow(icon: Icons.confirmation_number_outlined, label: 'رقم البلاغ', value: ticketId),
              if (itemType != null) _SheetRow(icon: Icons.inventory_2_outlined, label: 'النوع', value: itemType),
              if (color != null) _SheetRow(icon: Icons.color_lens_outlined, label: 'اللون', value: color),
              if (description != null) _SheetRow(icon: Icons.notes_rounded, label: 'الوصف', value: description),
              if (stationName != null) _SheetRow(icon: Icons.location_on_outlined, label: 'المحطة', value: stationName),
              _SheetRow(icon: Icons.calendar_today_outlined, label: 'التاريخ', value: '$dateText — $timeText'),
              if (phone != null) _SheetRow(icon: Icons.phone_outlined, label: 'رقم التواصل', value: phone),
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _tryParseIso(String iso) {
    try { return DateTime.parse(iso).toLocal(); } catch (_) { return null; }
  }

  String _formatDate(DateTime d) => "${d.year}/${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}";

  String _formatTime(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return "$h12:$m ${d.hour >= 12 ? 'PM' : 'AM'}";
  }
}

// ─── Step Meta ───
class _StepMeta {
  final String label;
  final String statusKey;
  final IconData icon;
  const _StepMeta(this.label, this.statusKey, this.icon);
}

// ─── Report Card ───
class _ReportCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetailsTap;
  final String ticketId;
  final String itemType;
  final String dateText;
  final String statusText;
  final Color statusColor;
  final int statusIndex;
  final List<_StepMeta> steps;

  const _ReportCard({
    required this.selected,
    required this.onTap,
    required this.onDetailsTap,
    required this.ticketId,
    required this.itemType,
    required this.dateText,
    required this.statusText,
    required this.statusColor,
    required this.statusIndex,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? statusColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.14 : 0.07),
              blurRadius: selected ? 18 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_rounded, size: 18, color: statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemType.isNotEmpty ? itemType : 'غرض مجهول',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                      Text(
                        ticketId,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.35),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Text(
              dateText,
              style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.4), fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 14),

            // Timeline
            _HorizontalTimeline(
              steps: steps,
              currentIndex: statusIndex,
              activeColor: statusColor,
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.black.withOpacity(0.06)),
            const SizedBox(height: 10),

            // زر التفاصيل
            GestureDetector(
              onTap: onDetailsTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    'عرض التفاصيل',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Horizontal Timeline ───
class _HorizontalTimeline extends StatelessWidget {
  final List<_StepMeta> steps;
  final int currentIndex;
  final Color activeColor;

  const _HorizontalTimeline({
    required this.steps,
    required this.currentIndex,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // الخط + النقاط
        SizedBox(
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // خط رمادي كامل
              Positioned(
                left: 16, right: 16,
                child: Container(height: 2.5, color: Colors.black.withOpacity(0.08)),
              ),
              // خط ملوّن للتقدم
              Positioned(
                left: 16, right: 16,
                child: LayoutBuilder(
                  builder: (_, c) {
                    final ratio = steps.length <= 1
                        ? 0.0
                        : currentIndex / (steps.length - 1);
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        height: 2.5,
                        width: c.maxWidth * ratio,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // النقاط
              Row(
                children: List.generate(steps.length, (i) {
                  final done    = i < currentIndex;
                  final current = i == currentIndex;

                  return Expanded(
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width:  current ? 18 : 13,
                        height: current ? 18 : 13,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? activeColor
                              : (current ? activeColor : Colors.white),
                          border: Border.all(
                            color: (done || current) ? activeColor : Colors.black26,
                            width: current ? 2.5 : 2,
                          ),
                          boxShadow: current
                              ? [BoxShadow(color: activeColor.withOpacity(0.35), blurRadius: 8)]
                              : [],
                        ),
                        child: done
                            ? Icon(Icons.check, size: 8, color: Colors.white)
                            : (current
                                ? Center(
                                    child: Container(
                                      width: 6, height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Labels
        Row(
          children: List.generate(steps.length, (i) {
            final active = i <= currentIndex;
            return Expanded(
              child: Text(
                steps[i].label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? activeColor : Colors.black38,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── Sheet Row ───
class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SheetRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.black45),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}