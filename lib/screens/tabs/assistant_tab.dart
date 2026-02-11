import 'dart:convert';
import 'dart:math';


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

  String _detectBaseUrl() {
    if (kIsWeb) return "http://10.203.225.185:8000";
    // Android emulator
    return "http://10.203.225.185:8000";
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

    // الفورم اللي السيرفر ينتظره
    req.fields["passenger_id"] = _passengerId!;
    req.fields["session_id"] = _sessionId;
    if (ticketId != null && ticketId.isNotEmpty) {
      req.fields["ticket_id"] = ticketId;
    }

    // ملف الصورة
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
        return "Server error: ${res.statusCode}";
      }

      final data = jsonDecode(res.body);
      return (data["answer"] ?? "").toString().trim();
    } catch (_) {
      return "Failed to connect to server.\n"
          "Check:\n"
          "- backend running on port 8000\n"
          "- baseUrl = $_baseUrl\n"
          "- same Wi-Fi if using a real phone";
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

    setState(() {
      _msgs.add(_Msg(text: answer.isEmpty ? "Empty reply" : answer, fromBot: true));
    });

    _extractOptionsFromBot(answer);
    _scrollDown();
    _loadingMenu = false;
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 160,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _extractOptionsFromBot(String botText) {
    final lines = botText.split('\n');
    final options = <_OptionItem>[];

    for (final l in lines) {
      final line = l.trim();

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
    }

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
    final txt = (forcedText ?? _controller.text).trim();
    if (txt.isEmpty) return;

    setState(() {
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

    setState(() {
      _msgs.add(_Msg(text: answer.isEmpty ? "Empty reply" : answer, fromBot: true));
    });

    _extractOptionsFromBot(answer);
    _scrollDown();
  }

  Future<void> _attachAndSendImage() async {
    if (_uploadingImage) return;

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

      setState(() {
        _uploadingImage = true;
        _hasOptions = false;
        _lastOptions = [];
        _msgs.add(_Msg(text: "تم إرفاق صورة", fromBot: false));
      });

      _scrollDown();
      _setTyping(true);
      _scrollDown();

      final url = await _uploadImageToBackend(picked);

// ما نرسل photo_url داخل /ask
// لأن السيرفر أصلاً يحطه في session_store داخل upload endpoint
      final answer = await _askBackend("تم");


      _setTyping(false);

      setState(() {
        _uploadingImage = false;
        _msgs.add(_Msg(text: answer.isEmpty ? "Empty reply" : answer, fromBot: true));
      });

      _extractOptionsFromBot(answer);
      _scrollDown();
    } catch (_) {
      if (!mounted) return;
      _setTyping(false);
      setState(() {
        _uploadingImage = false;
        _msgs.add(_Msg(text: "صار خطأ في رفع الصورة. جرّب مرة ثانية.", fromBot: true));
      });
      _scrollDown();
    }
  }

  Widget _buildOptionButtons() {
    if (!_hasOptions || _lastOptions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _lastOptions.map((opt) {
          return ElevatedButton(
            onPressed: () => _send(opt.index.toString()),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFF1F1F1),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.black.withOpacity(.08)),
              ),
            ),
            child: Text(opt.label, textDirection: TextDirection.rtl),
          );
        }).toList(),
      ),
    );
  }

  // NEW: input bar height constants (so list padding matches perfectly)
  static const double _inputBarH = 58;

  //  CHANGED: closer to bottom bar
  static const double _gapAboveNav = 4;

  //  CHANGED: smaller => input goes LOWER
  static const double bottomNavTotalHeight = 72;

  // WhatsApp-like input bar.
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
                    enabled: !_uploadingImage,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: _uploadingImage ? 'جاري رفع الصورة…' : 'اكتب رسالتك…',
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      // clearer circular gallery button (lighter color)
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Material(
                          color: const Color(0xFFE6E6E6), // lighter
                          elevation: 1,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _uploadingImage ? null : _attachAndSendImage,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.photo_outlined, // gallery icon (NOT camera)
                                size: 20,
                                color: _uploadingImage
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
                onPressed: _uploadingImage ? null : _send,
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

class _Msg {
  final String text;
  final bool fromBot;
  final bool isTyping;
  _Msg({required this.text, required this.fromBot, this.isTyping = false});
}

class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isBot = msg.fromBot;
    final bg = isBot ? const Color(0xFFEDE7F6) : const Color(0xFFE8F5E9);
    final fg = Colors.black87;
    final align = isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end;

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
          child: Text(
            msg.text,
            textDirection: TextDirection.rtl,
            style: TextStyle(color: fg, height: 1.4),
          ),
        ),
      ],
    );
  }
}
