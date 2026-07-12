import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/ai_config.dart';
import '../database/database.dart';
import '../providers/providers.dart';
import '../controllers/connectivity_controller.dart';

/// NVIDIA NIM AI service — an OpenAI-compatible client for all AI features in
/// OmniCore.
///
/// **Models:**
/// * [AiConfig.deepModel] (DeepSeek-R1) — complex reasoning.
/// * [AiConfig.freeModel] (Llama 3.1 8B) — fast tasks (mail rate scoring).
/// * [AiConfig.visionModel] (Llama 3.2 11B Vision) — gallery photo tagging.
///
/// **Offline-first:** every method returns `null` on failure so callers can
/// fall back to the local heuristic. The app never crashes if the API is
/// unreachable.
class NvidiaAiService {
  NvidiaAiService({
    required this.apiKey,
    this.runtimeOverride,
  });

  /// The NVIDIA API key. If [runtimeOverride] is non-empty it takes priority
  /// over [apiKey] (which comes from the embedded/--dart-define config).
  final String apiKey;
  final String? runtimeOverride;

  bool get isConfigured => effectiveKey.isNotEmpty;
  String get effectiveKey =>
      (runtimeOverride != null && runtimeOverride!.isNotEmpty)
          ? runtimeOverride!
          : apiKey;

  // -----------------------------------------------------------------------
  // Chat completion (text models)
  // -----------------------------------------------------------------------

