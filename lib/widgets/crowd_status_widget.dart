import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

/*==========================
   Crowd Status Widget
   - current: from /snapshot/{sid}
   - future 30-min: from /predict_30min_live/{sid}
 ==========================*/

const String kMasarApiBaseUrl = 'https://masar-sim.onrender.com';

class CrowdStatusWidget extends StatefulWidget {
  final String? stationId;

  const CrowdStatusWidget({required this.stationId, super.key});

  @override
  State<CrowdStatusWidget> createState() => CrowdStatusWidgetState();
}

class CrowdStatusWidgetState extends State<CrowdStatusWidget>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  String? _crowdLevel;  // Low / Medium / High / Extreme (الحالية)
  String? _futureLevel; // Low / Medium / High / Extreme (التنبؤ)

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

    _fetchStatusAndForecast();
  }

  @override
  void didUpdateWidget(covariant CrowdStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationId != widget.stationId) {
      _fetchStatusAndForecast();
    }
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStatusAndForecast() async {
    final sid = widget.stationId;

    if (sid == null || sid.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'لا يوجد معلومات لهذه المحطة.';
      });
      return;
    }

   
    final raw = sid.trim();
    final normalizedSid = raw.toUpperCase().startsWith('S')
        ? raw.toUpperCase()
        : 'S$raw';

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) /snapshot/{sid}
      final snapUrl =
          Uri.parse('$kMasarApiBaseUrl/snapshot/$normalizedSid');
      final snapRes = await http.get(snapUrl);

      if (snapRes.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'تعذّر تحميل حالة الازدحام.';
        });
        return;
      }

      final snapData = jsonDecode(snapRes.body) as Map<String, dynamic>;
      final currentLevel =
          (snapData['crowd_level'] as String?) ?? 'Medium';

      // 2) /predict_30min_live/{sid}
      String? futureLevel;

      try {
        final predUrl = Uri.parse(
            '$kMasarApiBaseUrl/predict_30min_live/$normalizedSid');
        final predRes = await http.get(predUrl);

        if (predRes.statusCode == 200) {
          final predData =
              jsonDecode(predRes.body) as Map<String, dynamic>;
          // server return crowd_level_30min
          futureLevel =
              (predData['crowd_level_30min'] as String?) ?? currentLevel;
        } else {
          futureLevel = currentLevel;
        }
      } catch (_) {
        
        futureLevel = currentLevel;
      }

      setState(() {
        _crowdLevel = currentLevel;
        _futureLevel = futureLevel;
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
        return 'منخفض';
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
        return const Color.fromARGB(255, 122, 0, 0);
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
      return Opacity(
        opacity: 0.75,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Lottie.asset(
              'assets/animations/loading.json',
              width: 70,
              height: 70,
            ),
          ),
        ),
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

    final levelNow = _crowdLevel ?? 'Medium';
    final levelFuture = _futureLevel ?? levelNow;

    final currentColor = _colorForLevel(levelNow);
    final futureColor = _colorForLevel(levelFuture);

    final currentLabel = _arabicLabel(levelNow);
    final futureLabel = _arabicLabel(levelFuture);

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
