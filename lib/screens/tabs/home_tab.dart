import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const LatLng _riyadhCenter = LatLng(24.7136, 46.6753);
  GoogleMapController? _map;

  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};

  // سواد خارج الحدود (شفاف)
  final Color _maskFill = Colors.black.withOpacity(0.75);

  // حدود + توهج
  final Color _borderColor = const Color(0xFF984C9D);
  final double _borderWidth = 2;
  final double _glowMultiplier = 8;
  final double _glowOpacity = 0.25;

  // كاش للأيقونات
  final Map<String, BitmapDescriptor> _iconCache = {};

  // الحجم حسب الزوم
  double _currentZoom = 14;
  double _lastZoomBucket = -999;
  static const double _minSizePx = 18;
  static const double _maxSizePx = 44;
  static const double _zoomMin = 8;
  static const double _zoomMax = 16;

  // بيانات المحطات
  final List<_Station> _stations = [];

  // ===== البحث اليدوي مع لوحة اقتراحات =====
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final List<_Station> _suggestions = [];
  bool _showSuggestions = false;

  // ربط الاسم بالماركر
  final Map<String, MarkerId> _markerIdByNameKey = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _riyadhCenter, zoom: _currentZoom),
          onMapCreated: (c) async {
            _map = c;
            await _loadAndBuildMask();
            await _loadStations();
            await _rebuildMarkersForZoom(_currentZoom);
          },
          onCameraMove: (pos) {
            _currentZoom = pos.zoom;
            _maybeUpdateMarkerIconsForZoom(pos.zoom);
          },
          onCameraIdle: () => _maybeUpdateMarkerIconsForZoom(_currentZoom),
          polygons: _polygons,
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: false,
        ),

        // ===== شريط البحث + لوحة الاقتراحات داخل الـStack =====
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
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن اسم المحطة… ',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),

                  // لوحة الاقتراحات
                  if (_showSuggestions && _suggestions.isNotEmpty)
                    const SizedBox(height: 8),
                  if (_showSuggestions && _suggestions.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final st = _suggestions[i];
                            final subtitle = st.lines.isNotEmpty
                                ? st.lines.join(' + ')
                                : (st.altName ?? '');
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on),
                              title: Text(st.name),
                              subtitle: subtitle.isEmpty
                                  ? null
                                  : Text(subtitle, style: const TextStyle(fontSize: 12)),
                              onTap: () async {
                                setState(() {
                                  _searchCtrl.text = st.name;
                                  _showSuggestions = false;
                                });
                                _searchFocus.unfocus();
                                await _goToStation(st);
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
    );
  }

  // ============== تحديث الاقتراحات أثناء الكتابة ==============
  void _onQueryChanged(String qRaw) {
    final q = _normalizeForSearch(qRaw);
    if (q.isEmpty) {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
      return;
    }

    // نفس منطق الترتيب: يبدأ بـ > يحتوي > تشابه بسيط
    final scored = <({ _Station st, int score, int distance })>[];
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

  // ===================== القناع والحدود =====================

  Future<void> _loadAndBuildMask() async {
    try {
      final raw = await rootBundle.loadString('assets/data/riyadh_boundary.geojson');
      final geo = json.decode(raw);

      final rings = _extractOuterRings(geo);
      if (rings.isEmpty) return;

      final worldRing = <LatLng>[
        const LatLng(-85, -180),
        const LatLng( 85, -180),
        const LatLng( 85,  180),
        const LatLng(-85,  180),
      ];

      final partsCW = rings.map((r) => _ensureCW(r)).toList();
      final mergedOutlineCW = _computeUnionOutlineRings(partsCW, precision: 1e-6);
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

  // ===================== تحميل + دمج محطات المترو بالاسم =====================

  String _normalizeForSearch(String s) {
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

  Future<void> _loadStations() async {
    try {
      final raw = await rootBundle.loadString('assets/data/metro_stations.json');
      final data = json.decode(raw);
      final List list =
          (data is Map && data['results'] is List) ? data['results'] as List : (data as List);

      final Map<String, Map<String, dynamic>> byName = {};

      for (final s in list) {
        final String nameAr = (s['metrostationnamear'] ?? '').toString().trim();
        final String nameEn = (s['metrostationname'] ?? '').toString().trim();
        final String displayName = nameAr.isNotEmpty ? nameAr : (nameEn.isNotEmpty ? nameEn : 'محطة');
        final String key = _normalizeForSearch(displayName);

        final String lineFull = (s['metrolinenamear'] ?? s['metrolinename'] ?? '').toString();
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
          final colors = (b['colors'] as Set<int>).map((v) => Color(v)).toList()
            ..sort((a, b) => a.value.compareTo(b.value));

          return _Station(
            name: b['nameArOrEn'] as String,
            altName: (b['nameEn'] as String?) ?? '',
            position: LatLng(avgLat, avgLon),
            lines: lines.toSet(),
            colors: colors,
          );
        }));

      setState(() {}); // يحدّث الواجهة بعد تحميل المحطات
    } catch (e) {
      debugPrint('❌ Failed to load stations JSON: $e');
    }
  }

  // إعادة بناء الماركرات وفق الزوم
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

      final markerId = MarkerId('${st.name}-${st.position.latitude},${st.position.longitude}');
      newMarkers.add(
        Marker(
          markerId: markerId,
          position: st.position,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: multi ? '${st.name} — تقاطع' : st.name,
            snippet: multi ? 'على ${linesList.length} خطوط: $linesText' : linesText,
          ),
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

  // الذهاب للمحطة
  Future<void> _goToStation(_Station st) async {
    final targetZoom = _currentZoom < 14.5 ? 14.5 : _currentZoom;
    await _map?.animateCamera(CameraUpdate.newLatLngZoom(st.position, targetZoom));
    final mk = _markerIdByNameKey[_normalizeForSearch(st.name)] ??
        ((st.altName ?? '').isNotEmpty ? _markerIdByNameKey[_normalizeForSearch(st.altName!)] : null);
    if (mk != null) {
      await Future.delayed(const Duration(milliseconds: 200));
      _map?.showMarkerInfoWindow(mk);
    }
  }

  // Enter = اختيار أفضل نتيجة
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
            (score == bestScore && dist == bestDist && st.name.length < (best?.name.length ?? 1 << 30));
        if (better) {
          best = st;
          bestScore = score;
          bestDist = dist;
        }
      }
    }

    if (best != null) {
      setState(() => _showSuggestions = false);
      await _goToStation(best!);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ما لقيت محطة مطابقة للنص المدخل')),
        );
      }
    }
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

  // ===================== أيقونات الحلقات =====================
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
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

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

    // مركز أبيض
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

  // ===================== GeoJSON helpers =====================
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

  // ===================== اتجاه الحلقات =====================
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
  bool _isCW (List<LatLng> pts) => _signedArea(pts) < 0;
  List<LatLng> _ensureCCW(List<LatLng> pts) => _isCCW(pts) ? pts : pts.reversed.toList();
  List<LatLng> _ensureCW (List<LatLng> pts) => _isCW(pts)  ? pts : pts.reversed.toList();

  // ===================== إذابة الحدود =====================
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
    final edgeAB   = <String, List<LatLng>>{};

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
          if (_keyPt(nb, precision: precision) != _keyPt(prev, precision: precision)) {
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

        if (_keyPt(current, precision: precision) == _keyPt(path.first, precision: precision)) {
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

  // ===================== نص/لون =====================

  String _shortLineName(String line) {
    if (line.contains('الأزرق') || line.toLowerCase().contains('blue')) return 'الأزرق';
    if (line.contains('الأحمر') || line.toLowerCase().contains('red')) return 'الأحمر';
    if (line.contains('البرتقالي') || line.toLowerCase().contains('orange')) return 'البرتقالي';
    if (line.contains('الأخضر') || line.toLowerCase().contains('green')) return 'الأخضر';
    if (line.contains('الأصفر') || line.toLowerCase().contains('yellow')) return 'الأصفر';
    if (line.contains('البنفسجي') || line.toLowerCase().contains('purple')) return 'البنفسجي';
    return line;
  }

  // ألوان ثابتة (منك)
  static const Color _blueHex   = Color(0xFF00ADE5);
  static const Color _greenHex  = Color(0xFF43B649);
  static const Color _purpleHex = Color(0xFF984C9D);
  static const Color _redHex    = Color(0xFFD12027);
  static const Color _orangeHex = Color(0xFFF68D39);
  static const Color _yellowHex = Color(0xFFFFC107); // غطّيت الأصفر التقريبي

  Color _colorForLine(String lineAr) {
    final ln = lineAr.toLowerCase();
    if (lineAr.contains('الأزرق')    || ln.contains('blue'))   return _blueHex;
    if (lineAr.contains('الأحمر')    || ln.contains('red'))    return _redHex;
    if (lineAr.contains('البرتقالي') || ln.contains('orange')) return _orangeHex;
    if (lineAr.contains('الأخضر')    || ln.contains('green'))  return _greenHex;
    if (lineAr.contains('الأصفر')    || ln.contains('yellow')) return _yellowHex;
    if (lineAr.contains('البنفسجي')  || ln.contains('purple')) return _purpleHex;
    return Colors.grey;
  }
}

// نموذج محطة
class _Station {
  final String name;      // اسم العرض (عربي أو إنجليزي)
  final String? altName;  // اسم بديل
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
