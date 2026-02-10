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
                    return const Center(child: Text('لا توجد بلاغات حتى الآن'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) {
                      final data = docs[i].data();

                      final ticketId =
                          (data['ticket_id'] ?? docs[i].id).toString();
                      final createdAt = (data['created_at'] ?? '').toString();
                      final status = (data['status'] ?? 'open').toString();

                      final photoUrl = (data['photo_url'] ?? '').toString();
                      final itemType = (data['item_type'] ?? '').toString();
                      final description = (data['description'] ?? '').toString();
                      final stationName = (data['station_name'] ?? '').toString();
                      final phone = (data['phone'] ?? '').toString();

                      final dt = _tryParseIso(createdAt);
                      final dateText = dt != null ? _formatDate(dt) : "—";
                      final timeText = dt != null ? _formatTime(dt) : "—";

                      final isSelected = _selectedIndex == i;

                      return _SelectableReportCard(
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedIndex = isSelected ? null : i;
                          });
                        },
                        onDetailsTap: () => _openDetailsSheet(
                          context,
                          ticketId: ticketId,
                          dateText: dateText,
                          timeText: timeText,
                          statusText: _statusLabel(status),
                          photoUrl: photoUrl.isEmpty ? null : photoUrl,
                          stationName: stationName.isEmpty ? null : stationName,
                          itemType: itemType.isEmpty ? null : itemType,
                          description: description.isEmpty ? null : description,
                          phone: phone.isEmpty ? null : phone,
                        ),
                        ticketId: ticketId,
                        dateText: dateText,
                        statusText: _statusLabel(status),
                        statusIndex: _mapStatusToIndex(status),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  // ---------- Bottom sheet (مثل الصورة الثانية) ----------
  void _openDetailsSheet(
    BuildContext context, {
    required String ticketId,
    required String dateText,
    required String timeText,
    required String statusText,
    String? photoUrl,
    String? stationName,
    String? itemType,
    String? description,
    String? phone,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'التفاصيل:',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 185,
                    width: double.infinity,
                    color: const Color(0xFFF0F0F0),
                    child: photoUrl == null
                        ? const Center(
                            child: Icon(Icons.image_outlined,
                                size: 72, color: Colors.black26),
                          )
                        : Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (c, child, p) =>
                                p == null ? child : const Center(child: CircularProgressIndicator()),
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  size: 72, color: Colors.black26),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                _SheetRow(label: 'رقم البلاغ:', value: ticketId),
                const SizedBox(height: 10),
                _SheetRow(label: 'التاريخ:', value: dateText),
                const SizedBox(height: 10),
                _SheetRow(label: 'الوقت التقريبي:', value: timeText),
                const SizedBox(height: 10),
                _SheetRow(label: 'الحالة:', value: statusText),
                if (stationName != null) ...[
                  const SizedBox(height: 10),
                  _SheetRow(label: 'المحطة:', value: stationName),
                ],
                if (itemType != null) ...[
                  const SizedBox(height: 10),
                  _SheetRow(label: 'النوع:', value: itemType),
                ],
                if (description != null) ...[
                  const SizedBox(height: 10),
                  _SheetRow(label: 'الوصف:', value: description),
                ],
                if (phone != null) ...[
                  const SizedBox(height: 10),
                  _SheetRow(label: 'رقم التواصل:', value: phone),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Status mapping ----------
  int _mapStatusToIndex(String status) {
    switch (status) {
      case 'open':
        return 0;
      case 'received':
        return 1;
      case 'verifying':
        return 2;
      case 'processing':
        return 3;
      case 'closed':
        return 4;
      default:
        return 0;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'تم الإرسال';
      case 'received':
        return 'جارٍ الاستلام';
      case 'verifying':
        return 'جارٍ التحقق';
      case 'processing':
        return 'جارٍ المعالجة';
      case 'closed':
        return 'تم الإغلاق';
      default:
        return 'تم الإرسال';
    }
  }

  DateTime? _tryParseIso(String iso) {
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime d) => "${d.year}/${d.month}/${d.day}";

  String _formatTime(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? "PM" : "AM";
    return "$h12:$m $ampm";
  }
}

// =====================================================
// ✅ Card with animation + selected outline on edges
// =====================================================
class _SelectableReportCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetailsTap;

  final String ticketId;
  final String dateText;
  final String statusText;
  final int statusIndex;

  const _SelectableReportCard({
    required this.selected,
    required this.onTap,
    required this.onDetailsTap,
    required this.ticketId,
    required this.dateText,
    required this.statusText,
    required this.statusIndex,
  });

  static const purple = Color(0xFF964C9B);

  static const steps = [
    'تم الإرسال',
    'جارٍ الاستلام',
    'جارٍ التحقق',
    'جارٍ المعالجة',
    'تم الإغلاق',
  ];

  @override
  Widget build(BuildContext context) {
    final scale = selected ? 1.03 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        scale: scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              // ✅ حدود البطاقة الخارجية (مثل اللي بالصورة على المختارة)
              color: selected ? purple : Colors.transparent,
              width: selected ? 2.0 : 0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(selected ? 0.18 : 0.10),
                blurRadius: selected ? 18 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // معلومات أعلى (مركزة مثل الموك)
              _CenterInfoRow(label: 'رقم البلاغ:', value: ticketId),
              const SizedBox(height: 10),
              _CenterInfoRow(label: 'التاريخ:', value: dateText),
              const SizedBox(height: 10),
              _CenterInfoRow(label: 'الحالة:', value: statusText),
              const SizedBox(height: 14),

              // الإطار الداخلي البنفسجي (زي الموك)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: purple, width: 2.2),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _TopMiniTab(
                          title: 'حالة البلاغ',
                          color: Colors.redAccent,
                          onTap: () {}, // ما نسوي شيء
                        ),
                        const SizedBox(width: 14),
                        _TopMiniTab(
                          title: 'التفاصيل',
                          color: Colors.blueAccent,
                          onTap: onDetailsTap, // ✅ يفتح البوتوم شيت
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StatusTimelineExact(
                      steps: steps,
                      currentIndex: statusIndex.clamp(0, 4),
                      activeColor: purple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopMiniTab extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _TopMiniTab({
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2.2,
            width: 54,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _CenterInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
      ],
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;

  const _SheetRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}

/// Timeline بنفس شكل الموك (دوائر + الحالية صفراء)
class _StatusTimelineExact extends StatelessWidget {
  final List<String> steps;
  final int currentIndex;
  final Color activeColor;

  const _StatusTimelineExact({
    required this.steps,
    required this.currentIndex,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFF1C40F);

    return Column(
      children: [
        SizedBox(
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 8,
                right: 8,
                child: Container(height: 3, color: Colors.black12),
              ),
              Positioned(
                left: 8,
                right: 8,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final total = steps.length - 1;
                    final ratio = total == 0 ? 0.0 : (currentIndex / total);
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(height: 3, width: c.maxWidth * ratio, color: activeColor),
                    );
                  },
                ),
              ),
              Row(
                children: List.generate(steps.length, (i) {
                  final active = i <= currentIndex;
                  final isCurrent = i == currentIndex;

                  final fill = isCurrent
                      ? yellow
                      : (active ? activeColor : Colors.white);
                  final border = active ? activeColor : Colors.black26;

                  return Expanded(
                    child: Center(
                      child: Container(
                        width: 12.5,
                        height: 12.5,
                        decoration: BoxDecoration(
                          color: fill,
                          border: Border.all(color: border, width: 2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: steps
              .map(
                (s) => Expanded(
                  child: Text(
                    s,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.2,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}