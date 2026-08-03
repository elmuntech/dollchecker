import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dollchecker/core/errors/rate_limited.dart';
import 'package:dollchecker/features/chat/data/chat_repository.dart';
import 'package:dollchecker/features/chat/domain/chat_message.dart';
import 'package:dollchecker/l10n/app_localizations.dart';
import 'package:dollchecker/shared/widgets/error_retry.dart';

/// Everything a parent asks after the analysis: "she ignores it, now what?",
/// "is the noise a problem?", "how do I get more out of it?".
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.scanId});

  final String scanId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// Turns not yet in the stored thread: the question just asked and, once it
  /// arrives, its answer.
  final List<ChatMessage> _pending = [];

  bool _sending = false;
  bool _premiumRequired = false;
  bool _failed = false;
  bool _rateLimited = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final question = text.trim();
    if (question.isEmpty || _sending) return;

    _input.clear();
    setState(() {
      _pending.add(ChatMessage.pending(question));
      _sending = true;
      _failed = false;
      _rateLimited = false;
      _premiumRequired = false;
    });
    _scrollToEnd();

    try {
      final reply = await ref.read(chatRepositoryProvider).ask(
            scanId: widget.scanId,
            question: question,
          );
      if (!mounted) return;
      setState(() {
        _pending.add(ChatMessage(
          id: 'pending-reply-${_pending.length}',
          isFromParent: false,
          content: reply,
          createdAt: DateTime.now(),
        ));
      });
    } on ChatPremiumRequiredException {
      if (mounted) setState(() => _premiumRequired = true);
    } on RateLimitedException {
      if (mounted) setState(() => _rateLimited = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final thread = ref.watch(chatThreadProvider(widget.scanId));

    return Scaffold(
      appBar: AppBar(title: Text(l.askAboutToy)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: thread.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => ErrorRetry(
                  onRetry: () =>
                      ref.invalidate(chatThreadProvider(widget.scanId)),
                ),
                data: (stored) {
                  final messages = [...stored, ..._pending];
                  if (messages.isEmpty) {
                    return _Starters(onPick: _send, enabled: !_sending);
                  }
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) =>
                        _Bubble(message: messages[i]),
                  );
                },
              ),
            ),
            if (_premiumRequired)
              _PremiumBanner(onUpgrade: () => context.push('/paywall'))
            else if (_failed || _rateLimited)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _rateLimited ? l.rateLimited : l.chatFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            _Composer(
              controller: _input,
              sending: _sending,
              onSend: () => _send(_input.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.isFromParent;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.content),
      ),
    );
  }
}

/// A blank chat box is a hard place to start, so the empty thread offers the
/// questions the analysis itself cannot answer.
class _Starters extends StatelessWidget {
  const _Starters({required this.onPick, required this.enabled});

  final void Function(String) onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final starters = [
      l.chatStarterAge,
      l.chatStarterBored,
      l.chatStarterSafety,
      l.chatStarterSkill,
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Center(child: Text('💬', style: TextStyle(fontSize: 44))),
        const SizedBox(height: 12),
        Text(
          l.chatEmpty,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        for (final starter in starters)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: enabled ? () => onPick(starter) : null,
              child: Text(starter, textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ListTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: Text(l.chatPremiumRequired),
        trailing: FilledButton.tonal(
          onPressed: onUpgrade,
          child: Text(l.upgrade),
        ),
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
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: l.chatHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton.filled(
                  onPressed: onSend,
                  icon: const Icon(Icons.send),
                  tooltip: l.chatSend,
                ),
        ],
      ),
    );
  }
}
