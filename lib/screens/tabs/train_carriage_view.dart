import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class _TrainCarriageViewState extends State<TrainCarriageView>
    with TickerProviderStateMixin {
  bool _loading = true;

  String? _error;       
  String? _infoMessage; 

  List<CarriageData> _carriages = [];
  List<AnimationController> _fillControllers = [];
  List<Animation<double>> _fillAnimations = [];

  late AnimationController _dotCtrl;
  late Animation<double> _dotScale;

  @override
  void initState() {
    super.initState();

    _dotCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _dotScale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _dotCtrl,
        curve: Curves.easeInOut,
      ),
    );

    _fetchCarriageData();
  }

  void _initAnimations() {
    for (final c in _fillControllers) {
      c.dispose();
    }
    _fillControllers = [];
    _fillAnimations = [];

    _fillControllers = List.generate(
      _carriages.length,
      (index) => AnimationController(
        duration: Duration(milliseconds: 1500 + (index * 200)),
        vsync: this,
      ),
    );

    _fillAnimations = _fillControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    Future.delayed(const Duration(milliseconds: 300), () {
      for (int i = 0; i < _fillControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 150), () {
          if (mounted) _fillControllers[i].forward();
        });
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _fillControllers) {
      controller.dispose();
    }
    _dotCtrl.dispose();
    super.dispose();
  }

 
  String _mapClassName(String? rawType) {
    final t = (rawType ?? '').toLowerCase().trim();
    if (t == 'vip') {
      return 'الدرجة الأولى';
    } else if (t == 'families') {
      return 'العوائل';
    } else if (t == 'individuals') {
      return 'الأفراد';
    }
    if (rawType != null && rawType.trim().isNotEmpty) {
      return rawType;
    }
    return 'العامة';
  }


  //   Firestore 
  Future<void> _fetchCarriageData() async {
    try {
      const monthKey = '2025-11_12';
      final fs = FirebaseFirestore.instance;

      // trips_month / 2025-11_12 / trips / {tripId}
      final tripRef = fs
          .collection('trips_month')
          .doc(monthKey)
          .collection('trips')
          .doc(widget.tripId);

      //  stop 
      final currentStopsSnap = await tripRef
          .collection('stops')
          .where('station_id', isEqualTo: widget.stationId)
          .limit(1)
          .get();

      if (currentStopsSnap.docs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error =
              'لا يوجد توقف لهذه المحطة (${widget.stationId}) في هذه الرحلة.';
          _infoMessage = null;
          _carriages = [];
          _loading = false;
        });
        return;
      }

      final currentStopDoc = currentStopsSnap.docs.first;
      final currentData = currentStopDoc.data();

      int currentSeq;
      try {
        currentSeq = int.parse(currentStopDoc.id);
      } catch (_) {
        final seqRaw = currentData['stop_sequence'];
        if (seqRaw is int) {
          currentSeq = seqRaw;
        } else if (seqRaw is String) {
          currentSeq = int.tryParse(seqRaw) ?? 1;
        } else {
          currentSeq = 1;
        }
      }

      // all stops for the trip
      final allStopsSnap = await tripRef.collection('stops').get();

      if (allStopsSnap.docs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'لا توجد أي توقفات مسجلة لهذه الرحلة.';
          _infoMessage = null;
          _carriages = [];
          _loading = false;
        });
        return;
      }

     
      final stopsMeta = <Map<String, dynamic>>[];

      for (final d in allStopsSnap.docs) {
        final data = d.data();
        
        // seq
        int seq;
        try {
          seq = int.parse(d.id);
        } catch (_) {
          final seqRaw = data['stop_sequence'];
          if (seqRaw is int) {
            seq = seqRaw;
          } else if (seqRaw is String) {
            seq = int.tryParse(seqRaw) ?? 0;
          } else {
            seq = 0;
          }
        }

        if (seq == 0) continue;

        Timestamp? depTs;
        final ts = data['departure_timestamp'];
        if (ts is Timestamp) depTs = ts;

        final sid = (data['station_id'] as String?) ?? '';

        stopsMeta.add({
          'ref': d.reference,
          'seq': seq,
          'depTs': depTs,
          'stationId': sid,
        });
      }

      if (stopsMeta.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'لا توجد بيانات كافية عن التوقفات لهذه الرحلة.';
          _infoMessage = null;
          _carriages = [];
          _loading = false;
        });
        return;
      }

      int firstSeq = stopsMeta.first['seq'] as int;
      for (final m in stopsMeta) {
        final s = m['seq'] as int;
        if (s < firstSeq) firstSeq = s;
      }

      // first station in the line
      if (currentSeq <= firstSeq) {
        if (!mounted) return;
        setState(() {
          _infoMessage =
              'هذه هي المحطة الأولى في هذا المسار. لا يمكن عرض بيانات الازدحام للمقطورات لكونها اول انطلاقة.';
          _error = null;
          _carriages = [];
          _loading = false;
        });
        return;
      }

      // current time
      final nowUtc = DateTime.now().toUtc();

      //  departure <= now
      Map<String, dynamic>? lastDeparted;
      for (final m in stopsMeta) {
        final seq = m['seq'] as int;
        final depTs = m['depTs'] as Timestamp?;

        if (seq >= currentSeq) continue; 
        if (depTs == null) continue;

        final depTime = depTs.toDate().toUtc();
        if (depTime.isAfter(nowUtc)) continue; // هنا لما يكون لسه ما مشى منها

        if (lastDeparted == null) {
          lastDeparted = m;
        } else {
          final prevDep =
              (lastDeparted['depTs'] as Timestamp).toDate().toUtc();
          if (depTime.isAfter(prevDep)) lastDeparted = m;
        }
      }

      //  لما الرحله ما بعد بدت
      if (lastDeparted == null) {
        if (!mounted) return;
        setState(() {
          _infoMessage =
              'القطار لم يغادر المحطة الأولى بعد لهذه الرحلة. سيتم عرض ازدحام المقطورات عند تحركه.';
          _error = null;
          _carriages = [];
          _loading = false;
        });
        return;
      }

      final lastStopRef = lastDeparted['ref'] as DocumentReference;

      // carriages for last destenation
      final carSnap = await lastStopRef
          .collection('carriages')
          .orderBy('carriage_no')
          .get();

      if (carSnap.docs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _infoMessage =
              'لا توجد بيانات ازدحام للمقطورات حتى الآن. قد يكون القطار شبه خالي أو لم يغادر بعد.';
          _error = null;
          _carriages = [];
          _loading = false;
        });
        return;
      }

      final carriages = carSnap.docs.map((doc) {
        final data = doc.data();

        final numRaw = data['carriage_no'];
        final occRaw = data['occupancy_pct'];
        final typeRaw = data['carriage_type'] as String?;

        final number = (numRaw is int)
            ? numRaw
            : (numRaw is num)
                ? numRaw.toInt()
                : 1;

        final occ = (occRaw is num) ? occRaw.toDouble() : 0.0;

        final className = _mapClassName(typeRaw);
        final level = _getCrowdingLevel(occ);

        return CarriageData(
          number: number,
          className: className,
          crowdingPercent: occ,
          crowdingLevel: level,
        );
      }).toList();

     
      final allZero = carriages.isNotEmpty &&
          carriages.every((c) => c.crowdingPercent <= 0);

      if (!mounted) return;

      setState(() {
        _carriages = carriages;
        _loading = false;
        _error = null;
        _infoMessage = allZero
            ? 'القطار شبه خالي الآن، جميع المقطورات تقريبًا فارغة. هذه فرصة ممتازة لاختيار المقطورة الأنسب لك.'
            : null;
      });

      _initAnimations();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'حدث خطأ أثناء تحميل بيانات المقطورات. حاول مرة أخرى.';
        _infoMessage = null;
        _carriages = [];
        _loading = false;
      });
    }
  }

  String _getCrowdingLevel(double percent) {
    if (percent >= 80) return 'extreme';
    if (percent >= 60) return 'high';
    if (percent >= 40) return 'medium';
    return 'low';
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

  String _labelForLevel(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return 'منخفض';
      case 'medium':
        return 'متوسط';
      case 'high':
        return 'مزدحم';
      case 'extreme':
        return 'شديد الازدحام';
      default:
        return 'غير معروف';
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

  Color _getGradientColorTop(double percent) {
    final level = _getCrowdingLevel(percent);
    return _colorForLevel(level);
  }

  Color _getGradientColorBottom(double percent) {
    final level = _getCrowdingLevel(percent);
    switch (level.toLowerCase()) {
      case 'low':
        return const Color(0xFF4CAF50);
      case 'medium':
        return const Color(0xFFFF9800);
      case 'high':
        return const Color(0xFFF44336);
      case 'extreme':
        return const Color(0xFF8B0000);
      default:
        return Colors.grey;
    }
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
          title: const Text(
            'مقطورات القطار',
            style: TextStyle(color: Colors.black),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTripInfoCard(),
                    const SizedBox(height: 12),

                   
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                   
                    if (_infoMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange[700], size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _infoMessage!,
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),

                    if (_carriages.isNotEmpty) ...[
                      _buildCrowdingLegend(),
                      const SizedBox(height: 24),
                      Center(child: _buildTrainVisualization()),
                    ],

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
        Text(
          widget.stationName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        Container(
          height: 1,
          color: Colors.grey[300],
        ),
        const SizedBox(height: 20),
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

  Widget _buildCrowdingLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('منخفض', Colors.green),
        _buildLegendItem('متوسط', Colors.orange),
        _buildLegendItem('مزدحم', Colors.red),
        _buildLegendItem(
            'شديد', const Color.fromARGB(255, 122, 0, 0)),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTrainVisualization() {
    const double carriageHeight = 130.0;
    const double connectorHeight = 20.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: List.generate(_carriages.length, (index) {
            final carriage = _carriages[index];
            final isFirst = index == 0;
            final isLast = index == _carriages.length - 1;

            return Column(
              children: [
                if (index > 0)
                  SizedBox(
                    width: 85,
                    height: connectorHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
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
                AnimatedBuilder(
                  animation: (index < _fillAnimations.length)
                      ? _fillAnimations[index]
                      : const AlwaysStoppedAnimation<double>(1.0),
                  builder: (context, child) {
                    final animValue = (index < _fillAnimations.length)
                        ? _fillAnimations[index].value
                        : 1.0;

                    return ClipRRect(
                      borderRadius: isFirst
                          ? const BorderRadius.vertical(
                              top: Radius.circular(26),
                            )
                          : isLast
                              ? const BorderRadius.vertical(
                                  bottom: Radius.circular(26),
                                )
                              : BorderRadius.zero,
                      child: Container(
                        width: 85,
                        height: carriageHeight,
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.black, width: 3.5),
                          borderRadius: isFirst
                              ? const BorderRadius.vertical(
                                  top: Radius.circular(10),
                                )
                              : isLast
                                  ? const BorderRadius.vertical(
                                      bottom: Radius.circular(26),
                                    )
                                  : BorderRadius.zero,
                        ),
                        child: Stack(
                          children: [
                            Container(color: Colors.grey[300]),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: animValue,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        _getGradientColorTop(
                                            carriage.crowdingPercent),
                                        _getGradientColorBottom(
                                            carriage.crowdingPercent),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                if (isFirst)
                                  Container(
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(3),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical:
                                          isFirst || isLast ? 8 : 12,
                                    ),
                                    child: Column(
                                      children: List.generate(
                                        3,
                                        (windowIndex) => Expanded(
                                          child: Container(
                                            margin:
                                                const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                if (isLast)
                                  Container(
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(3),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          }),
        ),

        const SizedBox(width: 16),


        Column(
          children: List.generate(_carriages.length, (index) {
            return Column(
              children: [
                if (index > 0) const SizedBox(height: connectorHeight),
                SizedBox(
                  height: carriageHeight,
                  width: 35,
                  child: CustomPaint(
                    size: const Size(35, carriageHeight),
                    painter: DashedArrowPainter(),
                  ),
                ),
              ],
            );
          }),
        ),

        const SizedBox(width: 8),

        Column(
          children: List.generate(_carriages.length, (index) {
            final carriage = _carriages[index];
            final color = _colorForLevel(carriage.crowdingLevel);
            final label = _labelForLevel(carriage.crowdingLevel);

            return Column(
              children: [
                if (index > 0) const SizedBox(height: connectorHeight),
                Container(
                  height: carriageHeight,
                  width: 110,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: color,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        _pulsingDot(color),
                        const SizedBox(height: 12),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
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
      ],
    );
  }
}

class DashedArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[500]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

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
  final String crowdingLevel;

  CarriageData({
    required this.number,
    required this.className,
    required this.crowdingPercent,
    required this.crowdingLevel,
  });
}
