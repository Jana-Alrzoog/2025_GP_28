import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:firebase_auth/firebase_auth.dart';

// Needed for Position type (returned by LocationService)
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

  static const double _inputBarHeight = 68;

  late final String _baseUrl = _detectBaseUrl();

  // Session is generated per tab open to avoid mixing old chats.
  late String _sessionId;

  // Passenger id comes from Firebase user uid.
  String? _passengerId;

  List<_OptionItem> _lastOptions = [];
  bool _hasOptions = false;

  bool _loadingMenu = false;
  bool _sessionReady = false;

  String _detectBaseUrl() {
    if (kIsWeb) return "http://127.0.0.1:8000";
    if (Platform.isAndroid) return "http://10.0.2.2:8000";
    return "http://127.0.0.1:8000";
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
      debugPrint("AssistantTab: Firebase user is null (not signed in).");
      setState(() {
        _sessionReady = false;
        _passengerId = null;
      });
      return;
    }

    _passengerId = user.uid;

    // Generate a unique session id each time the tab opens.
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(1 << 30);
    _sessionId = "${user.uid}_$now_$rand";

    debugPrint("AssistantTab: passenger_id = $_passengerId");
    debugPrint("AssistantTab: session_id = $_sessionId");

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

  Future<String> _askBackend(String text) async {
    final uri = Uri.parse("$_baseUrl/ask");

    if (!_sessionReady || _passengerId == null) {
      return "لم يتم تسجيل الدخول. سجلي دخولك ثم افتحي المساعد مرة ثانية.";
    }

    double? lat;
    double? lon;

    final bool useLocation = await LocationService.getUseLocation();
    final bool asked = await LocationService.getHasAsked();

    debugPrint("useLocation = $useLocation");
    debugPrint("asked_location = $asked");

    if (useLocation) {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint("locationServiceEnabled = $serviceEnabled");

      if (!asked) {
        final perm = await LocationService.requestPermission();
        await LocationService.setHasAsked(true);
        debugPrint("requestPermission result = $perm");
      }

      final LocationPermission currentPerm = await Geolocator.checkPermission();
      debugPrint("checkPermission = $currentPerm");

      final Position? pos = await LocationService.getCurrentPosition();
      debugPrint("pos = $pos");

      lat = pos?.latitude;
      lon = pos?.longitude;

      debugPrint("lat = $lat, lon = $lon");

      // If user enabled location but we could not retrieve it, return a clear message
      if (lat == null || lon == null) {
        return "تعذر الحصول على موقعك حالياً. تأكد من تفعيل GPS ومنح إذن الموقع للتطبيق، وإذا كنت على Emulator حددي Location من إعدادات المحاكي.";
      }
    }

    final body = {
      "question": text,
      "session_id": _sessionId,
      "passenger_id": _passengerId,
      "lat": lat,
      "lon": lon,
    };

    debugPrint("POST /ask body = ${jsonEncode(body)}");

    try {
      final res = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        return "Server error: ${res.statusCode}";
      }

      final data = jsonDecode(res.body);
      return (data["answer"] ?? "").toString().trim();
    } catch (e) {
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

    // Always reset UI state when opening the tab
    setState(() {
      _msgs.clear();
      _hasOptions = false;
      _lastOptions = [];
    });

    _setTyping(true);
    _scrollDown();

    // Always request menu explicitly at the beginning
    final answer = await _askBackend("MENU");

    if (!mounted) return;

    _setTyping(false);

    setState(() {
      _msgs.add(_Msg(
        text: answer.isEmpty ? "Empty reply" : answer,
        fromBot: true,
      ));
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
      _msgs.add(_Msg(
        text: answer.isEmpty ? "Empty reply" : answer,
        fromBot: true,
      ));
    });

    _extractOptionsFromBot(answer);
    _scrollDown();
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
            onPressed: () {
              _send(opt.index.toString());
            },
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, _inputBarHeight + 90),
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
          bottom: 80,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Container(
                  height: _inputBarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالتك…',
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _send,
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                            const Color.fromRGBO(59, 59, 59, 1),
                          ),
                          foregroundColor: WidgetStateProperty.all(Colors.white),
                          shape: WidgetStateProperty.all(const CircleBorder()),
                        ),
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
