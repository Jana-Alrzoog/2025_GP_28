import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AssistantTab extends StatefulWidget {
  const AssistantTab({super.key});

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<AssistantTab> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  final List<_Msg> _msgs = [
    _Msg(text: 'أهلًا! اكتب start عشان نبدأ 👋', fromBot: true),
  ];

  static const double _inputBarHeight = 68;


  late final String _baseUrl = _detectBaseUrl();

  final String _sessionId = "test_session_1";
  final String _passengerId = "042dTZgI0sb1DyMMFZfpwd5tgCs2";

  // Options extracted from bot message
  List<_OptionItem> _lastOptions = [];
  bool _hasOptions = false;

  String _detectBaseUrl() {
    if (kIsWeb) {
      return "http://127.0.0.1:8000";
    }
    if (Platform.isAndroid) {
      // Android emulator
      return "http://10.0.2.2:8000";
    }
    return "http://127.0.0.1:8000";
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<String> _askBackend(String text) async {
    final uri = Uri.parse("$_baseUrl/ask");

    final body = {
      "question": text,
      "session_id": _sessionId,
      "passenger_id": _passengerId,
    };

    try {
      final res = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        return "⚠️ Server error: ${res.statusCode}";
      }

      final data = jsonDecode(res.body);
      return (data["answer"] ?? "").toString().trim();
    } catch (e) {
      return "Failed to connect to server.\n"
          "Check:\n"
          "- backend running on port 8000\n"
          "- baseUrl = $_baseUrl\n"
          "- same Wi-Fi if using real phone";
    }
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

      // pattern 1: 1 خيار
      final matchEmoji = RegExp(r'^(\d+)️⃣\s+(.+)$').firstMatch(line);
      if (matchEmoji != null) {
        options.add(_OptionItem(
          index: int.parse(matchEmoji.group(1)!),
          label: matchEmoji.group(2)!.trim(),
        ));
        continue;
      }

      // pattern 2: 1 - خيار
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
        _msgs.add(_Msg(text: "…", fromBot: true, isTyping: true));
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

  void _openOptionsSheet() {
    if (_lastOptions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "اختاري من القائمة",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _lastOptions.map((opt) {
                    return ActionChip(
                      label: Text("${opt.index} - ${opt.label}"),
                      onPressed: () {
                        Navigator.pop(context);
                        _send(opt.index.toString());
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, _inputBarHeight + 80),
          child: ListView.builder(
            controller: _scroll,
            itemCount: _msgs.length,
            itemBuilder: (_, i) => _ChatBubble(msg: _msgs[i]),
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
                      if (_hasOptions) ...[
                        IconButton(
                          tooltip: "اختيار من القائمة",
                          onPressed: _openOptionsSheet,
                          icon: const Icon(Icons.filter_list),
                        ),
                        const SizedBox(width: 4),
                      ],

                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالتك… (مثال: start أو menu)',
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
            style: TextStyle(color: fg, height: 1.4),
          ),
        ),
      ],
    );
  }
}
