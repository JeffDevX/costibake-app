import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/services/ai_config_service.dart';

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = {};

  FakeFlutterSecureStorage();

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
}

void main() {
  group('AiConfigService Unit Tests', () {
    late FakeFlutterSecureStorage fakeStorage;
    late AiConfigService service;

    setUp(() {
      fakeStorage = FakeFlutterSecureStorage();
      service = AiConfigService(secureStorage: fakeStorage);
    });

    test('returns null when no key is configured', () async {
      expect(await service.getApiKey(), isNull);
      expect(await service.hasValidKey(), isFalse);
    });

    test('saves and retrieves API key correctly in secure storage', () async {
      await service.saveApiKey('AIzaSyTestApiKey12345');

      expect(await service.getApiKey(), equals('AIzaSyTestApiKey12345'));
      expect(await service.hasValidKey(), isTrue);
    });

    test('trims whitespaces when saving API key', () async {
      await service.saveApiKey('   AIzaSyTrimmedKey   ');

      expect(await service.getApiKey(), equals('AIzaSyTrimmedKey'));
    });

    test('deletes key when saving empty string', () async {
      await service.saveApiKey('AIzaSyKey');
      expect(await service.hasValidKey(), isTrue);

      await service.saveApiKey('   ');
      expect(await service.getApiKey(), isNull);
      expect(await service.hasValidKey(), isFalse);
    });

    test('deletes key explicitly', () async {
      await service.saveApiKey('AIzaSyKey');
      expect(await service.hasValidKey(), isTrue);

      await service.deleteApiKey();
      expect(await service.getApiKey(), isNull);
      expect(await service.hasValidKey(), isFalse);
    });
  });
}
