/// Coach chat screen.
///
/// Messages come from the backend, which builds context from the user's
/// aggregate lifestyle data only. The backend sanitises replies and appends a
/// "not a doctor" disclaimer; this screen presents them faithfully and never
/// rewrites content. Failed sends stay visible with an inline retry instead of
/// being silently dropped.
library;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../models/coach.dart';
import '../../repositories/coach_repository.dart';
import '../../widgets/loading_skeleton.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId, this.title = 'Coach chat'});

  final int conversationId;
  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final CoachRepository _repo = CoachRepository(AppServices.instance.api);
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<CoachMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  // A send that failed: kept so the user can retry without retyping.
  String? _failedText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.messages(widget.conversationId);
      if (mounted) {
        setState(() => _messages = data.messages);
        _jumpToBottom();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _composer.text).trim();
    if (text.isEmpty || _sending) return;
    _composer.clear();
    setState(() {
      _sending = true;
      _failedText = null;
    });
    try {
      final reply = await _repo.send(widget.conversationId, text);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, reply.reply];
        _sending = false;
      });
      _jumpToBottom();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _failedText = text;
          _messages = [..._messages, _errorBubble(e.message)];
        });
        _jumpToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _failedText = text;
          _messages = [..._messages, _errorBubble(AppStrings.somethingWentWrong)];
        });
      }
    }
  }

  CoachMessage _errorBubble(String message) => CoachMessage(
        id: -DateTime.now().millisecondsSinceEpoch,
        conversationId: widget.conversationId,
        role: 'assistant',
        content: message,
        provider: 'error',
        safetyApplied: false,
        createdAt: DateTime.now(),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          _SafetyBanner(scheme: scheme),
          Expanded(
            child: _loading
                ? Column(
                    children: const [
                      SizedBox(height: 12),
                      SkeletonCard(height: 72),
                      SizedBox(height: 10),
                      SkeletonCard(height: 72),
                      SizedBox(height: 10),
                      SkeletonCard(height: 72),
                    ],
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded,
                                size: 40, color: scheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonal(
                              onPressed: _load,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      )
                    : GestureDetector(
                        // Dismiss the keyboard when tapping the message area.
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: ListView.builder(
                          controller: _scroll,
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount:
                              _messages.length + (_sending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_sending && index == _messages.length) {
                              return const _TypingIndicator();
                            }
                            final m = _messages[index];
                            return CoachMessageBubble(message: m);
                          },
                        ),
                      ),
          ),
          if (_failedText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your last message failed to send.',
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _send(_failedText),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          _Composer(
            controller: _composer,
            sending: _sending,
            onSend: () => _send(),
          ),
        ],
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.surfaceContainerLow,
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 15, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.coachSafetyNote,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(
          width: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final delay in const [0, 150, 300])
                _Dot(delay: Duration(milliseconds: delay), color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay, required this.color});

  final Duration delay;
  final Color color;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(
          parent: _c,
          curve: Interval(
            widget.delay.inMilliseconds / 700,
            1,
            curve: Curves.easeInOut,
          ),
        ),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ask about your patterns\u2026',
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            sending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  )
                : IconButton.filled(
                    tooltip: 'Send',
                    onPressed: onSend,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 22),
                  ),
          ],
        ),
      ),
    );
  }
}

/// One chat message. Assistant bubbles sit left on a soft surface; user
/// bubbles sit right in the primary color. Error pseudo-messages show an
/// inline retry affordance instead of pretending the send succeeded.
class CoachMessageBubble extends StatelessWidget {
  const CoachMessageBubble({super.key, required this.message});

  final CoachMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = message.provider == 'error';
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primary
              : isError
                  ? scheme.errorContainer
                  : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.content,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: isUser
                    ? scheme.onPrimary
                    : isError
                        ? scheme.onErrorContainer
                        : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppDateUtils.timeLabel(message.createdAt.toLocal()),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isUser
                        ? scheme.onPrimary.withValues(alpha: 0.7)
                        : scheme.onSurfaceVariant,
                  ),
                ),
                if (!isUser && !isError && message.safetyApplied) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified_user_outlined,
                      size: 12, color: scheme.onSurfaceVariant),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
