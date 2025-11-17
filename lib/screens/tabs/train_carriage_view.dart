// lib/train_carriage_view.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TrainCarriageView extends StatefulWidget {
  final String stationName;
  final String tripId;
  final String lineId;
  final int lineNumber;
  final Color lineColor;
  final String departureTime;
  final String destination;
  final String stationId;

  const TrainCarriageView({
    super.key,
    required this.stationName,
    required this.tripId,
    required this.lineId,
    required this.lineNumber,
    required this.lineColor,
    required this.departureTime,
    required this.destination,
    required this.stationId,
  });

  @override
  State<TrainCarriageView> createState() => _TrainCarriageViewState();
}

class _TrainCarriageViewState extends State<TrainCarriageView> {
  bool _loading = true;
  String? _error;
  bool _usingMock = false;
  List<CarriageData> _carriages = [];

  @override
  void initState() {
    super.initState();
    _fetchCarriageData();
  }

  void _useMockCarriages() {
    setState(() {
      _usingMock = true;
      _error = null;
      _loading = false;
      _carriages = [
        CarriageData(
          number: 1,
          className: 'الدرجة الأولى',
          crowdingPercent: 100,
        ),
        CarriageData(
          number: 2,
          className: 'العوائل',
          crowdingPercent: 70,
        ),
        CarriageData(
          number: 3,
          className: 'العوائل',
          crowdingPercent: 30,
        ),
        CarriageData(
          number: 4,
          className: 'الأفراد',
          crowdingPercent: 45,
        ),
      ];
    });
  }

  Future<void> _fetchCarriageData() async {
    try {
      final url = Uri.parse(
        'https://masar-sim.onrender.com/carriage_crowding/${widget.tripId}/${widget.stationId}',
      );

      final res = await http.get(url);

      if (res.statusCode != 200) {
        _useMockCarriages();
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['carriages'] is! List) {
        _useMockCarriages();
        return;
      }

      final List list = data['carriages'] as List;
      if (list.isEmpty) {
        _useMockCarriages();
        return;
      }

      final carriages = list.map((c) {
        return CarriageData(
          number: c['carriage_number'] ?? 1,
          className: c['class_name'] ?? 'العامة',
          crowdingPercent: (c['crowding_percent'] ?? 0).toDouble(),
        );
      }).toList();

      setState(() {
        _carriages = carriages;
        _loading = false;
        _usingMock = false;
      });
    } catch (e) {
      _useMockCarriages();
    }
  }

  Color _getGradientColorTop(double percent) {
    if (percent >= 80) return const Color(0xFFD12027);
    if (percent >= 50) return const Color(0xFFF68D39);
    return const Color(0xFF43B649);
  }

  Color _getGradientColorBottom(double percent) {
    if (percent >= 80) return const Color(0xFF8B0000);
    if (percent >= 50) return const Color(0xFFFF6B35);
    return const Color(0xFFFFC107);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),

        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTripInfoCard(),
              const SizedBox(height: 32),
              _buildTrainVisualization(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripInfoCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // اسم المحطة
        Text(
          widget.stationName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 12),

        // المسار
        Row(
          children: [
            const Text(
              'المسار:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.lineColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${widget.lineNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // نحو
        Row(
          children: [
            Text(
              'نحو: ${widget.destination}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // الوقت
        Row(
          children: [
            Text(
              'الوقت: ${widget.departureTime}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // الخط الفاصل
        Container(
          height: 1,
          color: Colors.grey[300],
        ),

        const SizedBox(height: 20),

        // عنوان معدل الزحمة - في النص تماماً
        const Center(
          child: Text(
            'معدل ازدحام المقطورات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrainVisualization() {
    const double carriageHeight = 130.0;
    const double connectorHeight = 20.0;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // القطار - الجزء الأيسر
            Column(
              children: List.generate(_carriages.length, (index) {
                final carriage = _carriages[index];
                final isFirst = index == 0;
                final isLast = index == _carriages.length - 1;

                return Column(
                  children: [
                    // الموصل بين العربات
                    if (index > 0)
                      Container(
                        width: 85,
                        height: connectorHeight,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // الخطوط الجانبية
                            Positioned(
                              left: 10,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2.5,
                                color: Colors.black,
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2.5,
                                color: Colors.black,
                              ),
                            ),
                            // الوصلة
                            Center(
                              child: Container(
                                width: 50,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(4.5),
                                  border: Border.all(
                                    color: Colors.grey[600]!,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // العربة
                    Container(
                      width: 85,
                      height: carriageHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _getGradientColorTop(carriage.crowdingPercent),
                            _getGradientColorBottom(carriage.crowdingPercent),
                          ],
                        ),
                        border: Border.all(color: Colors.black, width: 3.5),
                        borderRadius: isFirst
                            ? const BorderRadius.vertical(
                            top: Radius.circular(26))
                            : isLast
                            ? const BorderRadius.vertical(
                            bottom: Radius.circular(26))
                            : BorderRadius.zero,
                      ),
                      child: Column(
                        children: [
                          // رأس العربة الأولى
                          if (isFirst)
                            Container(
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(22),
                                ),
                              ),
                            ),

                          // النوافذ
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: isFirst || isLast ? 8 : 12,
                              ),
                              child: Column(
                                children: List.generate(
                                  3,
                                      (windowIndex) => Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey[400]!,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ذيل العربة الأخيرة
                          if (isLast)
                            Container(
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(22),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),

            const SizedBox(width: 16),

            // الأسهم المنقطة
            Column(
              children: List.generate(_carriages.length, (index) {
                return Column(
                  children: [
                    if (index > 0) const SizedBox(height: connectorHeight),
                    Container(
                      height: carriageHeight,
                      width: 35,
                      child: CustomPaint(
                        size: Size(35, carriageHeight),
                        painter: DashedArrowPainter(),
                      ),
                    ),
                  ],
                );
              }),
            ),

            const SizedBox(width: 8),

            // المربعات - الجزء الأيمن (بنفس الحجم والمحتوى في النص)
            Expanded(
              child: Column(
                children: List.generate(_carriages.length, (index) {
                  final carriage = _carriages[index];

                  return Column(
                    children: [
                      if (index > 0) const SizedBox(height: connectorHeight),
                      Container(
                        height: carriageHeight,
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getBorderColor(carriage.crowdingPercent),
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                carriage.className,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${carriage.crowdingPercent.toInt()}%',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: _getTextColor(carriage.crowdingPercent),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getBorderColor(double percent) {
    if (percent >= 80) return const Color(0xFFD12027);
    if (percent >= 50) return const Color(0xFFF68D39);
    return const Color(0xFF43B649);
  }

  Color _getTextColor(double percent) {
    if (percent >= 80) return const Color(0xFFD12027);
    if (percent >= 50) return const Color(0xFFF68D39);
    return const Color(0xFF43B649);
  }
}

class DashedArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[500]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // رسم الخط المنقط الأفقي في النص
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width - 8) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    // رسم رأس السهم (يشير لليمين) - معدل للمنتصف
    final arrowPaint = Paint()
      ..color = Colors.grey[500]!
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    final arrowX = size.width;
    arrowPath.moveTo(arrowX, y);
    arrowPath.lineTo(arrowX - 7, y - 5);
    arrowPath.lineTo(arrowX - 7, y + 5);
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CarriageData {
  final int number;
  final String className;
  final double crowdingPercent;

  CarriageData({
    required this.number,
    required this.className,
    required this.crowdingPercent,
  });
}