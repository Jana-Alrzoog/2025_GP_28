// lib/home_tab.dart
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/services/location_service.dart'; 
import 'package:geolocator/geolocator.dart';



/// دالة تطبيع نص (AR/EN) لنجاح المطابقة بين أسماء المحطات وملف station_id_map.json
String norm(String s) {
  var t = s.trim().toLowerCase();
  const diacritics = [
    '\u0610','\u0611','\u0612','\u0613','\u0614','\u0615','\u0616','\u0617','\u0618','\u0619','\u061A',
    '\u064B','\u064C','\u064D','\u064E','\u064F','\u0650','\u0651','\u0652','\u0653','\u0654','\u0655',
    '\u0656','\u0657','\u0658','\u0659','\u065A','\u065B','\u065C','\u065D','\u065E','\u065F','\u0670'
  ];
  for (final d in diacritics) t = t.replaceAll(d, '');
  t = t
      .replaceAll('ـ', '')
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('‏', '')
      .replaceAll('ٔ', '')
      .replaceAll('ٕ', '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const LatLng _riyadhCenter = LatLng(24.7136, 46.6753);

  GoogleMapController? _map;
  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};

  LatLng? _userLatLng;        // موقع المستخدم
  bool _useLocation = false;  // إعداد استخدام الموقع

  final Color _maskFill = Colors.black.withOpacity(0.75);
  final Color _borderColor = const Color(0xFFD12027);
  final double _borderWidth = 2;
  final double _glowMultiplier = 8;
  final double _glowOpacity = 0.25;

  final Map<String, BitmapDescriptor> _iconCache = {};

  double _currentZoom = 14;
  double _lastZoomBucket = -999;
  static const double _minSizePx = 18;
  static const double _maxSizePx = 44;
  static const double _zoomMin = 8;
  static const double _zoomMax = 16;

  final List<_Station> _stations = [];

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final List<_Station> _suggestions = [];
  bool _showSuggestions = false;

  final Map<String, MarkerId> _markerIdByNameKey = {};

  _Station? _selectedStation;
  bool _sheetOpen = false;

  // خريطة ربط station_id بالأسماء (قد تكون ID->Name أو Name->ID)
  Map<String, String> _stationIdMap = {};

  static const Color _blueHex = Color(0xFF00ADE5);
  static const Color _redHex = Color(0xFFD12027);
  static const Color _orangeHex = Color(0xFFF68D39);
  static const Color _greenHex = Color(0xFF43B649);
  static const Color _yellowHex = Color(0xFFFFC107);
  static const Color _purpleHex = Color(0xFF984C9D);

  @override
  void initState() {
    super.initState();
    _loadStationIdMap();
   
  }
   Future<void> _handleLocationOnFirstOpen() async {
    final useLoc = await LocationService.getUseLocation();
    final hasAsked = await LocationService.getHasAsked();
    if (!mounted) return;

    // لو قد سألناه قبل
    if (hasAsked) {
      // احترم الإعداد الحالي
      setState(() => _useLocation = useLoc);

      // لو المستخدم مطفّي استخدام الموقع من صفحة الحساب → لا نسأل ولا نطلب صلاحية
      if (!useLoc) return;
    } else {
      // أول مرة نسأل المستخدم
      final allow = await _showLocationDialog(context);

      // نخزّن إننا سألناه مرة
      await LocationService.setHasAsked(true);

      if (!allow) {
        // رفض من الدايالوج → نخزّن false ومانسوي شيء
        await LocationService.setUseLocation(false);
        if (!mounted) return;
        setState(() => _useLocation = false);
        return;
      }

      // وافق من الدايالوج → نخزّن true
      await LocationService.setUseLocation(true);
      if (!mounted) return;
      setState(() => _useLocation = true);
    }

    // هنا نجي لطلب صلاحية النظام (بس إذا الإعداد النهائي true)
    final perm = await LocationService.requestPermission();
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      await _moveCameraToUser();
    } else {
      await LocationService.setUseLocation(false);
      if (!mounted) return;
      setState(() => _useLocation = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم منح صلاحية الموقع. يمكنك تفعيلها من إعدادات الجهاز.'),
        ),
      );
    }
  }


  Future<void> _moveCameraToUser() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos == null) return;

    final userPos = LatLng(pos.latitude, pos.longitude);
    if (!mounted) return;

    setState(() {
      _userLatLng = userPos;
    });

    if (_map != null) {
      await _map!.animateCamera(
        CameraUpdate.newLatLngZoom(userPos, 15),
      );
    }
  }

  Future<bool> _showLocationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('السماح بالوصول للموقع'),
        content: const Text(
          'هل تريد أن يستخدم التطبيق موقعك الحالي لعرض المحطات الأقرب لك؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );
    return result ?? false;
  }



  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadStationIdMap() async {
    try {
      final raw = await rootBundle.loadString('assets/data/station_id_map.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      _stationIdMap = data.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint('❌ Failed to load station_id_map.json: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLatLng ?? _riyadhCenter,
              zoom: _currentZoom,
            ),
            onMapCreated: (c) async {
              _map = c;
              await _loadAndBuildMask();
              await _loadStations();
              await _rebuildMarkersForZoom(_currentZoom);
              await _handleLocationOnFirstOpen();
            },
            onCameraMove: (pos) {
              _currentZoom = pos.zoom;
              _maybeUpdateMarkerIconsForZoom(pos.zoom);
            },
            onCameraIdle: () => _maybeUpdateMarkerIconsForZoom(_currentZoom),
            polygons: _polygons,
            markers: _markers,
            myLocationEnabled: _useLocation && _userLatLng != null,
            myLocationButtonEnabled: _useLocation,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(14),
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        textInputAction: TextInputAction.search,
                        onChanged: _onQueryChanged,
                        onSubmitted: (value) => _searchAndGo(value),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن اسم المحطة…',
                          prefixIcon:
                              const Icon(Icons.search, color: Color(0xFFD12027)),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: Color(0xFF9CA3AF)),
                                  onPressed: () {
                                    setState(() {
                                      _searchCtrl.clear();
                                      _suggestions.clear();
                                      _showSuggestions = false;
                                    });
                                    _searchFocus.requestFocus();
                                  },
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    if (_showSuggestions && _suggestions.isNotEmpty)
                      const SizedBox(height: 8),
                    if (_showSuggestions && _suggestions.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: Color(0xFFE5E7EB),
                            ),
                            itemBuilder: (context, i) {
                              final st = _suggestions[i];
                              final subtitle = st.lines.isNotEmpty
                                  ? st.lines.join(' + ')
                                  : (st.altName ?? '');
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFFD12027),
                                ),
                                title: Text(
                                  st.name,
                                  style: const TextStyle(
                                    color: Color(0xFF1F1F1F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: subtitle.isEmpty
                                    ? null
                                    : Text(
                                        subtitle,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                onTap: () async {
                                  setState(() {
                                    _searchCtrl.text = st.name;
                                    _showSuggestions = false;
                                    _selectedStation = st;
                                  });
                                  _searchFocus.unfocus();
                                  await _goToStation(st, openSheet: true);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQueryChanged(String qRaw) {
    final q = _normalizeForSearch(qRaw);
    if (q.isEmpty) {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
      return;
    }

    final scored = <({_Station st, int score, int distance})>[];
    for (final st in _stations) {
      final nameAr = _normalizeForSearch(st.name);
      final nameEn = _normalizeForSearch(st.altName ?? '');

      int score = 0;
      int bestDist = 999;

      if (nameAr.startsWith(q) || nameEn.startsWith(q)) {
        score = 3;
      } else if (nameAr.contains(q) || nameEn.contains(q)) {
        score = 2;
      } else {
        bestDist = _editDistanceLimited(nameAr, q, 2);
        if (bestDist <= 2) score = 1;
      }

      if (score > 0) {
        scored.add((st: st, score: score, distance: bestDist));
      }
    }

    scored.sort((a, b) {
      final c1 = b.score.compareTo(a.score);
      if (c1 != 0) return c1;
      final c2 = a.distance.compareTo(b.distance);
      if (c2 != 0) return c2;
      return a.st.name.length.compareTo(b.st.name.length);
    });

    setState(() {
      _suggestions
        ..clear()
        ..addAll(scored.map((e) => e.st).take(15));
      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  Future<void> _searchAndGo(String query) async {
    final nq = _normalizeForSearch(query);
    if (nq.isEmpty) return;

    _Station? best;
    int bestScore = -1;
    int bestDist = 999;

    for (final st in _stations) {
      final nameAr = _normalizeForSearch(st.name);
      final nameEn = _normalizeForSearch(st.altName ?? '');
      int score = 0;
      int dist = 999;

      if (nameAr.startsWith(nq) || nameEn.startsWith(nq)) {
        score = 3;
      } else if (nameAr.contains(nq) || nameEn.contains(nq)) {
        score = 2;
      } else {
        dist = _editDistanceLimited(nameAr, nq, 2);
        if (dist <= 2) score = 1;
      }

      if (score > 0) {
        final better = (score > bestScore) ||
            (score == bestScore && dist < bestDist) ||
            (score == bestScore &&
                dist == bestDist &&
                st.name.length < (best?.name.length ?? 1 << 30));
        if (better) {
          best = st;
          bestScore = score;
          bestDist = dist;
        }
      }
    }

    if (best != null) {
      await _goToStation(best, openSheet: true);
      setState(() {
        _selectedStation = best;
        _showSuggestions = false;
      });
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لايوجد محطة مطابقة للنص المدخل')),
        );
      }
    }
  }

  void _openSheet(BuildContext context, _Station st) {
    if (_sheetOpen) {
      Navigator.of(context, rootNavigator: true).maybePop();
      _sheetOpen = false;
    }
    _sheetOpen = true;

    Future.microtask(() {
      final realCtx = _scaffoldKey.currentContext ?? context;
      showModalBottomSheet(
        context: realCtx,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (ctx) {
          return DraggableScrollableSheet(
            initialChildSize: 0.43,
            minChildSize: 0.25,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return _StationSheet(
                station: st,
                scrollController: scrollController,
                stationIdMap: _stationIdMap,
              );
            },
          );
        },
      ).whenComplete(() {
        _sheetOpen = false;
      });
    });
  }

  Future<void> _goToStation(_Station st, {bool openSheet = false}) async {
    final targetZoom = _currentZoom < 14.5 ? 14.5 : _currentZoom;
    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(st.position, targetZoom),
    );

    

    if (openSheet && context.mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _openSheet(context, st);
      });
    }
  }

  Future<void> _rebuildMarkersForZoom(double zoom) async {
    final size = _sizeForZoom(zoom);
    final thickness = (size * 0.28).clamp(4.0, 10.0);

    final newMarkers = <Marker>{};
    _markerIdByNameKey.clear();

    for (final st in _stations) {
      final icon = await _stationIconForColors(
        st.colors,
        size: size,
        ringThickness: thickness,
      );

      final linesList = st.lines.toList()..sort();
      final bool multi = linesList.length > 1;
      final linesText = linesList.join(' + ');

      final markerId =
          MarkerId('${st.name}-${st.position.latitude},${st.position.longitude}');
      newMarkers.add(
        Marker(
          markerId: markerId,
          position: st.position,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
        
          onTap: () {
            setState(() {
              _selectedStation = st;
            });
            _openSheet(context, st);
          },
        ),
      );

      _markerIdByNameKey[_normalizeForSearch(st.name)] = markerId;
      if ((st.altName ?? '').isNotEmpty) {
        _markerIdByNameKey[_normalizeForSearch(st.altName!)] = markerId;
      }
    }

    _markers
      ..clear()
      ..addAll(newMarkers);
    if (mounted) setState(() {});
  }

  void _maybeUpdateMarkerIconsForZoom(double zoom) {
    final bucket = (zoom * 2).round() / 2.0;
    if ((bucket - _lastZoomBucket).abs() >= 0.5) {
      _lastZoomBucket = bucket;
      _rebuildMarkersForZoom(zoom);
    }
  }

  double _sizeForZoom(double zoom) {
    final t = ((zoom - _zoomMin) / (_zoomMax - _zoomMin)).clamp(0.0, 1.0);
    return _minSizePx + (_maxSizePx - _minSizePx) * t;
  }

  Future<BitmapDescriptor> _stationIconForColors(
    List<Color> colors, {
    double size = 32,
    double ringThickness = 6,
  }) async {
    final key = '${colors.map((c) => c.value).join(",")}-$size-$ringThickness';
    final cached = _iconCache[key];
    if (cached != null) return cached;

    final icon = await _buildStationIconMulti(
      colors: colors,
      size: size,
      ringThickness: ringThickness,
    );
    _iconCache[key] = icon;
    return icon;
  }

  Future<BitmapDescriptor> _buildStationIconMulti({
    required List<Color> colors,
    double size = 32,
    double ringThickness = 6,
  }) async {
    final dpr = ui.PlatformDispatcher.instance.views.isNotEmpty
        ? ui.PlatformDispatcher.instance.views.first.devicePixelRatio
        : 1.0;

    final int w = (size * dpr).round();
    final int h = (size * dpr).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );

    final center = Offset(w / 2.0, h / 2.0);
    final stroke = ringThickness * dpr;
    final outerRadius = (w / 2.0) - (stroke / 2.0);
    final rect = Rect.fromCircle(center: center, radius: outerRadius);

    final paintSeg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    if (colors.length == 2) {
      paintSeg.color = colors[0];
      canvas.drawArc(rect, _deg2rad(-90), _deg2rad(180), false, paintSeg);
      paintSeg.color = colors[1];
      canvas.drawArc(rect, _deg2rad(90), _deg2rad(180), false, paintSeg);
    } else {
      final n = (colors.isEmpty) ? 1 : colors.length;
      final sweep = 360.0 / n;
      for (int i = 0; i < n; i++) {
        paintSeg.color = colors[i % colors.length];
        final startDeg = -90.0 + sweep * i;
        canvas.drawArc(rect, _deg2rad(startDeg), _deg2rad(sweep), false, paintSeg);
      }
    }

    final innerRadius = outerRadius - (stroke / 2.0);
    final paintCenterWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(center, innerRadius, paintCenterWhite);

    final picture = recorder.endRecording();
    final img = await picture.toImage(w, h);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  double _deg2rad(double d) => d * 3.1415926535897932 / 180.0;

  Future<void> _loadAndBuildMask() async {
    try {
      final raw = await rootBundle.loadString('assets/data/riyadh_boundary.geojson');
      final geo = json.decode(raw);

      final rings = _extractOuterRings(geo);
      if (rings.isEmpty) return;

      final worldRing = <LatLng>[
        const LatLng(-85, -180),
        const LatLng(85, -180),
        const LatLng(85, 180),
        const LatLng(-85, 180),
      ];

      final partsCW = rings.map((r) => _ensureCW(r)).toList();
      final mergedOutlineCW =
          _computeUnionOutlineRings(partsCW, precision: 1e-6);
      final holesCCW = mergedOutlineCW.map((r) => _ensureCCW(r)).toList();

      _polygons
        ..clear()
        ..add(
          Polygon(
            polygonId: const PolygonId('dark_mask'),
            points: _ensureCW(worldRing),
            holes: holesCCW,
            strokeWidth: 0,
            fillColor: _maskFill,
            geodesic: false,
            zIndex: 1,
          ),
        );

      for (int i = 0; i < mergedOutlineCW.length; i++) {
        final outline = mergedOutlineCW[i];

        _polygons.add(
          Polygon(
            polygonId: PolygonId('border_glow_$i'),
            points: outline,
            strokeColor: _borderColor.withOpacity(_glowOpacity),
            strokeWidth: (_borderWidth * _glowMultiplier).toInt(),
            fillColor: Colors.transparent,
            geodesic: false,
            zIndex: 2,
          ),
        );

        _polygons.add(
          Polygon(
            polygonId: PolygonId('border_main_$i'),
            points: outline,
            strokeColor: _borderColor,
            strokeWidth: _borderWidth.toInt(),
            fillColor: Colors.transparent,
            geodesic: false,
            zIndex: 3,
          ),
        );
      }

      setState(() {});
    } catch (e) {
      debugPrint('❌ Failed to load boundary GeoJSON: $e');
    }
  }

  List<List<LatLng>> _extractOuterRings(dynamic geo) {
    final List<List<LatLng>> rings = [];
    final type = geo['type'] as String?;

    if (type == 'FeatureCollection') {
      final features = geo['features'] as List?;
      if (features != null) {
        for (final f in features) {
          _collectGeometryRings(f['geometry'], rings);
        }
      }
    } else if (type == 'Feature') {
      _collectGeometryRings(geo['geometry'], rings);
    } else if (type == 'Polygon' || type == 'MultiPolygon') {
      _collectGeometryRings(geo, rings);
    }
    return rings;
  }

  void _collectGeometryRings(dynamic geom, List<List<LatLng>> out) {
    if (geom == null) return;
    final gType = geom['type'] as String?;
    final coords = geom['coordinates'];

    if (gType == 'Polygon' && coords is List) {
      if (coords.isNotEmpty) out.add(_toLatLngList(coords[0]));
    } else if (gType == 'MultiPolygon' && coords is List) {
      for (final poly in coords) {
        if (poly is List && poly.isNotEmpty) {
          out.add(_toLatLngList(poly[0]));
        }
      }
    }
  }

  List<LatLng> _toLatLngList(dynamic ring) {
    final List<LatLng> res = [];
    if (ring is List) {
      for (final p in ring) {
        if (p is List && p.length >= 2) {
          final lon = (p[0] as num).toDouble();
          final lat = (p[1] as num).toDouble();
          res.add(LatLng(lat, lon));
        }
      }
    }
    return res;
  }

  double _signedArea(List<LatLng> pts) {
    double area = 0;
    for (int i = 0; i < pts.length; i++) {
      final p1 = pts[i];
      final p2 = pts[(i + 1) % pts.length];
      area += (p1.longitude * p2.latitude) - (p2.longitude * p1.latitude);
    }
    return area / 2.0;
  }

  bool _isCCW(List<LatLng> pts) => _signedArea(pts) > 0;
  bool _isCW(List<LatLng> pts) => _signedArea(pts) < 0;
  List<LatLng> _ensureCCW(List<LatLng> pts) =>
      _isCCW(pts) ? pts : pts.reversed.toList();
  List<LatLng> _ensureCW(List<LatLng> pts) =>
      _isCW(pts) ? pts : pts.reversed.toList();

  String _keyPt(LatLng p, {double precision = 1e-6}) {
    double q(double v) => (v / precision).round() * precision;
    final lat = q(p.latitude);
    final lon = q(p.longitude);
    return '$lat,$lon';
  }

  String _edgeKey(LatLng a, LatLng b, {double precision = 1e-6}) {
    final ka = _keyPt(a, precision: precision);
    final kb = _keyPt(b, precision: precision);
    return (ka.compareTo(kb) <= 0) ? '$ka|$kb' : '$kb|$ka';
  }

  List<List<LatLng>> _ringEdges(List<LatLng> ring) {
    final edges = <List<LatLng>>[];
    for (int i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      edges.add([a, b]);
    }
    return edges;
  }

  List<List<LatLng>> _computeUnionOutlineRings(
    List<List<LatLng>> parts, {
    double precision = 1e-6,
  }) {
    final edgeCount = <String, List<LatLng>>{};
    final edgeAB = <String, List<LatLng>>{};

    for (final ring in parts) {
      for (final e in _ringEdges(ring)) {
        final a = e[0], b = e[1];
        final key = _edgeKey(a, b, precision: precision);
        edgeCount[key] = (edgeCount[key] ?? [])..addAll([a, b]);
        edgeAB.putIfAbsent(key, () => [a, b]);
      }
    }

    final boundaryEdges = <String, List<LatLng>>{};
    edgeCount.forEach((key, listAB) {
      if (listAB.length == 2) {
        boundaryEdges[key] = edgeAB[key]!;
      }
    });

    final adj = <String, List<LatLng>>{};
    void addAdj(LatLng u, LatLng v) {
      final ku = _keyPt(u, precision: precision);
      (adj[ku] ??= []).add(v);
    }

    for (final ab in boundaryEdges.values) {
      final a = ab[0], b = ab[1];
      addAdj(a, b);
      addAdj(b, a);
    }

    final visitedEdges = <String, bool>{};
    final outlines = <List<LatLng>>[];

    String dirKey(LatLng u, LatLng v) =>
        '${_keyPt(u, precision: precision)}->${_keyPt(v, precision: precision)}';

    for (final ab in boundaryEdges.values) {
      final startA = ab[0];
      final startB = ab[1];
      final firstDir = dirKey(startA, startB);
      if (visitedEdges[firstDir] == true) continue;

      final path = <LatLng>[];
      LatLng current = startA;
      LatLng prev = startB;

      while (true) {
        path.add(current);
        final kcur = _keyPt(current, precision: precision);
        final neighbors = adj[kcur] ?? const [];

        LatLng? next;
        for (final nb in neighbors) {
          if (_keyPt(nb, precision: precision) !=
              _keyPt(prev, precision: precision)) {
            final keyUndirected = _edgeKey(current, nb, precision: precision);
            if (boundaryEdges.containsKey(keyUndirected)) {
              final dk = dirKey(current, nb);
              if (visitedEdges[dk] == true) continue;
              next = nb;
              visitedEdges[dk] = true;
              break;
            }
          }
        }

        if (next == null && neighbors.isNotEmpty) {
          final nb = neighbors.first;
          final keyUndirected = _edgeKey(current, nb, precision: precision);
          if (boundaryEdges.containsKey(keyUndirected)) {
            final dk = dirKey(current, nb);
            if (visitedEdges[dk] != true) {
              next = nb;
              visitedEdges[dk] = true;
            }
          }
        }

        if (next == null) break;
        prev = current;
        current = next;

        if (_keyPt(current, precision: precision) ==
            _keyPt(path.first, precision: precision)) {
          path.add(current);
          break;
        }
      }

      if (path.length >= 4) {
        outlines.add(_ensureCW(path));
      }
    }

    return outlines;
  }

  Future<void> _loadStations() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/metro_stations.json');
      final data = json.decode(raw);
      final List list = (data is Map && data['results'] is List)
          ? data['results'] as List
          : (data as List);

      final Map<String, Map<String, dynamic>> byName = {};

      for (final s in list) {
        final String nameAr =
            (s['metrostationnamear'] ?? '').toString().trim();
        final String nameEn = (s['metrostationname'] ?? '').toString().trim();
        final String displayName =
            nameAr.isNotEmpty ? nameAr : (nameEn.isNotEmpty ? nameEn : 'محطة');
        final String key = _normalizeForSearch(displayName);

        final String lineFull =
            (s['metrolinenamear'] ?? s['metrolinename'] ?? '').toString();
        final String lineShort = _shortLineName(lineFull);
        final Color color = _colorForLine(lineFull);

        double? lat, lon;
        if (s['geo_point_2d'] is Map) {
          lat = (s['geo_point_2d']['lat'] as num?)?.toDouble();
          lon = (s['geo_point_2d']['lon'] as num?)?.toDouble();
        }
        if ((lat == null || lon == null) && s['geoshape'] is Map) {
          final geom = s['geoshape']['geometry'];
          if (geom is Map &&
              geom['type'] == 'Point' &&
              geom['coordinates'] is List &&
              (geom['coordinates'] as List).length >= 2) {
            final coords = geom['coordinates'] as List;
            lon = (coords[0] as num).toDouble();
            lat = (coords[1] as num).toDouble();
          }
        }
        if (lat == null || lon == null) continue;

        final bucket = byName.putIfAbsent(key, () => {
              'nameArOrEn': displayName,
              'nameEn': nameEn,
              'lats': <double>[],
              'lons': <double>[],
              'lines': <String>{},
              'colors': <int>{},
            });

        (bucket['lats'] as List<double>).add(lat);
        (bucket['lons'] as List<double>).add(lon);
        (bucket['lines'] as Set<String>).add(lineShort);
        (bucket['colors'] as Set<int>).add(color.value);
      }

      _stations
        ..clear()
        ..addAll(byName.values.map((b) {
          final lats = (b['lats'] as List<double>);
          final lons = (b['lons'] as List<double>);
          final avgLat = lats.reduce((a, c) => a + c) / lats.length;
          final avgLon = lons.reduce((a, c) => a + c) / lons.length;

          final lines = (b['lines'] as Set<String>).toList()..sort();
          final colors =
              (b['colors'] as Set<int>).map((v) => Color(v)).toList()
                ..sort((a, b) => a.value.compareTo(b.value));

          return _Station(
            name: b['nameArOrEn'] as String,
            altName: (b['nameEn'] as String?) ?? '',
            position: LatLng(avgLat, avgLon),
            lines: lines.toSet(),
            colors: colors,
          );
        }));

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Failed to load stations JSON: $e');
    }
  }

  String _shortLineName(String line) {
    if (line.contains('الأزرق') || line.toLowerCase().contains('blue')) return 'الأزرق';
    if (line.contains('الأحمر') || line.toLowerCase().contains('red')) return 'الأحمر';
    if (line.contains('البرتقالي') || line.toLowerCase().contains('orange')) return 'البرتقالي';
    if (line.contains('الأخضر') || line.toLowerCase().contains('green')) return 'الأخضر';
    if (line.contains('الأصفر') || line.toLowerCase().contains('yellow')) return 'الأصفر';
    if (line.contains('البنفسجي') || line.toLowerCase().contains('purple')) return 'البنفسجي';
    return line;
  }

  Color _colorForLine(String lineAr) {
    final ln = lineAr.toLowerCase();
    if (lineAr.contains('الأزرق') || ln.contains('blue')) return _blueHex;
    if (lineAr.contains('الأحمر') || ln.contains('red')) return _redHex;
    if (lineAr.contains('البرتقالي') || ln.contains('orange')) return _orangeHex;
    if (lineAr.contains('الأخضر') || ln.contains('green')) return _greenHex;
    if (lineAr.contains('الأصفر') || ln.contains('yellow')) return _yellowHex;
    if (lineAr.contains('البنفسجي') || ln.contains('purple')) return _purpleHex;
    return Colors.grey;
  }

  String _normalizeForSearch(String s) => norm(s);

  int _editDistanceLimited(String a, String b, int limit) {
    final n = a.length, m = b.length;
    if ((n - m).abs() > limit) return 999;
    List<int> prev = List<int>.generate(m + 1, (j) => j);
    for (int i = 1; i <= n; i++) {
      List<int> cur = List<int>.filled(m + 1, 0);
      cur[0] = i;
      int rowMin = cur[0];
      for (int j = 1; j <= m; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = [
          prev[j] + 1,
          cur[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce((v, e) => v < e ? v : e);
        if (cur[j] < rowMin) rowMin = cur[j];
      }
      if (rowMin > limit) return 999;
      prev = cur;
    }
    return prev[m];
  }
}

class _StationSheet extends StatelessWidget {
  final _Station station;
  final ScrollController scrollController;
  final Map<String, String> stationIdMap;

  const _StationSheet({
    required this.station,
    required this.scrollController,
    required this.stationIdMap,
  });

  /// ربط ذكي للـ station_id سواء كانت الخريطة ID->Name أو Name->ID
  String? _resolveStationId({
    required String stationNameAr,
    required String? stationNameEn,
    required Map<String, String> map,
  }) {
    final nAr = norm(stationNameAr);
    final nEn = norm(stationNameEn ?? '');

    // تخمين شكل الخريطة من أول عنصر
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
        // الخريطة ID -> Name
        if (nv == nAr || nv == nEn || nv.contains(nAr) || nv.contains(nEn) || nAr.contains(nv) || nEn.contains(nv)) {
          return k;
        }
      } else {
        // الخريطة Name -> ID
        if (nk == nAr || nk == nEn || nk.contains(nAr) || nk.contains(nEn) || nAr.contains(nk) || nEn.contains(nk)) {
          return v;
        }
      }
    }

    // محاولة أضعف
    for (final e in map.entries) {
      final nk = norm(e.key);
      final nv = norm(e.value);
      if (nk.isNotEmpty && (nAr.contains(nk) || nEn.contains(nk))) return e.value;
      if (nv.isNotEmpty && (nAr.contains(nv) || nEn.contains(nv))) return e.key;
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

    // نحسم station_id
    final stationId = _resolveStationId(
      stationNameAr: station.name,
      stationNameEn: station.altName,
      map: stationIdMap,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                station.name,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
           
            const SizedBox(height: 16),

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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int i = 0; i < station.colors.length; i++)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: station.colors[i],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${colorToLineNumber[station.colors[i]] ?? (i + 1)}',
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

            _CrowdStatusWidget(stationId: stationId),
            const SizedBox(height: 24),

            const Divider(thickness: 1.1),
            const SizedBox(height: 10),
            const Text(
              'الجدول الزمني',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            if (stationId != null)
              _ScheduleWidget(
                stationId: stationId,
                stationName: station.name,
                colors: station.colors,
                colorToLineNumber: colorToLineNumber,
                stationIdMap: stationIdMap,
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
      ),
    );
  }
}

