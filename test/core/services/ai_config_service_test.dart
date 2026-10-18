import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/services/ai_config_service.dart';

class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AiConfigService Precedence and Security Tests', () {
    late _FakeSecureStorage fakeStorage;

    setUp(() {
      fakeStorage = _FakeSecureStorage();
    });

    test('Case 1: No key configured returns null and AiKeySource.none', () async {
      final service = AiConfigService(
        secureStorage: fakeStorage,
        envApiKey: '',
      );

      expect(await service.getApiKey(), isNull);
      expect(await service.hasValidKey(), isFalse);
      expect(await service.getApiKeySource(), equals(AiKeySource.none));
      expect(service.hasBundledKey, isFalse);
      expect(await service.hasCustomKey(), isFalse);
    });

    test('Case 2: Only bundled key configured (Wife mode) returns bundled key and AiKeySource.bundledDefault', () async {
      final service = AiConfigService(
        secureStorage: fakeStorage,
        envApiKey: 'AIzaSy_BUNDLED_KEY_123',
      );

      expect(await service.getApiKey(), equals('AIzaSy_BUNDLED_KEY_123'));
      expect(await service.hasValidKey(), isTrue);
      expect(await service.getApiKeySource(), equals(AiKeySource.bundledDefault));
      expect(service.hasBundledKey, isTrue);
      expect(await service.hasCustomKey(), isFalse);
    });

    test('Case 3: User saves custom key in Settings (Override) takes priority over bundled key', () async {
      final service = AiConfigService(
        secureStorage: fakeStorage,
        envApiKey: 'AIzaSy_BUNDLED_KEY_123',
      );

      // Save custom key
      await service.saveApiKey('AIzaSy_USER_CUSTOM_KEY_999');

      expect(await service.getApiKey(), equals('AIzaSy_USER_CUSTOM_KEY_999'));
      expect(await service.getApiKeySource(), equals(AiKeySource.userCustom));
      expect(service.hasBundledKey, isTrue);
      expect(await service.hasCustomKey(), isTrue);
    });

    test('Case 4: Deleting custom key restores bundled fallback key', () async {
      final service = AiConfigService(
        secureStorage: fakeStorage,
        envApiKey: 'AIzaSy_BUNDLED_KEY_123',
      );

      // Save custom key
      await service.saveApiKey('AIzaSy_USER_CUSTOM_KEY_999');
      expect(await service.getApiKey(), equals('AIzaSy_USER_CUSTOM_KEY_999'));

      // Delete custom key
      await service.deleteApiKey();

      // Now it must fallback to bundled key
      expect(await service.getApiKey(), equals('AIzaSy_BUNDLED_KEY_123'));
      expect(await service.getApiKeySource(), equals(AiKeySource.bundledDefault));
      expect(await service.hasCustomKey(), isFalse);
    });

    test('Saving empty or whitespace string deletes custom key', () async {
      final service = AiConfigService(
        secureStorage: fakeStorage,
        envApiKey: 'AIzaSy_BUNDLED_KEY_123',
      );

      await service.saveApiKey('AIzaSy_CUSTOM');
      expect(await service.hasCustomKey(), isTrue);

      await service.saveApiKey('   ');
      expect(await service.hasCustomKey(), isFalse);
      expect(await service.getApiKey(), equals('AIzaSy_BUNDLED_KEY_123'));
    });

    test('testApiKeyConnection fails gracefully when no key provided', () async {
      final service = AiConfigService(
        secureStorage: fakeStorage,
        envApiKey: '',
      );

      final result = await service.testApiKeyConnection();
      expect(result.isSuccessful, isFalse);
      expect(result.errorMessage, contains('No se ha proporcionado ninguna clave'));
    });

    test('defaultCandidateModels contains active Gemini Flash models', () {
      expect(AiConfigService.defaultCandidateModels, contains('gemini-3.8-flash'));
      expect(AiConfigService.defaultCandidateModels, contains('gemini-3.6-flash'));
      expect(AiConfigService.defaultCandidateModels, contains('gemini-3.5-flash'));
      expect(AiConfigService.defaultCandidateModels, contains('gemini-flash-lite-latest'));
      expect(AiConfigService.defaultCandidateModels, isNot(contains('gemini-1.5-flash')));
    });
  });
}
