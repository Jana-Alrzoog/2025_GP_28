import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/*==========================
   Crowd Status Widget
 ==========================*/

class CrowdStatusWidget extends StatefulWidget {
  final String? stationId;

  const CrowdStatusWidget({required this.stationId});

  @override
  State<CrowdStatusWidget> createState() => CrowdStatusWidgetState();
}

class CrowdStatusWidgetState extends State<CrowdStatusWidget>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  String? _crowdLevel; // Low / Medium / High / Extreme

  late final AnimationController _dotCtrl;
  late final Animation<double> _dotScale;

  @override
  void initState() {
    super.initState();

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _dotScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _dotCtrl, curve: Curves.easeOut),
    );
    _dotCtrl.repeat(reverse: true);

    _fetchSnapshot();
  }

  @override
  void didUpdateWidget(covariant CrowdStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationId != widget.stationId) {
      _fetchSnapshot();
    }
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSnapshot() async {
    final sid = widget.stationId;

    if (sid == null || sid.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'لا يوجد معرّف لهذه المحطة.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = Uri.parse('https://masar-sim.onrender.com/snapshot/$sid');
      final res = await http.get(url);

      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'تعذّر تحميل حالة الازدحام (كود ${res.statusCode}).';
        });
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      setState(() {
        _crowdLevel = (data['crowd_level'] as String?) ?? 'Medium';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'حدث خطأ أثناء الاتصال بالخادم.';
      });
    }
  }

  String _arabicLabel(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return 'سلس';
      case 'medium':
        return 'متوسط';
      case 'high':
        return 'مزدحم';
      case 'extreme':
        return 'مزدحم جدًا';
      default:
        return 'غير معروف';
    }
  }

  Color _colorForLevel(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'extreme':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _pulsingDot(Color color) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.5).animate(
              CurvedAnimation(
                parent: _dotCtrl,
                curve: Curves.easeOut,
              ),
            ),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          ScaleTransition(
            scale: _dotScale,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pulsingDot(color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _crowdRow({
    required String title,
    required Color color,
    required String label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            overflow: TextOverflow.visible,
          ),
        ),
        const SizedBox(width: 8),
        _pill(color, label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final level = _crowdLevel ?? 'Medium';
    final currentColor = _colorForLevel(level);
    final currentLabel = _arabicLabel(level);

    final futureColor = currentColor;
    final futureLabel = currentLabel;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _crowdRow(
            title: 'الحالية:',
            color: currentColor,
            label: currentLabel,
          ),
          const SizedBox(height: 12),
          _crowdRow(
            title: 'المتوقعة بعد 30 دقيقة:',
            color: futureColor,
            label: futureLabel,
          ),
        ],
      ),
    );
  }
}
