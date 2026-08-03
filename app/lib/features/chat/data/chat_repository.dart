import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/errors/rate_limited.dart';
import 'package:dollchecker/core/l10n/locale_controller.dart';
import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/chat/domain/chat_message.dart';

/// The conversation is a premium feature — a scan is one bounded call, a chat
/// is not — so the paywall, not an error, is the right answer.
class ChatPremiumRequiredException implements Exception {}

class ChatFailedException implements Exception {}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseProvider), ref);
});

class ChatRepository {
  ChatRepository(this._client, this._ref);
  final SupabaseClient _client;
  final Ref _ref;

  /// The stored thread for one scan, oldest first.
  Future<List<ChatMessage>> history(String scanId) async {
    final rows = await _client
        .from('chat_messages')
        .select('id, role, content, created_at')
        .eq('scan_id', scanId)
        .order('created_at');
    return (rows as List)
        .map((r) => ChatMessage.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Asks a question and returns the answer. Both turns are persisted by the
  /// Edge Function, so nothing is written from here.
  Future<String> ask({
    required String scanId,
    required String question,
  }) async {
    final dynamic payload;
    try {
      final res = await _client.functions.invoke('chat-toy', body: {
        'scan_id': scanId,
        'question': question,
        'locale': _ref.read(localeProvider).languageCode,
      });
      if (res.status == 402) throw ChatPremiumRequiredException();
      if (res.status == 429) throw rateLimitedFrom(res.data);
      if (res.status != 200 || res.data == null) throw ChatFailedException();
      payload = res.data;
    } on FunctionException catch (e) {
      // Newer supabase_flutter throws instead of returning a non-2xx status.
      if (e.status == 402) throw ChatPremiumRequiredException();
      if (e.status == 429) throw rateLimitedFrom(e.details);
      throw ChatFailedException();
    }

    final reply = (payload as Map)['reply']?.toString();
    if (reply == null || reply.isEmpty) throw ChatFailedException();
    return reply;
  }
}

/// The thread for one scan.
final chatThreadProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, scanId) async {
  return ref.watch(chatRepositoryProvider).history(scanId);
});
