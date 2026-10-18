import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Origin of the active Gemini API key.
enum AiKeySource {
  /// Custom key saved by the user in device secure storage (Settings).
  userCustom,

  /// Pre-configured fallback key bundled at build time (e.g. config.json).
  bundledDefault,

  /// No key is currently configured.
  none,
}

/// Result of testing a candidate or active Gemini API key with Google servers.
class AiKeyTestResult {
  final bool isSuccessful;
  final String? errorMessage;

  const AiKeyTestResult({
    required this.isSuccessful,
    this.errorMessage,
  });

  factory AiKeyTestResult.success() =>
      const AiKeyTestResult(isSuccessful: true);

  factory AiKeyTestResult.failure(String message) =>
      AiKeyTestResult(isSuccessful: false, errorMessage: message);
}

/// Service responsible for managing Gemini AI API configuration and credentials.
///
/// Precedence for retrieving the API key:
/// 1. Secure storage via [FlutterSecureStorage] (user-custom override from Settings)
/// 2. Compile-time environment variable `--dart-define=GEMINI_API_KEY=your_key`
///    or `--dart-define-from-file=config.json` (bundled default for wife/demo)
/// 3. Returns null if neither is present.
class AiConfigService {
  static const String _storageKey = 'gemini_api_key';
  static const String _defaultEnvApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  final FlutterSecureStorage _secureStorage;
  final String _envApiKey;

  AiConfigService({
    FlutterSecureStorage? secureStorage,
    String? envApiKey,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _envApiKey = envApiKey ?? _defaultEnvApiKey;

  /// Whether a bundled default key was provided at build-time.
  bool get hasBundledKey => _envApiKey.trim().isNotEmpty;

  /// Whether the user has saved a custom override key in secure storage.
  Future<bool> hasCustomKey() async {
    try {
      final storedKey = await _secureStorage.read(key: _storageKey);
      return storedKey != null && storedKey.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Identifies the origin of the active API key.
  Future<AiKeySource> getApiKeySource() async {
    try {
      final storedKey = await _secureStorage.read(key: _storageKey);
      if (storedKey != null && storedKey.trim().isNotEmpty) {
        return AiKeySource.userCustom;
      }
    } catch (_) {
      // In case platform secure storage is not accessible
    }

    if (_envApiKey.trim().isNotEmpty) {
      return AiKeySource.bundledDefault;
    }

    return AiKeySource.none;
  }

  /// Retrieves the active Gemini API key if configured, or null otherwise.
  Future<String?> getApiKey() async {
    // 1. Check FlutterSecureStorage first (user override has highest priority)
    try {
      final storedKey = await _secureStorage.read(key: _storageKey);
      if (storedKey != null && storedKey.trim().isNotEmpty) {
        return storedKey.trim();
      }
    } catch (_) {
      // In case platform secure storage is not accessible
    }

    // 2. Fall back to compile-time environment variable (bundled default)
    if (_envApiKey.trim().isNotEmpty) {
      return _envApiKey.trim();
    }

    return null;
  }

  /// Saves the user-provided Gemini API key securely in device storage.
  Future<void> saveApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await deleteApiKey();
      return;
    }
    await _secureStorage.write(key: _storageKey, value: trimmed);
  }

  /// Deletes any stored custom key from secure storage, reverting to bundled fallback.
  Future<void> deleteApiKey() async {
    try {
      await _secureStorage.delete(key: _storageKey);
    } catch (_) {}
  }

  /// Whether any valid API key is available (either via secure storage or bundled default).
  Future<bool> hasValidKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Verifies connectivity and key validity against Google Gemini API using a lightweight token check.
  Future<AiKeyTestResult> testApiKeyConnection([String? candidateKey]) async {
    final key = (candidateKey != null && candidateKey.trim().isNotEmpty)
        ? candidateKey.trim()
        : await getApiKey();

    if (key == null || key.isEmpty) {
      return AiKeyTestResult.failure(
        'No se ha proporcionado ninguna clave para probar.',
      );
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: key,
      );

      final response = await model.countTokens([Content.text('ping')]);
      if (response.totalTokens >= 0) {
        return AiKeyTestResult.success();
      } else {
        return AiKeyTestResult.failure('Respuesta inesperada de Gemini.');
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('API_KEY_INVALID') ||
          errStr.contains('API key not valid')) {
        return AiKeyTestResult.failure(
          'La clave de API ingresada no es válida o ha sido revocada por Google.',
        );
      } else if (errStr.contains('429') ||
          errStr.contains('RESOURCE_EXHAUSTED')) {
        return AiKeyTestResult.failure(
          'Límite de solicitudes momentáneo alcanzado (Nivel Gratuito). La clave es válida, pero debes esperar unos segundos.',
        );
      }
      return AiKeyTestResult.failure('Error de conexión con Gemini: $errStr');
    }
  }
}