  /// Sends a chat completion request to NVIDIA NIM.
  ///
  /// [model] defaults to [AiConfig.freeModel] (Llama 3.1 8B). Pass
  /// [AiConfig.deepModel] for DeepSeek-R1 reasoning.
  Future<String?> chat({
    required String systemPrompt,
    required String userPrompt,
    String? model,
    int maxTokens = AiConfig.defaultMaxTokens,
    double temperature = AiConfig.defaultTemperature,
  }) async {
    if (!isConfigured) return null;
    try {
      final response = await http
          .post(
            Uri.parse('${AiConfig.baseUrl}${AiConfig.chatEndpoint}'),
            headers: {
              'Authorization': 'Bearer ${effectiveKey}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'model': model ?? AiConfig.freeModel,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'max_tokens': maxTokens,
              'temperature': temperature,
              'top_p': 0.7,
              'stream': false,
            }),
          )
          .timeout(AiConfig.requestTimeout);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('NVIDIA AI error ${response.statusCode}: '
              '${response.body.substring(0, response.body.length.clamp(0, 200))}');
        }
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final content =
          (choices[0] as Map<String, dynamic>)['message']['content'];
      return content is String ? content.trim() : null;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('NVIDIA AI chat failed: $e');
      return null;
    }
  }

  // -----------------------------------------------------------------------
  // Vision — AI Gallery photo tagging
  // -----------------------------------------------------------------------

  /// Tags a photo on disk using the vision model. Returns up to 5 descriptive
  /// tags, or `null` if the file doesn't exist or the API fails.
  Future<List<String>?> tagImage({
    required String imagePath,
    String? customPrompt,
  }) async {
    if (!isConfigured) return null;
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _mimeTypeForPath(imagePath);

      final prompt = customPrompt ??
          'You are a photo tagging AI. Look at this photo and respond with '
              'EXACTLY 5 single-word descriptive tags, comma-separated, '
              'lowercase, no numbering, no extra text. '
              'Example: beach, sunset, ocean, sand, warm';

      final response = await http
          .post(
            Uri.parse('${AiConfig.baseUrl}${AiConfig.chatEndpoint}'),
            headers: {
              'Authorization': 'Bearer ${effectiveKey}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'model': AiConfig.visionModel,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': prompt},
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:$mimeType;base64,$base64Image',
                      },
                    },
                  ],
                },
              ],
              'max_tokens': 100,
              'temperature': 0.3,
              'stream': false,
            }),
          )
          .timeout(AiConfig.requestTimeout);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('NVIDIA Vision error ${response.statusCode}: '
              '${response.body.substring(0, response.body.length.clamp(0, 200))}');
        }
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final content =
          (choices[0] as Map<String, dynamic>)['message']['content'];
      if (content is! String) return null;

      // Parse tags: split by comma, clean, lowercase, deduplicate.
      final tags = content
          .split(RegExp(r'[,\n]'))
          .map((t) => t
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'^[\d.\)\- ]+'), '')
              .replaceAll(RegExp(r'[^a-z0-9 -]'), '')
              .trim())
          .where((t) => t.isNotEmpty && t.length <= 24)
          .toSet()
          .take(5)
          .toList();

      return tags.isEmpty ? null : tags;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('NVIDIA Vision tagging failed: $e');
      return null;
    }
  }

  // -----------------------------------------------------------------------
  // Mail Rate scoring (free model)
  // -----------------------------------------------------------------------

  /// Scores an email's priority (1–5) using the free Llama model.
  /// Returns `null` on failure so the caller can use the heuristic fallback.
  Future<int?> scoreMailRate({
    required String from,
    required String subject,
    required String body,
  }) async {
    final result = await chat(
      systemPrompt: 'You are an email priority scorer. Rate emails 1 to 5 '
          'where 5 = urgent/important/action-needed, 3 = normal, '
          '1 = newsletter/spam/low-priority. '
          'Reply with ONLY a single digit 1-5, nothing else.',
      userPrompt: 'From: $from\n'
          'Subject: $subject\n'
          'Body: ${body.substring(0, body.length.clamp(0, 500))}',
      model: AiConfig.freeModel,
      maxTokens: 5,
      temperature: 0.1,
    );
    if (result == null) return null;
    final match = RegExp(r'[1-5]').firstMatch(result.trim());
    return match != null ? int.parse(match.group(0)!) : null;
  }

  // -----------------------------------------------------------------------
  // Deep reasoning (DeepSeek-R1 — the "desk" model)
  // -----------------------------------------------------------------------

  /// Runs a complex reasoning prompt through DeepSeek-R1. Use this for tasks
  /// that benefit from step-by-step thinking (drafting replies, summarising
  /// long content, planning).
  Future<String?> reason({
    required String prompt,
    int maxTokens = 2048,
  }) async {
    return chat(
      systemPrompt: 'You are a helpful assistant inside OmniCore, an '
          'offline-first productivity app. Think through the user\'s request '
          'carefully and give a clear, concise answer.',
      userPrompt: prompt,
      model: AiConfig.deepModel,
      maxTokens: maxTokens,
      temperature: 0.6,
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  String _mimeTypeForPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }
}

// =============================================================================
// Riverpod provider
// =============================================================================

/// Provides the singleton [NvidiaAiService]. The API key comes from
/// [AiConfig.embeddedKey] (embedded or --dart-define). A runtime override can
/// be stored in the Drift `user_preferences` table under key `nvidia_api_key`.
final nvidiaAiServiceProvider = Provider<NvidiaAiService>((ref) {
  return NvidiaAiService(apiKey: AiConfig.embeddedKey);
});

/// Reads the runtime API-key override (if any) from the local DB.
final nvidiaApiKeyOverrideProvider = FutureProvider<String?>((ref) async {
  final db = ref.watch(dbProvider);
  return db.getPref('nvidia_api_key');
});

/// Whether the AI service has a usable key (embedded, --dart-define, or
/// runtime override) AND the device is online.
final isAiAvailableProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  final override = ref.watch(nvidiaApiKeyOverrideProvider).valueOrNull;
  final service = ref.watch(nvidiaAiServiceProvider);
  final hasKey = (override != null && override.isNotEmpty) ||
      service.apiKey.isNotEmpty;
  return hasKey && connectivity == ConnectivityStatus.online;
});
