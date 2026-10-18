import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/errors/exceptions.dart';
import 'package:costibake_app/core/services/ai_config_service.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/recipes/data/services/gemini_ai_recipe_extractor.dart';

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = {};

  FakeFlutterSecureStorage([Map<String, String>? initial]) {
    if (initial != null) _storage.addAll(initial);
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _storage[key];

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
  }) async =>
      _storage.remove(key);
}

Uint8List createMockDocx(List<String> paragraphs) {
  final archive = Archive();
  final pTags = paragraphs
      .map((p) => '<w:p><w:r><w:t>$p</w:t></w:r></w:p>')
      .join('\n');
  final xmlContent = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $pTags
  </w:body>
</w:document>
''';
  final bytes = utf8.encode(xmlContent);
  archive.addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  group('GeminiAiRecipeExtractor Unit Tests', () {
    late FakeFlutterSecureStorage fakeStorage;
    late AiConfigService configService;

    const validRecipeJsonResponse = '''
{
  "title": "Torta Húmeda de Chocolate",
  "description": "Exquisita torta de chocolate con ganache",
  "yieldPortions": 12,
  "prepTimeMinutes": 30,
  "bakeTimeMinutes": 45,
  "moldType": "Redondo",
  "moldDimension": "22 cm / 9 in",
  "ingredients": [
    {
      "name": "Harina de trigo todo uso",
      "quantity": 250,
      "unit": "g",
      "section": "Bizcocho",
      "notes": "tamizada",
      "rawText": "250g harina de trigo tamizada"
    },
    {
      "name": "Cacao en polvo amargo",
      "quantity": 75,
      "unit": "gr",
      "section": "Bizcocho",
      "notes": "sin azúcar",
      "rawText": "75 gr cacao en polvo"
    },
    {
      "name": "Huevos medianos",
      "quantity": 3,
      "unit": "unidad",
      "section": "Bizcocho",
      "notes": "a temperatura ambiente",
      "rawText": "3 huevos"
    },
    {
      "name": "Leche entera",
      "quantity": 1,
      "unit": "tazas",
      "section": "Bizcocho",
      "notes": null,
      "rawText": "1 taza de leche"
    },
    {
      "name": "Esencia de vainilla",
      "quantity": 2,
      "unit": "cucharadas",
      "section": "Bizcocho",
      "notes": null,
      "rawText": "2 cucharadas de esencia"
    },
    {
      "name": "Chocolate cobertura 70%",
      "quantity": 200,
      "unit": "g",
      "section": "Ganache Cobertura",
      "notes": "picado fino",
      "rawText": "200g chocolate semiamargo"
    }
  ],
  "steps": [
    "Precalentar el horno a 180°C y engrasar el molde.",
    "Tamizar ingredientes secos.",
    "Batir líquidos y agregar secos suavemente.",
    "Hornear por 45 minutos."
  ],
  "notes": "Dejar enfriar completamente antes de desmoldar."
}
''';

    setUp(() {
      fakeStorage = FakeFlutterSecureStorage({'gemini_api_key': 'test-key-123'});
      configService = AiConfigService(secureStorage: fakeStorage);
    });

    test('throws AiConfigException when no API key is available', () async {
      final emptyStorage = FakeFlutterSecureStorage();
      final emptyConfig = AiConfigService(secureStorage: emptyStorage);
      final extractor = GeminiAiRecipeExtractor(aiConfigService: emptyConfig);

      expect(
        () => extractor.extractFromText(text: 'Receta de prueba'),
        throwsA(isA<AiConfigException>()),
      );
    });

    test('throws AiExtractionException when recipe text is empty', () async {
      final extractor = GeminiAiRecipeExtractor(aiConfigService: configService);

      expect(
        () => extractor.extractFromText(text: '    '),
        throwsA(isA<AiExtractionException>()),
      );
    });

    test('extracts recipe correctly from text using content generator', () async {
      final extractor = GeminiAiRecipeExtractor(
        aiConfigService: configService,
        contentGenerator: ({required contents, required apiKey}) async {
          expect(apiKey, equals('test-key-123'));
          return validRecipeJsonResponse;
        },
      );

      final result = await extractor.extractFromText(
        text: 'Receta: Torta Húmeda de Chocolate...',
      );

      expect(result.title, equals('Torta Húmeda de Chocolate'));
      expect(result.yieldPortions, equals(12));
      expect(result.prepTimeMinutes, equals(30));
      expect(result.bakeTimeMinutes, equals(45));
      expect(result.moldType, equals('Redondo'));
      expect(result.moldDimension, equals('22 cm / 9 in'));
      expect(result.ingredients.length, equals(6));
      expect(result.steps.length, equals(4));

      // Check unit normalizations
      // 'gr' normalized to 'g'
      final cacao = result.ingredients[1];
      expect(cacao.name, equals('Cacao en polvo amargo'));
      expect(cacao.quantity, equals(PreciseDecimal.fromString('75')));
      expect(cacao.unit, equals('g'));

      // 'tazas' normalized to 'taza'
      final leche = result.ingredients[3];
      expect(leche.unit, equals('taza'));

      // 'cucharadas' normalized to 'cda'
      final vainilla = result.ingredients[4];
      expect(vainilla.unit, equals('cda'));

      // Section separation
      expect(result.ingredients[5].section, equals('Ganache Cobertura'));
    });

    test('extracts recipe correctly from image data', () async {
      final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00]);

      final extractor = GeminiAiRecipeExtractor(
        aiConfigService: configService,
        contentGenerator: ({required contents, required apiKey}) async {
          expect(contents.isNotEmpty, isTrue);
          return validRecipeJsonResponse;
        },
      );

      final result = await extractor.extractFromImage(
        imageBytes: dummyBytes,
        mimeType: 'image/jpeg',
      );

      expect(result.title, equals('Torta Húmeda de Chocolate'));
      expect(result.ingredients.isNotEmpty, isTrue);
    });

    test('extracts recipe correctly from PDF document', () async {
      final dummyPdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 ...'));

      final extractor = GeminiAiRecipeExtractor(
        aiConfigService: configService,
        contentGenerator: ({required contents, required apiKey}) async {
          expect(contents.isNotEmpty, isTrue);
          return validRecipeJsonResponse;
        },
      );

      final result = await extractor.extractFromPdf(pdfBytes: dummyPdfBytes);
      expect(result.title, equals('Torta Húmeda de Chocolate'));
    });

    test('extracts text from DOCX document and processes recipe', () async {
      final docxBytes = createMockDocx([
        'Receta: Torta de Chocolate',
        'Ingredientes:',
        '250g Harina',
        '3 Huevos',
      ]);

      final extractedText = GeminiAiRecipeExtractor.extractTextFromDocx(docxBytes);
      expect(extractedText, contains('Receta: Torta de Chocolate'));
      expect(extractedText, contains('250g Harina'));

      final extractor = GeminiAiRecipeExtractor(
        aiConfigService: configService,
        contentGenerator: ({required contents, required apiKey}) async {
          return validRecipeJsonResponse;
        },
      );

      final result = await extractor.extractFromDocx(docxBytes: docxBytes);
      expect(result.title, equals('Torta Húmeda de Chocolate'));
    });

    test('throws AiExtractionException on corrupted DOCX', () async {
      final corruptBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      expect(
        () => GeminiAiRecipeExtractor.extractTextFromDocx(corruptBytes),
        throwsA(isA<AiExtractionException>()),
      );
    });

    test('strips Markdown code fences from JSON output', () async {
      const wrappedJson = '```json\n$validRecipeJsonResponse\n```';

      final extractor = GeminiAiRecipeExtractor(
        aiConfigService: configService,
        contentGenerator: ({required contents, required apiKey}) async {
          return wrappedJson;
        },
      );

      final result = await extractor.extractFromText(text: 'Receta...');
      expect(result.title, equals('Torta Húmeda de Chocolate'));
    });

    test('parses fractional quantities like 1/2 properly', () async {
      const jsonWithFractions = '''
{
  "title": "Galletas de Mantequilla",
  "yieldPortions": 24,
  "ingredients": [
    {
      "name": "Mantequilla",
      "quantity": "1/2",
      "unit": "taza"
    }
  ]
}
''';

      final extractor = GeminiAiRecipeExtractor(
        aiConfigService: configService,
        contentGenerator: ({required contents, required apiKey}) async {
          return jsonWithFractions;
        },
      );

      final result = await extractor.extractFromText(text: 'Receta...');
      expect(result.ingredients.first.quantity, equals(PreciseDecimal.fromString('0.5')));
    });

    test('throws AiExtractionException on invalid JSON response', () async {
      final extractor = GeminiAiRecipeExtractor(
        aiConfigService: configService,
        contentGenerator: ({required contents, required apiKey}) async {
          return 'Esto no es un JSON válido';
        },
      );

      expect(
        () => extractor.extractFromText(text: 'Receta...'),
        throwsA(isA<AiExtractionException>()),
      );
    });

    test('defaultCandidateModels includes current active flash models without deprecated 1.5-flash', () {
      expect(GeminiAiRecipeExtractor.defaultCandidateModels, contains('gemini-3.8-flash'));
      expect(GeminiAiRecipeExtractor.defaultCandidateModels, contains('gemini-3.6-flash'));
      expect(GeminiAiRecipeExtractor.defaultCandidateModels, contains('gemini-3.5-flash'));
      expect(GeminiAiRecipeExtractor.defaultCandidateModels, contains('gemini-flash-lite-latest'));
      expect(GeminiAiRecipeExtractor.defaultCandidateModels, isNot(contains('gemini-1.5-flash')));
    });
  });
}

