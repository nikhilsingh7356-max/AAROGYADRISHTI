/// Lifestyle coach - conversation list (Phase 6).
///
/// The coach answers only from aggregate lifestyle data; it never diagnoses
/// or prescribes. Replies are sanitised by the backend safety guard.
library;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../models/coach.dart';
import '../../repositories/coach_repository.dart';
import '../../widgets/app_card.dart';
import '../../widgets/state_views.dart';
import 'chat_screen.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final CoachRepository _repo = CoachRepository(AppServices.instance.api);

  List<CoachConversation> _conversations = const [];
  bool _loading = true;
  bool _creating = false;
  String? _error;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _offline = false;
    });
    try {
      final data = await _repo.conversations();
      if (mounted) setState(() => _conversations = data.conversations);
    } on NetworkException {
      if (mounted) {
        setState(() {
          _error = AppStrings.noInternet;
          _offline = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newChat() async {
    setState(() => _creating = true);
    try {
      final convo = await _repo.createConversation();
      if (!mounted) return;
      await _openChat(convo.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _openChat(int conversationId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(conversationId: conversationId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lifestyle Coach'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _newChat,
        icon: _creating
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chat_bubble_outline),
        label: const Text('New chat'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load, offline: _offline)
              : _conversations.isEmpty
                  ? _EmptyCoach(
                      onNewChat: _newChat,
                      creating: _creating,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final c = _conversations[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              onTap: () => _openChat(c.id),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: Icon(Icons.chat_outlined,
                                    color: scheme.primary),
                                title: Text(
                                  c.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                    AppDateUtils.shortDay(c.createdAt.toLocal())),
                                trailing: Icon(Icons.chevron_right_rounded,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _EmptyCoach extends StatelessWidget {
  const _EmptyCoach({required this.onNewChat, required this.creating});

  final VoidCallback onNewChat;
  final bool creating;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.psychology_alt_outlined,
                  size: 36, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your coach is ready when you are',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Chat about your lifestyle patterns to see honest, data-backed observations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, height: 1.45, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.coachSafetyNote,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: creating ? null : onNewChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Start your first chat'),
            ),
          ],
        ),
      ),
    );
  }
}
