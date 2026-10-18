import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service responsible for managing Gemini AI API configuration and credentials.
///
/// Precedence for retrieving the API key:
/// 1. Compile-time environment variable `--dart-define=GEMINI_API_KEY=your_key`
/// 2. Secure storage via [FlutterSecureStorage] (key: `gemini_api_key`)
class AiConfigService {
  static const String _storageKey = 'gemini_api_key';
  static const String _envApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  final FlutterSecureStorage _secureStorage;

  AiConfigService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Retrieves the active Gemini API key if configured, or null otherwise.
  Future<String?> getApiKey() async {
    // 1. Check dart-define environment variable
    if (_envApiKey.trim().isNotEmpty) {
      return _envApiKey.trim();
    }

    // 2. Check FlutterSecureStorage
    try {
      final storedKey = await _secureStorage.read(key: _storageKey);
      if (storedKey != null && storedKey.trim().isNotEmpty) {
        return storedKey.trim();
      }
    } catch (_) {
      // In case platform secure storage is not accessible (e.g. some headless test runners)
      return null;
    }

    return null;
  }

  /// Saves the user-provided Gemini API key securely.
  Future<void> saveApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await deleteApiKey();
      return;
    }
    await _secureStorage.write(key: _storageKey, value: trimmed);
  }

  /// Deletes any stored API key from secure storage.
  Future<void> deleteApiKey() async {
    await _secureStorage.delete(key: _storageKey);
  }

  /// Whether an API key is available (either via env or secure storage).
  Future<bool> hasValidKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }
}
