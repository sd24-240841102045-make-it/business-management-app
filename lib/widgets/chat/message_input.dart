import 'dart:async';
import 'package:flutter/material.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String text) onSend;
  final Function(bool isTyping)? onTypingChanged;
  final List<Map<String, String>>? quickPrompts;
  final bool isSending;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onTypingChanged,
    this.quickPrompts,
    this.isSending = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  Timer? _typingDebounce;
  bool _isCurrentlyTyping = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _typingDebounce?.cancel();
    if (_isCurrentlyTyping) {
      widget.onTypingChanged?.call(false);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText) {
      if (!_isCurrentlyTyping) {
        _isCurrentlyTyping = true;
        widget.onTypingChanged?.call(true);
      }
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 2), () {
        if (mounted && _isCurrentlyTyping) {
          _isCurrentlyTyping = false;
          widget.onTypingChanged?.call(false);
        }
      });
    } else {
      if (_isCurrentlyTyping) {
        _isCurrentlyTyping = false;
        _typingDebounce?.cancel();
        widget.onTypingChanged?.call(false);
      }
    }
  }

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || widget.isSending) return;

    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      _typingDebounce?.cancel();
      widget.onTypingChanged?.call(false);
    }

    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final prompts = widget.quickPrompts ?? [
      {'label': '\u{1F44B} Quick Hello', 'text': 'Hello! Hope you are doing well.'},
      {'label': '\u{1F4CB} Request Update', 'text': 'Could you please share an update on current deliverables?'},
      {'label': '\u{1F4C5} Schedule Call', 'text': 'Let\'s schedule a brief sync when you are available.'},
      {'label': '\u2705 Approved', 'text': 'Thanks! Looks good to proceed.'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: kPremiumSurface.withOpacity(0.96),
        border: const Border(top: BorderSide(color: kPremiumBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Prompt Suggestions
            if (prompts.isNotEmpty)
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                margin: const EdgeInsets.only(top: 6),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: prompts.length,
                  itemBuilder: (ctx, index) {
                    final p = prompts[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(
                          p['label']!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kPremiumGold,
                          ),
                        ),
                        backgroundColor: kPremiumGold.withOpacity(0.08),
                        side: BorderSide(color: kPremiumGold.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onPressed: () => widget.onSend(p['text']!),
                      ),
                    );
                  },
                ),
              ),

            // Message Input Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      style: const TextStyle(color: kPremiumText, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
                        hintStyle: const TextStyle(color: kPremiumMuted, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: kPremiumBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: kPremiumBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: kPremiumGold, width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      gradient: kGradBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kPremiumBlue.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: widget.isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      tooltip: 'Send Message',
                      onPressed: widget.isSending ? null : _handleSend,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
