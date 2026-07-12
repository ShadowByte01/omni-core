/// NVIDIA NIM AI configuration for OmniCore.
///
/// All AI features (gallery tagging, mail rate scoring, deep reasoning) use
/// the NVIDIA NIM API — an OpenAI-compatible endpoint at
/// `https://integrate.api.nvidia.com/v1`.
///
/// **Models configured:**
/// * [deepModel] — `deepseek-ai/deepseek-r1` (the "desk"/DeepSeek model, for
///   complex reasoning tasks).
/// * [freeModel] — `meta/llama-3.1-8b-instruct` (the free, fast model, for
///   quick tasks like mail rate scoring).
/// * [visionModel] — `meta/llama-3.2-11b-vision-instruct` (for AI gallery
///   photo tagging).
///
/// **API key security:**
/// The key is embedded below for your local build. To avoid shipping it in
/// source, override at build time:
///   `flutter build apk --dart-define=NVIDIA_API_KEY=nvapi-yourkey`
/// You can also override at runtime via the AI Settings sheet (stored in the
/// local Drift DB).
class AiConfig {
  AiConfig._();

  // -----------------------------------------------------------------------
  // API key — embedded for your personal build.
  // Override with: --dart-define=NVIDIA_API_KEY=nvapi-xxxx
  // -----------------------------------------------------------------------
  static const String _embeddedKey =
      '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';

  static const String _defineKey = String.fromEnvironment(
    'NVIDIA_API_KEY',
    defaultValue: '',
  );

  /// The effective API key. --dart-define takes priority, then the embedded
  /// key, then the runtime override (read from Drift prefs by the service).
  static String get embeddedKey =>
      _defineKey.isNotEmpty ? _defineKey : _embeddedKey;

  /// True if a key is available (embedded or via --dart-define).
  static bool get hasEmbeddedKey => embeddedKey.isNotEmpty;

  // -----------------------------------------------------------------------
  // Endpoint
  // -----------------------------------------------------------------------
  static const String baseUrl = 'https://integrate.api.nvidia.com/v1';
  static const String chatEndpoint = '/chat/completions';

  // -----------------------------------------------------------------------
  // Models
  // -----------------------------------------------------------------------

  /// The "desk" model — DeepSeek-R1, a powerful reasoning model for complex
  /// tasks (summarisation, drafting, multi-step analysis).
  static const String deepModel = 'deepseek-ai/deepseek-r1';

  /// The free model — Llama 3.1 8B Instruct. Fast and economical, ideal for
  /// quick single-shot tasks like mail rate scoring.
  static const String freeModel = 'meta/llama-3.1-8b-instruct';

  /// The vision model — Llama 3.2 11B Vision Instruct. Used by the AI Gallery
  /// to analyse photos and produce descriptive tags.
  static const String visionModel = 'meta/llama-3.2-11b-vision-instruct';

  // -----------------------------------------------------------------------
  // Generation defaults
  // -----------------------------------------------------------------------
  static const int defaultMaxTokens = 512;
  static const double defaultTemperature = 0.3;
  static const Duration requestTimeout = Duration(seconds: 30);
}
