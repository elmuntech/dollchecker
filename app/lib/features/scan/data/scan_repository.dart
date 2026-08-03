import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/scan/domain/toy_analysis.dart';

/// How many scans one page of history holds.
const kHistoryPageSize = 30;

class QuotaExceededException implements Exception {}

class AnalysisException implements Exception {
  final String message;
  AnalysisException(this.message);
}

final scanRepositoryProvider = Provider<ScanRepository>((ref) {
  return ScanRepository(ref.watch(supabaseProvider));
});

class ScanRepository {
  ScanRepository(this._client);
  final SupabaseClient _client;

  /// Sends the image to the `analyze-toy` Edge Function (which holds the
  /// Anthropic key). The user's JWT is attached automatically.
  Future<ScanResult> analyze({
    required Uint8List imageBytes,
    required String mediaType,
    String? childProfileId,
    required String locale,
  }) async {
    late final dynamic payload;
    try {
      final res = await _client.functions.invoke(
        'analyze-toy',
        body: {
          'image_base64': base64Encode(imageBytes),
          'media_type': mediaType,
          'child_profile_id': childProfileId,
          'locale': locale,
        },
      );
      if (res.status == 429) throw QuotaExceededException();
      if (res.status != 200 || res.data == null) {
        throw AnalysisException('status ${res.status}');
      }
      payload = res.data;
    } on FunctionException catch (e) {
      // Newer supabase_flutter throws instead of returning a non-2xx status.
      if (e.status == 429) throw QuotaExceededException();
      throw AnalysisException('status ${e.status}');
    }

    final data = Map<String, dynamic>.from(payload as Map);
    return ScanResult(
      scanId: data['scan_id'].toString(),
      imagePath: data['image_path'] as String?,
      analysis:
          ToyAnalysis.fromJson(Map<String, dynamic>.from(data['analysis'])),
    );
  }

  /// One page of history for the current user, newest first.
  ///
  /// Paged rather than capped: the old fixed limit meant a family past it
  /// simply stopped seeing their older scans, with nothing to say so.
  Future<List<ScanSummary>> history({
    int limit = kHistoryPageSize,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('scans')
        .select('id, identification, safety_overall, educational_score, created_at')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List)
        .map((r) => ScanSummary.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Reopen a stored scan from its saved raw analysis.
  Future<ScanResult> getScan(String id) async {
    final row = await _client
        .from('scans')
        .select('id, image_url, raw_response')
        .eq('id', id)
        .single();
    final map = Map<String, dynamic>.from(row);
    return ScanResult(
      scanId: map['id'].toString(),
      imagePath: map['image_url'] as String?,
      analysis:
          ToyAnalysis.fromJson(Map<String, dynamic>.from(map['raw_response'])),
    );
  }

  /// Signed URL for a private toy image (valid 1 hour), or null.
  Future<String?> signedImageUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await _client.storage.from('toy-images').createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }
}