class _CrowdStatusWidget extends StatelessWidget {
  final String? stationId;

  const _CrowdStatusWidget({required this.stationId});

  @override
  Widget build(BuildContext context) {
   final now = DateTime.now();
    final rnd = Random(now.millisecondsSinceEpoch);
    final currentIdx = rnd.nextInt(3);
    final futureIdx = (currentIdx + 1) % 3;
    const labels = ['سلس', 'متوسط', 'مزدحم'];
    const colors = [Colors.green, Colors.orange, Colors.red];

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
            color: colors[currentIdx],
            label: labels[currentIdx],
          ),
          const SizedBox(height: 12),
          _crowdRow(
            title: 'المتوقعة بعد 30 دقيقة:',
            color: colors[futureIdx],
            label: labels[futureIdx],
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleWidget extends StatelessWidget {
  final String stationName;
  final String stationId;
  final List<Color> colors;
  final Map<Color, int> colorToLineNumber;
  final Map<String, String> stationIdMap;

  const _ScheduleWidget({
    required this.stationName,
    required this.stationId,
    required this.colors,
    required this.colorToLineNumber,
    required this.stationIdMap,
  });

  // ========= وجهة الرحلة (Destination) =========

  // كاش: tripId -> end_code
  static final Map<String, String?> _tripEndCache = {};

  // أسماء محتملة لحقل الوجهة داخل وثيقة الرحلة
  static const List<String> _tripEndCandidates = [
    'end_station_code', 'endStationCode',
    'end_station', 'destination', 'dest', 'dest_code', 'end_code',
  ];

  // اقرأ الوجهة من وثيقة الرحلة الأم
  Future<String?> _getTripEndCodeFromTrip(DocumentReference tripRef) async {
    final tripId = tripRef.id;
    if (_tripEndCache.containsKey(tripId)) return _tripEndCache[tripId];

    final snap = await tripRef.get();
    final trip = snap.data() as Map<String, dynamic>?;

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

  // حوّل كود الوجهة لاسم عربي من station_id_map (يدعم سلاسل متعددة مفصولة /)
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
        final vv = v.trim().toUpperCase();
        if (vv == cu || vv.contains(cu) || cu.contains(vv)) {
          // رجّع أول نص عربي موجود
          for (final p in variants) {
            if (RegExp(r'[\u0600-\u06FF]').hasMatch(p)) {
              return p.trim();
            }
          }
          return variants.first;
        }
      }
    }
    return null;
  }

