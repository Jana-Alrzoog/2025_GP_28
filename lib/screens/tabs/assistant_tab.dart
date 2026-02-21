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

  // Detect base URL for backend (port 8000)
  String _detectBaseUrl() {
    if (kIsWeb) return "http://localhost:8000";
    return "http://10.0.2.2:8000";
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

  Future<String> _askBackend(String text) async {
    final uri = Uri.parse("$_baseUrl/ask");

    if (!_sessionReady || _passengerId == null) {
      return "لم يتم تسجيل الدخول. سجّل دخولك ثم افتح المساعد مرة ثانية.";
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
        return "تعذر الحصول على موقعك حالياً. تأكد من تفعيل GPS ومنح إذن الموقع للتطبيق.";
      }

      final Position? pos = await LocationService.getCurrentPosition();
      lat = pos?.latitude;
      lon = pos?.longitude;

      if (lat == null || lon == null) {
        return "تعذر الحصول على موقعك حالياً. تأكد من تفعيل GPS ومنح إذن الموقع للتطبيق.";
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
        return "Server error: ${res.statusCode}\n${res.body}";
      }

      final data = jsonDecode(res.body);
      return (data["answer"] ?? "").toString().trim();
    } catch (_) {
      return "Failed to connect to server.\n"
          "Check:\n"
          "- backend running on port 8000\n"
          "- baseUrl = $_baseUrl\n"
          "- Using Android emulator => 10.0.2.2\n";
    }
  }

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

    final answer = await _askBackend("MENU");
    if (!mounted) return;

    _setTyping(false);

    final parsed = _parseBotReply(answer);
    setState(() {
      _msgs.add(_Msg(
        text: parsed.cleanedText.isEmpty
            ? (answer.isEmpty ? "Empty reply" : answer)
            : parsed.cleanedText,
        fromBot: true,
      ));
    });

    _applyOptions(parsed.options);
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

  // Parse bot reply:
  // - Extract numbered options from lines like "1️⃣ label" or "1 - label"
  // - Remove those option lines from the chat bubble (keeps bubble clean)
  _ParsedBotReply _parseBotReply(String botText) {
    final lines = botText.split('\n');
    final options = <_OptionItem>[];
    final keptLines = <String>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final matchEmoji = RegExp(r'^(\d+)️⃣\s+(.+)$').firstMatch(line);
      if (matchEmoji != null) {
        options.add(_OptionItem(
          index: int.parse(matchEmoji.group(1)!),
          label: matchEmoji.group(2)!.trim(),
        ));
        continue;
      }

      final matchDash = RegExp(r'^(\d+)\s*[-–]\s*(.+)$').firstMatch(line);
      if (matchDash != null) {
        options.add(_OptionItem(
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

    final answer = await _askBackend(txt);
    if (!mounted) return;

    _setTyping(false);

    final parsed = _parseBotReply(answer);
    setState(() {
      _msgs.add(_Msg(
        text: parsed.cleanedText.isEmpty
            ? (answer.isEmpty ? "Empty reply" : answer)
            : parsed.cleanedText,
        fromBot: true,
      ));
      _sending = false;
    });

    _applyOptions(parsed.options);
    _scrollDown();
  }

  // Send option as plain number (best with your backend flows)
  Future<void> _sendOption(_OptionItem opt) async {
    if (_sending) return;

    final display = opt.label.trim();
    final backend = opt.index.toString();

    setState(() {
      _sending = true;
      _msgs.add(_Msg(text: display, fromBot: false));
      _hasOptions = false;
      _lastOptions = [];
    });

    _scrollDown();
    _setTyping(true);
    _scrollDown();

    final answer = await _askBackend(backend);
    if (!mounted) return;

    _setTyping(false);

    final parsed = _parseBotReply(answer);
    setState(() {
      _msgs.add(_Msg(
        text: parsed.cleanedText.isEmpty
            ? (answer.isEmpty ? "Empty reply" : answer)
            : parsed.cleanedText,
        fromBot: true,
      ));
      _sending = false;
    });

    _applyOptions(parsed.options);
    _scrollDown();
  }

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

        _msgs.add(_Msg(
          fromBot: false,
          imageBytes: bytes,
          text: "صورة مرفقة",
        ));
      });

      _scrollDown();
      _setTyping(true);
      _scrollDown();

      await _uploadImageToBackend(picked);

      final answer = await _askBackend("تم");
      if (!mounted) return;

      _setTyping(false);

      final parsed = _parseBotReply(answer);
      setState(() {
        _uploadingImage = false;
        _sending = false;
        _msgs.add(_Msg(
          text: parsed.cleanedText.isEmpty
              ? (answer.isEmpty ? "Empty reply" : answer)
              : parsed.cleanedText,
          fromBot: true,
        ));
      });

      _applyOptions(parsed.options);
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

    // Route planning: do not match the app name "مسار" by itself.
    final isRoute =
        t.contains("تخطيط") ||
        t.contains("طريق") ||
        t.contains("وجهة") ||
        t.contains("إلى") ||
        t.contains("الى") ||
        t.contains("route") ||
        t.contains("directions");
    if (isRoute) {
      return Icons.alt_route_rounded;
    }

    if (t.contains("محطة") || t.contains("مترو") || t.contains("كافد")) {
      return Icons.train_outlined;
    }

    if (t.contains("اليوم") || t.contains("أمس") || t.contains("صباح") || t.contains("مساء")) {
      return Icons.access_time_rounded;
    }

    return Icons.arrow_forward_ios_rounded;
  }

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
              const Text(
                "الخيارات",
                textDirection: TextDirection.rtl,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Text(
                  "${_lastOptions.length}",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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
                      hintText: _uploadingImage
                          ? 'جاري رفع الصورة…'
                          : (_sending ? 'جاري الإرسال…' : 'اكتب رسالتك…'),
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
                                color: (_uploadingImage || _sending)
                                    ? Colors.black26
                                    : const Color(0xFF3A3A3A),
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
                crossAxisAlignment:
                    msg.fromBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  _ChatBubble(msg: msg),
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

class _OptionItem {
  final int index;
  final String label;
  _OptionItem({required this.index, required this.label});
}

class _ParsedBotReply {
  final String cleanedText;
  final List<_OptionItem> options;
  _ParsedBotReply({required this.cleanedText, required this.options});
}

class _Msg {
  final String? text;
  final bool fromBot;
  final bool isTyping;
  final Uint8List? imageBytes;

  _Msg({
    this.text,
    required this.fromBot,
    this.isTyping = false,
    this.imageBytes,
  });
}

/*
  Tag icon support:
  Extracts a tag only if it exists at the start of the bot message.
  Example: "[LF_COLOR]\n2) ..." -> tag = LF_COLOR, cleanText = "2) ..."
*/
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
  if (s.contains("خطأ") || s.contains("غير صحيح") || s.contains("تعذر")) {
    return const Color(0xFFD32F2F);
  }
  if (s.contains("تذكرة") || s.contains("نجاح")) {
    return const Color(0xFF2E7D32);
  }
  if (s.contains("محطة") || s.contains("وقت") || s.contains("تاريخ")) {
    return const Color(0xFF1976D2);
  }
  return Colors.black54;
}

/*
  Smart override:
  If tag is wrong but text clearly indicates a step, use the matching icon.
*/
IconData _iconFromTagSmart(String? tag, String cleanText) {
  if (tag == "LF_DONE" || tag == "LF_ERROR" || tag == "LF_START") {
    return _iconFromTag(tag);
  }

  final s = cleanText.toLowerCase();

  if (s.contains("لون")) return Icons.color_lens_rounded;
  if (s.contains("الماركة") || s.contains("الموديل")) return Icons.sell_rounded;
  if (s.contains("تفاصيل") || s.contains("علامة مميزة") || s.contains("علامه مميزه")) {
    return Icons.notes_rounded;
  }
  if (s.contains("صورة") || s.contains("ارفقي") || s.contains("ارفاق")) {
    return Icons.photo_camera_rounded;
  }
  if (s.contains("محطة") || s.contains("محطه")) return Icons.location_on_rounded;

  // Time/date detection: if it mentions date OR time OR "when"
  if (s.contains("متى") || s.contains("وقت") || s.contains("تاريخ")) {
    if (s.contains("تاريخ") || RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(s)) {
      return Icons.event_rounded;
    }
    return Icons.schedule_rounded;
  }

  if (s.contains("اسم") || s.contains("جوال") || s.contains("رقم")) {
    return Icons.person_rounded;
  }

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

    final parts =
        isBot ? _extractTagFromStart(rawText) : _TagParts(tag: null, clean: rawText);
    final tag = parts.tag;
    final cleanText = parts.clean;

    final botIcon = isBot
        ? (tag != null ? _iconFromTagSmart(tag, cleanText) : _fallbackBotIconForText(cleanText))
        : null;

    final iconColor = isBot
        ? (tag != null ? _colorFromTag(tag) : _fallbackColorForText(cleanText))
        : null;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * .78,
          ),
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
          child: Column(
            crossAxisAlignment: align,
            children: [
              if (msg.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    msg.imageBytes!,
                    fit: BoxFit.cover,
                    height: 180,
                    width: double.infinity,
                  ),
                ),
                if (cleanText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
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
                ],
              ] else ...[
                Row(
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
              ],
            ],
          ),
        ),
      ],
    );
  }
}
