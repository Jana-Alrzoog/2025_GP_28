import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import 'package:Masar_application_1/services/location_service.dart';

// ✅ inline schedule widget inside chat
import 'package:Masar_application_1/widgets/chat_schedule_inline.dart';

// ✅ NEW: route card widget
import 'package:Masar_application_1/widgets/route_card.dart';

class AssistantTab extends StatefulWidget {
  const AssistantTab({super.key});

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<AssistantTab> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];

  late final String _baseUrl = _detectBaseUrl();

  late String _sessionId;
  String? _passengerId;

  List<_OptionItem> _lastOptions = [];
  bool _hasOptions = false;

  bool _loadingMenu = false;
  bool _sessionReady = false;

  final ImagePicker _picker = ImagePicker();
  bool _uploadingImage = false;

  bool _sending = false;

  // ✅ Station map (S1..S6 -> variants)
  final Map<String, String> _stationIdMap = const {
    "S1": "المركز المالي/KAFD",
    "S2": "stc/STC",
    "S3": "قصر الحكم/Qasr Al Hokm/Qasr Al-Hukm/QASR",
    "S4": "المتحف الوطني/National Museum",
    "S5": "المطار صالة 1-2/Terminal 1-2/AIRP_T12",
    "S6": "المدينة الصناعية الأولى/First Industrial City",
  };

  // Detect base URL for backend (port 8000)
  String _detectBaseUrl() {
    if (kIsWeb) return "http://localhost:8000";
    return "http://10.0.2.2:8000";
  }

  // ----------------------------
  // Station ID resolver (IMPORTANT)
  // ----------------------------
  String _norm(String s) {
    final t = s.trim().toLowerCase();
    return t
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// يحوّل أي مدخل (S1 / KAFD / "المركز المالي") إلى station_id الحقيقي S1..S6
  String? _resolveStationIdFromAny(String? input, {String? stationName}) {
    final raw = (input ?? '').trim();
    final name = (stationName ?? '').trim();

    if (raw.isEmpty && name.isEmpty) return null;

    // إذا أصلاً S1..S6
    if (raw.isNotEmpty && RegExp(r'^S\d+$', caseSensitive: false).hasMatch(raw)) {
      return raw.toUpperCase();
    }

    final nRaw = _norm(raw);
    final nName = _norm(name);

    for (final e in _stationIdMap.entries) {
      final stationId = e.key; // S1..S6
      final variants = e.value
          .split('/')
          .map((x) => x.trim())
          .where((x) => x.isNotEmpty)
          .toList();

      for (final v in variants) {
        final nv = _norm(v);

        // مساواة
        if (nv == nRaw && nRaw.isNotEmpty) return stationId;
        if (nv == nName && nName.isNotEmpty) return stationId;

        // contains
        if (nRaw.isNotEmpty && (nv.contains(nRaw) || nRaw.contains(nv))) return stationId;
        if (nName.isNotEmpty && (nv.contains(nName) || nName.contains(nv))) return stationId;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initSession();
      if (!mounted) return;
      await _loadMenuOnOpen();
    });
  }

  Future<void> _initSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _sessionReady = false;
        _passengerId = null;
      });
      return;
    }

    _passengerId = user.uid;

    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(1 << 30);
    _sessionId = "${user.uid}_$now$rand";

    setState(() {
      _sessionReady = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<String> _uploadImageToBackend(XFile file, {String? ticketId}) async {
    final uri = Uri.parse("$_baseUrl/lost-found/upload-image");
    final req = http.MultipartRequest("POST", uri);

    req.fields["passenger_id"] = _passengerId!;
    req.fields["session_id"] = _sessionId;

    if (ticketId != null && ticketId.isNotEmpty) {
      req.fields["ticket_id"] = ticketId;
    }

    req.files.add(await http.MultipartFile.fromPath(
      "file",
      file.path,
      filename: file.name,
    ));

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      throw Exception("Upload failed: ${res.statusCode} ${res.body}");
    }

    final data = jsonDecode(res.body);
    return (data["photo_url"] ?? "").toString();
  }

  // ----------------------------
  // Backend call
  // ----------------------------
  Future<_BackendReply> _askBackend(String text) async {
    final uri = Uri.parse("$_baseUrl/ask");

    if (!_sessionReady || _passengerId == null) {
      return _BackendReply(
        answer: "لم يتم تسجيل الدخول. سجّل دخولك ثم افتح المساعد مرة ثانية.",
        type: "text",
        options: const [],
        raw: const {},
      );
    }

    double? lat;
    double? lon;

    final bool useLocation = await LocationService.getUseLocation();
    final bool asked = await LocationService.getHasAsked();

    if (useLocation) {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!asked) {
        await LocationService.requestPermission();
        await LocationService.setHasAsked(true);
      }

      final LocationPermission currentPerm = await Geolocator.checkPermission();

      if (!serviceEnabled ||
          currentPerm == LocationPermission.denied ||
          currentPerm == LocationPermission.deniedForever) {
        return _BackendReply(
          answer: "تعذر الحصول على موقعك حالياً. تأكد من تفعيل GPS ومنح إذن الموقع للتطبيق.",
          type: "text",
          options: const [],
          raw: const {},
        );
      }

      final Position? pos = await LocationService.getCurrentPosition();
      lat = pos?.latitude;
      lon = pos?.longitude;

      if (lat == null || lon == null) {
        return _BackendReply(
          answer: "تعذر الحصول على موقعك حالياً. تأكد من تفعيل GPS ومنح إذن الموقع للتطبيق.",
          type: "text",
          options: const [],
          raw: const {},
        );
      }
    }

    final body = {
      "question": text,
      "session_id": _sessionId,
      "passenger_id": _passengerId,
      "lat": lat,
      "lon": lon,
    };

    try {
      final res = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        return _BackendReply(
          answer: "Server error: ${res.statusCode}\n${res.body}",
          type: "error",
          options: const [],
          raw: const {},
        );
      }

      final data = jsonDecode(res.body);

      // ✅ DEBUG مهم جدًا (خلّيه مؤقتًا)
      // ignore: avoid_print
      print("BACKEND RAW => $data");

      var answer = (data["answer"] ?? "").toString().trim();
      final type = (data["type"] ?? "text").toString();

      // Friendly Firestore index error
      if (answer.contains("FailedPrecondition") && answer.contains("requires an index")) {
        answer =
            "فيه إعداد ناقص في Firebase (Index) عشان نجيب مواعيد الرحلات.\n"
            "افتحي رابط (create index) اللي ظهر لك مرة وحدة وسوي Create.\n"
            "بعدها المواعيد بتشتغل طبيعي ✅";
      }

      // Parse options from JSON if present
      final options = <_OptionItem>[];
      final rawOpts = data["options"];
      if (rawOpts is List) {
        for (final it in rawOpts) {
          if (it is Map) {
            final id = (it["id"] ?? "").toString().trim();
            final label = (it["label"] ?? "").toString().trim();
            if (id.isNotEmpty && label.isNotEmpty) {
              options.add(_OptionItem(id: id, label: label));
            }
          }
        }
      }

      return _BackendReply(
        answer: answer,
        type: type,
        options: options,
        raw: (data is Map<String, dynamic>) ? data : const {},
      );
    } catch (_) {
      return _BackendReply(
        answer: "Failed to connect to server.\n"
            "Check:\n"
            "- backend running on port 8000\n"
            "- baseUrl = $_baseUrl\n"
            "- Using Android emulator => 10.0.2.2\n",
        type: "error",
        options: const [],
        raw: const {},
      );
    }
  }

  // ----------------------------
  // Open -> load menu
  // ----------------------------
  Future<void> _loadMenuOnOpen() async {
    if (_loadingMenu) return;
    _loadingMenu = true;

    setState(() {
      _msgs.clear();
      _hasOptions = false;
      _lastOptions = [];
    });

    _setTyping(true);
    _scrollDown();

    final reply = await _askBackend("MENU");
    if (!mounted) return;

    _setTyping(false);

    final fallback = _parseBotReply(reply.answer);
    final effectiveText = fallback.cleanedText.isEmpty
        ? (reply.answer.isEmpty ? "Empty reply" : reply.answer)
        : fallback.cleanedText;

    setState(() {
      _msgs.add(_Msg(text: effectiveText, fromBot: true));
    });

    final effectiveOptions = reply.options.isNotEmpty
        ? reply.options
        : fallback.options.map((o) => _OptionItem(id: o.index.toString(), label: o.label)).toList();

    _applyOptions(effectiveOptions);
    _scrollDown();
    _loadingMenu = false;
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (!mounted) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 260,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  _ParsedBotReply _parseBotReply(String botText) {
    final lines = botText.split('\n');
    final options = <_OptionItemIndexOnly>[];
    final keptLines = <String>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final matchEmoji = RegExp(r'^(\d+)️⃣\s+(.+)$').firstMatch(line);
      if (matchEmoji != null) {
        options.add(_OptionItemIndexOnly(
          index: int.parse(matchEmoji.group(1)!),
          label: matchEmoji.group(2)!.trim(),
        ));
        continue;
      }

      final matchDash = RegExp(r'^(\d+)\s*[-–]\s*(.+)$').firstMatch(line);
      if (matchDash != null) {
        options.add(_OptionItemIndexOnly(
          index: int.parse(matchDash.group(1)!),
          label: matchDash.group(2)!.trim(),
        ));
        continue;
      }

      keptLines.add(line);
    }

    final cleaned = keptLines.join('\n').trim();
    return _ParsedBotReply(cleanedText: cleaned, options: options);
  }

  void _applyOptions(List<_OptionItem> options) {
    setState(() {
      _lastOptions = options;
      _hasOptions = options.isNotEmpty;
    });
  }

  void _setTyping(bool on) {
    setState(() {
      if (on) {
        _msgs.add(_Msg(text: "...", fromBot: true, isTyping: true));
      } else {
        _msgs.removeWhere((m) => m.isTyping);
      }
    });
  }

  void _applyOptionsOrFallback(List<_OptionItem> opts) {
    if (opts.isEmpty) {
      _applyOptions([_OptionItem(id: "MENU", label: "رجوع للقائمة")]);
    } else {
      _applyOptions(opts);
    }
  }

  // ----------------------------
  // Send text
  // ----------------------------
  Future<void> _send([String? forcedText]) async {
    if (_sending) return;

    final txt = (forcedText ?? _controller.text).trim();
    if (txt.isEmpty) return;

    setState(() {
      _sending = true;
      _msgs.add(_Msg(text: txt, fromBot: false));
      if (forcedText == null) _controller.clear();
      _hasOptions = false;
      _lastOptions = [];
    });

    _scrollDown();
    _setTyping(true);
    _scrollDown();

    final reply = await _askBackend(txt);
    if (!mounted) return;

    _setTyping(false);

    // ✅ route card
    if (reply.type == "route_card") {
      final route = (reply.raw["route"] is Map)
          ? (reply.raw["route"] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      setState(() {
        _msgs.add(_Msg(
          fromBot: true,
          text: reply.answer.isEmpty ? "هذا أفضل مسار لك:" : reply.answer,
          route: route,
        ));
        _sending = false;
      });

      _applyOptionsOrFallback(reply.options);
      _scrollDown();
      return;
    }

    // ✅ schedule inline
    if (reply.type == "schedule_inline") {
      final rawStation = (reply.raw["station_id"] ?? reply.raw["station_code"] ?? "").toString().trim();
      final stName = (reply.raw["station_name"] ?? "").toString().trim();

      final resolvedId = _resolveStationIdFromAny(rawStation, stationName: stName);

      setState(() {
        _msgs.add(_Msg(
          fromBot: true,
          text: reply.answer.isEmpty ? "تمام، هذي أقرب الرحلات:" : reply.answer,
          isScheduleInline: true,
          scheduleStationId: resolvedId,
          scheduleStationName: stName,
        ));
        _sending = false;
      });

      _applyOptionsOrFallback(reply.options);
      _scrollDown();
      return;
    }

    final fallback = _parseBotReply(reply.answer);
    final effectiveText = fallback.cleanedText.isEmpty
        ? (reply.answer.isEmpty ? "Empty reply" : reply.answer)
        : fallback.cleanedText;

    setState(() {
      _msgs.add(_Msg(text: effectiveText, fromBot: true));
      _sending = false;
    });

    final effectiveOptions = reply.options.isNotEmpty
        ? reply.options
        : fallback.options.map((o) => _OptionItem(id: o.index.toString(), label: o.label)).toList();

    _applyOptions(effectiveOptions);
    _scrollDown();
  }

  // ----------------------------
  // Send option payload to backend
  // ----------------------------
  Future<void> _sendOption(_OptionItem opt) async {
    if (_sending) return;

    final display = opt.label.trim();
    final backend = opt.id.trim();

    setState(() {
      _sending = true;
      _msgs.add(_Msg(text: display, fromBot: false));
      _hasOptions = false;
      _lastOptions = [];
    });

    _scrollDown();
    _setTyping(true);
    _scrollDown();

    final reply = await _askBackend(backend);
    if (!mounted) return;

    _setTyping(false);

    // ✅ route card
    if (reply.type == "route_card") {
      final route = (reply.raw["route"] is Map)
          ? (reply.raw["route"] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      setState(() {
        _msgs.add(_Msg(
          fromBot: true,
          text: reply.answer.isEmpty ? "هذا أفضل مسار لك:" : reply.answer,
          route: route,
        ));
        _sending = false;
      });

      _applyOptionsOrFallback(reply.options);
      _scrollDown();
      return;
    }

    // ✅ schedule inline
    if (reply.type == "schedule_inline") {
      final rawStation = (reply.raw["station_id"] ?? reply.raw["station_code"] ?? "").toString().trim();
      final stName = (reply.raw["station_name"] ?? "").toString().trim();

      final resolvedId = _resolveStationIdFromAny(rawStation, stationName: stName);

      setState(() {
        _msgs.add(_Msg(
          fromBot: true,
          text: reply.answer.isEmpty ? "تمام، هذي أقرب الرحلات:" : reply.answer,
          isScheduleInline: true,
          scheduleStationId: resolvedId,
          scheduleStationName: stName,
        ));
        _sending = false;
      });

      _applyOptionsOrFallback(reply.options);
      _scrollDown();
      return;
    }

    final fallback = _parseBotReply(reply.answer);
    final effectiveText = fallback.cleanedText.isEmpty
        ? (reply.answer.isEmpty ? "Empty reply" : reply.answer)
        : fallback.cleanedText;

    setState(() {
      _msgs.add(_Msg(text: effectiveText, fromBot: true));
      _sending = false;
    });

    final effectiveOptions = reply.options.isNotEmpty
        ? reply.options
        : fallback.options.map((o) => _OptionItem(id: o.index.toString(), label: o.label)).toList();

    _applyOptions(effectiveOptions);
    _scrollDown();
  }

  // ----------------------------
  // Image attach
  // ----------------------------
  Future<void> _attachAndSendImage() async {
    if (_uploadingImage || _sending) return;

    if (!_sessionReady || _passengerId == null) {
      setState(() {
        _msgs.add(_Msg(text: "لم يتم تسجيل الدخول.", fromBot: true));
      });
      return;
    }

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final Uint8List bytes = await picked.readAsBytes();

      setState(() {
        _uploadingImage = true;
        _sending = true;
        _hasOptions = false;
        _lastOptions = [];
        _msgs.add(_Msg(fromBot: false, imageBytes: bytes));
      });

      _scrollDown();
      _setTyping(true);
      _scrollDown();

      await _uploadImageToBackend(picked);

      final reply = await _askBackend("تم");
      if (!mounted) return;

      _setTyping(false);

      // ✅ route card
      if (reply.type == "route_card") {
        final route = (reply.raw["route"] is Map)
            ? (reply.raw["route"] as Map).cast<String, dynamic>()
            : <String, dynamic>{};

        setState(() {
          _uploadingImage = false;
          _sending = false;
          _msgs.add(_Msg(
            fromBot: true,
            text: reply.answer.isEmpty ? "هذا أفضل مسار لك:" : reply.answer,
            route: route,
          ));
        });

        _applyOptionsOrFallback(reply.options);
        _scrollDown();
        return;
      }

      if (reply.type == "schedule_inline") {
        final rawStation = (reply.raw["station_id"] ?? reply.raw["station_code"] ?? "").toString().trim();
        final stName = (reply.raw["station_name"] ?? "").toString().trim();
        final resolvedId = _resolveStationIdFromAny(rawStation, stationName: stName);

        setState(() {
          _uploadingImage = false;
          _sending = false;
          _msgs.add(_Msg(
            fromBot: true,
            text: reply.answer.isEmpty ? "تمام، هذي أقرب الرحلات:" : reply.answer,
            isScheduleInline: true,
            scheduleStationId: resolvedId,
            scheduleStationName: stName,
          ));
        });

        _applyOptionsOrFallback(reply.options);
        _scrollDown();
        return;
      }

      final fallback = _parseBotReply(reply.answer);
      final effectiveText = fallback.cleanedText.isEmpty
          ? (reply.answer.isEmpty ? "Empty reply" : reply.answer)
          : fallback.cleanedText;

      setState(() {
        _uploadingImage = false;
        _sending = false;
        _msgs.add(_Msg(text: effectiveText, fromBot: true));
      });

      final effectiveOptions = reply.options.isNotEmpty
          ? reply.options
          : fallback.options.map((o) => _OptionItem(id: o.index.toString(), label: o.label)).toList();

      _applyOptions(effectiveOptions);
      _scrollDown();
    } catch (_) {
      if (!mounted) return;
      _setTyping(false);
      setState(() {
        _uploadingImage = false;
        _sending = false;
        _msgs.add(_Msg(text: "صار خطأ في رفع الصورة. جرّب مرة ثانية.", fromBot: true));
      });
      _scrollDown();
    }
  }

  // ----------------------------
  // Icons for options
  // ----------------------------
  IconData _iconForOptionText(String label) {
    final t = label.toLowerCase();

    if (t.contains("الإبلاغ") || t.contains("بلاغ") || t.contains("مفقود") || t.contains("lost")) {
      return Icons.report_gmailerrorred_outlined;
    }
    if (t.contains("الأسئلة") || t.contains("اسئلة") || t.contains("عام") || t.contains("help")) {
      return Icons.help_outline_rounded;
    }
    if (t.contains("مواعيد") || t.contains("الجدول") || t.contains("trip") || t.contains("schedule")) {
      return Icons.schedule_rounded;
    }

    final isRoute = t.contains("تخطيط") ||
        t.contains("طريق") ||
        t.contains("وجهة") ||
        t.contains("إلى") ||
        t.contains("الى") ||
        t.contains("route") ||
        t.contains("directions");
    if (isRoute) return Icons.alt_route_rounded;

    if (t.contains("اليوم") || t.contains("today")) return Icons.today_rounded;
    if (t.contains("بكره") || t.contains("بكرة") || t.contains("tomorrow")) return Icons.calendar_month_rounded;
    if (t.contains("تاريخ") || t.contains("date")) return Icons.event_rounded;

    if (t.contains("رجوع") || t.contains("القائمه") || t.contains("القائمة") || t.contains("menu")) {
      return Icons.arrow_back_rounded;
    }
    if (t.contains("تغيير")) return Icons.swap_horiz_rounded;

    if (t.contains("محطه") || t.contains("محطة") || t.contains("مترو") || t.contains("kafd") || t.contains("stc")) {
      return Icons.train_outlined;
    }

    return Icons.arrow_forward_ios_rounded;
  }

  // ----------------------------
  // Options UI
  // ----------------------------
  Widget _buildOptionButtons() {
    if (!_hasOptions || _lastOptions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view_rounded, size: 18, color: Color(0xFF5B3FCB)),
              const SizedBox(width: 8),
              const Text("الخيارات", textDirection: TextDirection.rtl, style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Text("${_lastOptions.length}", style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _lastOptions.map((opt) {
              final icon = _iconForOptionText(opt.label);
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _sending ? null : () => _sendOption(opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _sending ? Colors.white.withOpacity(0.6) : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: const Color(0xFF2F2F2F)),
                      const SizedBox(width: 8),
                      Text(
                        opt.label,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _sending ? Colors.black38 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ----------------------------
  // Input bar
  // ----------------------------
  static const double _inputBarH = 58;
  static const double _gapAboveNav = 4;
  static const double bottomNavTotalHeight = 72;

  Widget _buildInputBar(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
                child: SizedBox(
                  height: _inputBarH,
                  child: TextField(
                    controller: _controller,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    enabled: !_uploadingImage && !_sending,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: _uploadingImage ? 'جاري رفع الصورة…' : (_sending ? 'جاري الإرسال…' : 'اكتب رسالتك…'),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Material(
                          color: const Color(0xFFE6E6E6),
                          elevation: 1,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: (_uploadingImage || _sending) ? null : _attachAndSendImage,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.photo_outlined,
                                size: 20,
                                color: (_uploadingImage || _sending) ? Colors.black26 : const Color(0xFF3A3A3A),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(59, 59, 59, 1),
                borderRadius: BorderRadius.circular(23),
              ),
              child: IconButton(
                onPressed: (_uploadingImage || _sending) ? null : _send,
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                tooltip: "Send",
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    final inputBottom = safeBottom + bottomNavTotalHeight + _gapAboveNav;
    final listBottomPadding = inputBottom + _inputBarH + 24;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, listBottomPadding),
          child: ListView.builder(
            controller: _scroll,
            itemCount: _msgs.length,
            itemBuilder: (_, i) {
              final msg = _msgs[i];
              final isLastBotMsgWithOptions =
                  msg.fromBot && !msg.isTyping && _hasOptions && i == _msgs.length - 1;

              return Column(
                crossAxisAlignment: msg.fromBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  _ChatBubble(msg: msg),

                  // ✅ NEW: Route Card widget
                  if (msg.fromBot && (msg.route != null) && msg.route!.isNotEmpty) RouteCard(route: msg.route!),

                  // ✅ Inline schedule widget (inside chat)
                  if (msg.fromBot &&
                      msg.isScheduleInline == true &&
                      (msg.scheduleStationId ?? "").trim().isNotEmpty)
                    ChatScheduleInline(
                      stationName: (msg.scheduleStationName ?? "").trim().isNotEmpty
                          ? msg.scheduleStationName!.trim()
                          : "المحطة",
                      stationId: msg.scheduleStationId!.trim(), // ✅ S1..S6
                      stationIdMap: _stationIdMap,
                      windowMinutes: 10,
                      limitTrips: 4,
                    ),

                  if (isLastBotMsgWithOptions) _buildOptionButtons(),
                ],
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: inputBottom,
          child: _buildInputBar(context),
        ),
      ],
    );
  }
}

// ----------------------------
// Models
// ----------------------------
class _BackendReply {
  final String answer;
  final String type;
  final List<_OptionItem> options;
  final Map<String, dynamic> raw;

  _BackendReply({
    required this.answer,
    required this.type,
    required this.options,
    required this.raw,
  });
}

class _OptionItem {
  final String id; // payload to send to backend
  final String label; // text shown to user
  _OptionItem({required this.id, required this.label});
}

class _OptionItemIndexOnly {
  final int index;
  final String label;
  _OptionItemIndexOnly({required this.index, required this.label});
}

class _ParsedBotReply {
  final String cleanedText;
  final List<_OptionItemIndexOnly> options;
  _ParsedBotReply({required this.cleanedText, required this.options});
}

class _Msg {
  final String? text;
  final bool fromBot;
  final bool isTyping;
  final Uint8List? imageBytes;

  final bool isScheduleInline;
  final String? scheduleStationId; // ✅ S1..S6
  final String? scheduleStationName;

  final Map<String, dynamic>? route; // ✅ NEW

  _Msg({
    this.text,
    required this.fromBot,
    this.isTyping = false,
    this.imageBytes,
    this.isScheduleInline = false,
    this.scheduleStationId,
    this.scheduleStationName,
    this.route, // ✅ NEW
  });
}

// ---------------------------------------------------------------------------
// Chat bubble UI (نفس حقك - خليته زي ما هو)
// ---------------------------------------------------------------------------

class _TagParts {
  final String? tag;
  final String clean;
  _TagParts({required this.tag, required this.clean});
}

_TagParts _extractTagFromStart(String text) {
  final t = text.trimLeft();
  final m = RegExp(r'^\[([A-Z0-9_]+)\]\s*').firstMatch(t);
  if (m == null) return _TagParts(tag: null, clean: text.trim());
  final tag = m.group(1);
  final clean = t.substring(m.end).trim();
  return _TagParts(tag: tag, clean: clean);
}

IconData _iconFromTag(String? tag) {
  switch (tag) {
    case "LF_START":
      return Icons.assignment_rounded;
    case "LF_ITEM":
      return Icons.inventory_2_rounded;
    case "LF_COLOR":
      return Icons.color_lens_rounded;
    case "LF_BRAND":
      return Icons.sell_rounded;
    case "LF_DESC":
      return Icons.notes_rounded;
    case "LF_PHOTO":
      return Icons.photo_camera_rounded;
    case "LF_STATION":
      return Icons.location_on_rounded;
    case "LF_TIME":
      return Icons.schedule_rounded;
    case "LF_DATE":
      return Icons.event_rounded;
    case "LF_CONTACT":
      return Icons.person_rounded;
    case "LF_DONE":
      return Icons.check_circle_rounded;
    case "LF_ERROR":
      return Icons.error_outline_rounded;
    default:
      return Icons.smart_toy_outlined;
  }
}

Color _colorFromTag(String? tag) {
  switch (tag) {
    case "LF_START":
      return const Color(0xFF5B3FCB);
    case "LF_ITEM":
    case "LF_COLOR":
    case "LF_BRAND":
    case "LF_DESC":
      return const Color(0xFF1976D2);
    case "LF_PHOTO":
      return const Color(0xFF6A1B9A);
    case "LF_STATION":
    case "LF_TIME":
    case "LF_DATE":
      return const Color(0xFF2E7D32);
    case "LF_CONTACT":
      return const Color(0xFF00897B);
    case "LF_DONE":
      return const Color(0xFF2E7D32);
    case "LF_ERROR":
      return const Color(0xFFD32F2F);
    default:
      return Colors.black54;
  }
}

Color _fallbackColorForText(String t) {
  final s = t.toLowerCase();
  if (s.contains("خطأ") || s.contains("غير صحيح") || s.contains("تعذر")) return const Color(0xFFD32F2F);
  if (s.contains("تذكرة") || s.contains("نجاح")) return const Color(0xFF2E7D32);
  if (s.contains("محطة") || s.contains("وقت") || s.contains("تاريخ")) return const Color(0xFF1976D2);
  return Colors.black54;
}

IconData _iconFromTagSmart(String? tag, String cleanText) {
  if (tag == "LF_DONE" || tag == "LF_ERROR" || tag == "LF_START") return _iconFromTag(tag);

  final s = cleanText.toLowerCase();
  if (s.contains("لون")) return Icons.color_lens_rounded;
  if (s.contains("الماركة") || s.contains("الموديل")) return Icons.sell_rounded;
  if (s.contains("تفاصيل") || s.contains("علامة مميزة") || s.contains("علامه مميزه")) return Icons.notes_rounded;
  if (s.contains("صورة") || s.contains("ارفقي") || s.contains("ارفاق")) return Icons.photo_camera_rounded;
  if (s.contains("محطة") || s.contains("محطه")) return Icons.location_on_rounded;

  if (s.contains("متى") || s.contains("وقت") || s.contains("تاريخ")) {
    if (s.contains("تاريخ") || RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(s)) return Icons.event_rounded;
    return Icons.schedule_rounded;
  }

  if (s.contains("اسم") || s.contains("جوال") || s.contains("رقم")) return Icons.person_rounded;

  return _iconFromTag(tag);
}

class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});

  IconData _fallbackBotIconForText(String t) {
    final s = t.toLowerCase();
    if (s.contains("بلاغ") || s.contains("مفقود")) return Icons.report_problem_outlined;
    if (s.contains("محطة") || s.contains("محطات")) return Icons.train_outlined;
    if (s.contains("وقت") || s.contains("متى") || s.contains("تاريخ")) return Icons.schedule_outlined;
    if (s.contains("صورة") || s.contains("ارفقي") || s.contains("ارفاق")) return Icons.photo_camera_outlined;
    if (s.contains("رقم التذكرة") || s.contains("تذكرة")) return Icons.confirmation_number_outlined;
    if (s.contains("خطأ") || s.contains("غير صحيح") || s.contains("تعذر")) return Icons.error_outline;
    return Icons.smart_toy_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final isBot = msg.fromBot;
    final bg = isBot ? const Color(0xFFEDE7F6) : const Color(0xFFE8F5E9);
    final fg = Colors.black87;
    final align = isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end;

    final rawText = (msg.text ?? "").trim();
    final parts = isBot ? _extractTagFromStart(rawText) : _TagParts(tag: null, clean: rawText);
    final tag = parts.tag;
    final cleanText = parts.clean;

    final botIcon = isBot
        ? (tag != null ? _iconFromTagSmart(tag, cleanText) : _fallbackBotIconForText(cleanText))
        : null;
    final iconColor = isBot ? (tag != null ? _colorFromTag(tag) : _fallbackColorForText(cleanText)) : null;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isBot ? 2 : 12),
              bottomRight: Radius.circular(isBot ? 12 : 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBot) ...[
                Icon(botIcon, size: 18, color: iconColor),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  cleanText,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(color: fg, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}