  Widget _scheduleRow({
    required int i,
    required int total,
    required String timeStr,
    required int lineNumber,
    required Color color,
    required String destName,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: i == total - 1 ? 0 : 1,
          ),
        ),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Icon(Icons.chevron_left, color: Colors.grey[600], size: 22),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            destName,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '$lineNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
  bool _isTerminalHere(String? destName) {
    if (destName == null || destName.trim().isEmpty) return false;
    final nd = norm(destName);      // 👈 يستخدم نفس الدالة الموجودة فوق
    final ns = norm(stationName);   // 👈 اسم المحطة الحالية
    return nd == ns;
  }


  @override
  Widget build(BuildContext context) {
   
    final DateTime now = DateTime.now();
    final DateTime end = now.add(const Duration(minutes: 30));

    final stream = FirebaseFirestore.instance
        .collectionGroup('stops')
        .where('station_id', isEqualTo: stationId)
        .where('arrival_timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('arrival_timestamp', isLessThan: Timestamp.fromDate(end))
        .orderBy('arrival_timestamp')
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _boxed(
            Text(
              'خطأ في تحميل البيانات: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _boxed(const Center(child: CircularProgressIndicator()));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _boxed(const Text(
            'لا توجد رحلات خلال الساعة القادمة',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ));
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: List.generate(docs.length, (i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              final lineId = (data['line_id'] as String?) ?? '';
              final Color color = _getColorForLine(lineId);
              final int lineNumber = colorToLineNumber[color] ?? 0;

              String timeStr = '';
              final ts = data['arrival_timestamp'];
              if (data['arrival_time'] is String &&
                  (data['arrival_time'] as String).isNotEmpty) {
                timeStr = _formatArrivalTime(data['arrival_time'] as String);
              } else if (ts is Timestamp) {
                timeStr = _formatFromTimestamp(ts);
              }

              // 1) حاول نقرأ الوجهة مباشرة من stop
              String? endCode = (data['end_station_code'] as String?)?.trim();
              if (endCode == null || endCode.isEmpty) {
                for (final k in ['end_station','endStation','destination','dest','dest_code','end_code']) {
                  final v = (data[k] as String?)?.trim();
                  if (v != null && v.isNotEmpty) { endCode = v; break; }
                }
              }

              // 2) إن ما وُجدت، نجيبها من وثيقة الرحلة الأم trips/{tripId}
              final tripRef = doc.reference.parent.parent;

                 if (endCode != null || tripRef == null) {
                  final destName = _resolveEndName(endCode) ?? 'وجهة غير معروفة';

                  // 👇 إذا الوجهة هي نفس المحطة الحالية لا نعرض السطر
                  if (_isTerminalHere(destName)) {
                    return const SizedBox.shrink();
                  }

                  return _scheduleRow(
                    i: i, total: docs.length, timeStr: timeStr,
                    lineNumber: lineNumber, color: color, destName: destName,
                  );
                }
                else {
                return FutureBuilder<String?>(
                  future: _getTripEndCodeFromTrip(tripRef),
                  builder: (context, snap) {
                    final code = snap.data;
                    final destName = _resolveEndName(code) ?? 'وجهة غير معروفة';

                    // 👇 برضه هنا: إذا الوجهة هي نفس المحطة لا نعرض الصف
                    if (_isTerminalHere(destName)) {
                      return const SizedBox.shrink();
                    }

                    return _scheduleRow(
                      i: i, total: docs.length, timeStr: timeStr,
                      lineNumber: lineNumber, color: color, destName: destName,
                    );
                  },
                );

              }
            }),
          ),
        );
      },
    );
  }

  Widget _boxed(Widget child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );

  Color _getColorForLine(String lineId) {
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

  // "09:32AM"
  String _formatArrivalTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        int hour24 = int.parse(parts[0]);
        final minute = parts[1].padLeft(2, '0');

        final isPM = hour24 >= 12;
        int hour12 = hour24 % 12;
        if (hour12 == 0) hour12 = 12;

        final hh = hour12.toString().padLeft(2, '0');
        final suffix = isPM ? 'PM' : 'AM';
        return '$hh:$minute$suffix';
      }
    } catch (_) {}
    return time;
  }

  String _formatFromTimestamp(Timestamp ts) {
    final dt = ts.toDate(); // وقت محلي
    int hour24 = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');

    final isPM = hour24 >= 12;
    int hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;

    final hh = hour12.toString().padLeft(2, '0');
    final suffix = isPM ? 'PM' : 'AM';
    return '$hh:$minute$suffix';
  }
}

class _Station {
  final String name;
  final String? altName;
  final LatLng position;
  final Set<String> lines;
  final List<Color> colors;

  const _Station({
    required this.name,
    required this.position,
    required this.lines,
    required this.colors,
    this.altName,
  });
}
