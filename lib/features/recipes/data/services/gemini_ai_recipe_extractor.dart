import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../../core/constants/culinary_units.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/ai_config_service.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../domain/entities/ai_recipe_extraction.dart';
import '../../domain/services/ai_recipe_extractor.dart';

/// Function signature for generating content from Gemini, allowing mock injection in tests.
typedef ContentGenerator = Future<String> Function({
  required List<Content> contents,
  required String apiKey,
});

/// Implementation of [AiRecipeExtractor] powered by Google Gemini Flash.
/// Supports extracting structured recipe data from Photos (JPEG/PNG/WEBP), PDFs, and DOCX documents
/// with an automatic multi-model fallback chain across active Gemini Flash models.
class GeminiAiRecipeExtractor implements AiRecipeExtractor {
  final AiConfigService _aiConfigService;
  final ContentGenerator? _contentGenerator;
  final List<String> _candidateModels;

  /// Resilient list of Gemini Flash models tried in order of capability and stability.
  static const List<String> defaultCandidateModels = [
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-flash-lite-latest',
  ];

  GeminiAiRecipeExtractor({
    required AiConfigService aiConfigService,
    ContentGenerator? contentGenerator,
    List<String>? candidateModels,
  })  : _aiConfigService = aiConfigService,
        _contentGenerator = contentGenerator,
        _candidateModels = candidateModels ?? defaultCandidateModels;

  static final Schema recipeExtractionSchema = Schema.object(
    properties: {
      'title': Schema.string(description: 'Nombre de la receta'),
      'description': Schema.string(
        description: 'Breve descripción de la receta',
        nullable: true,
      ),
      'yieldPortions': Schema.integer(
        description: 'Cantidad de porciones, unidades o rendimiento total',
      ),
      'prepTimeMinutes': Schema.integer(
        description: 'Tiempo de preparación en minutos',
      ),
      'bakeTimeMinutes': Schema.integer(
        description: 'Tiempo de horneado o cocción en minutos',
      ),
      'moldType': Schema.string(
        description:
            'Tipo de molde si aplica (ej. Redondo, Rectangular, Cuadrado, Plancha)',
        nullable: true,
      ),
      'moldDimension': Schema.string(
        description:
            'Dimensiones del molde si aplica (ej. 20 cm, 22 cm, 8 pulgadas)',
        nullable: true,
      ),
      'ingredients': Schema.array(
        items: Schema.object(
          properties: {
            'name': Schema.string(
              description:
                  'Nombre limpio del ingrediente (ej. Harina de trigo, Azúcar refinada, Mantequilla sin sal, Huevos)',
            ),
            'quantity': Schema.number(
              description:
                  'Cantidad numérica del ingrediente (ej. 250, 2, 1.5)',
            ),
            'unit': Schema.string(
              description:
                  'Unidad de medida (ej. g, kg, ml, l, taza, cda, cdta, oz, lb, unidad)',
            ),
            'section': Schema.string(
              description:
                  'Sección de la receta (ej. Base, Bizcocho, Relleno, Cobertura, Almíbar, Decoración)',
            ),
            'notes': Schema.string(
              description:
                  'Notas o detalles del ingrediente (ej. tamizada, a temperatura ambiente)',
              nullable: true,
            ),
            'rawText': Schema.string(
              description:
                  'Texto original exacto del ingrediente en la receta',
              nullable: true,
            ),
          },
          requiredProperties: ['name', 'quantity', 'unit'],
        ),
        description: 'Lista completa de ingredientes requeridos',
      ),
      'steps': Schema.array(
        items: Schema.string(),
        description: 'Pasos o instrucciones de elaboración secuenciales',
        nullable: true,
      ),
      'notes': Schema.string(
        description: 'Notas, tips u observaciones adicionales de la receta',
        nullable: true,
      ),
    },
    requiredProperties: ['title', 'yieldPortions', 'ingredients'],
  );

  static const String _promptInstructions = '''
Eres un chef pastelero experto y auditor de costos gastronómicos.
Tu tarea es analizar la imagen o documento de la receta y extraer minuciosamente todos sus datos estructurados en formato JSON.

REGLAS DE EXTRACCIÓN:
1. Extrae el título de la receta con precisión.
2. Identifica el rendimiento o porciones (yieldPortions). Si la receta es para unidades individuales (ej. cupcakes, galletas, muffins, vasitos/shots de postre como Carlota) y no especifica cantidad, infiere el rendimiento estándar por lote (ej. 12) o según los ingredientes. Si es una torta, pastel o pay entero y no se indica, usa 1.
3. Identifica tiempos de preparación (prepTimeMinutes) y horneado (bakeTimeMinutes). Si no se indican, usa 0.
4. Identifica tipo de molde (moldType) y dimensiones (moldDimension) si se mencionan.
5. Insumos/Ingredientes:
   - Extrae CADA ingrediente sin omitir ninguno.
   - Normaliza el nombre (ej: "harina leudante", "azúcar glass", "mantequilla sin sal").
   - Cantidad exacta numérica (si está en fracción como 1/2, conviértela a 0.5).
   - Unidad estándar (g, kg, ml, l, taza, cda, cdta, oz, lb, unidad). Si no tiene unidad explícita (ej. "3 huevos"), usa "unidad".
   - Identifica la sección de la receta a la que pertenece (ej. "Bizcocho", "Relleno", "Cobertura", "Base"). Si no hay secciones, usa "Base".
   - Extrae cualquier nota específica del ingrediente (ej. "tamizada", "derretida").
   - Incluye el texto original exacto en rawText.
6. Extrae los pasos e instrucciones en orden.
7. Devuelve ÚNICAMENTE el JSON estructurado respetando estrictamente el schema.
''';

  @override
  Future<AiRecipeExtraction> extractFromImage({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final normalizedMime = _normalizeImageMimeType(mimeType);
    final contents = [
      Content.multi([
        DataPart(normalizedMime, imageBytes),
        TextPart(_promptInstructions),
      ]),
    ];

    return _generateAndParse(contents);
  }

  @override
  Future<AiRecipeExtraction> extractFromPdf({
    required Uint8List pdfBytes,
  }) async {
    final contents = [
      Content.multi([
        DataPart('application/pdf', pdfBytes),
        TextPart(_promptInstructions),
      ]),
    ];

    return _generateAndParse(contents);
  }

  @override
  Future<AiRecipeExtraction> extractFromDocx({
    required Uint8List docxBytes,
  }) async {
    final text = extractTextFromDocx(docxBytes);
    return extractFromText(text: text);
  }

  @override
  Future<AiRecipeExtraction> extractFromText({
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const AiExtractionException(
        'El texto de la receta está vacío y no se puede analizar.',
      );
    }

    final contents = [
      Content.text(
        '$_promptInstructions\n\nCONTENIDO DE LA RECETA A ANALIZAR:\n$trimmed',
      ),
    ];

    return _generateAndParse(contents);
  }

  /// Extracts plain text from a DOCX file by parsing `word/document.xml`.
  static String extractTextFromDocx(Uint8List docxBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(docxBytes);
      final documentXmlFile = archive.findFile('word/document.xml');
      if (documentXmlFile == null) {
        throw const AiExtractionException(
          'El archivo DOCX no contiene el documento principal (word/document.xml).',
        );
      }

      final contentBytes = documentXmlFile.content as List<int>;
      final xmlContent = utf8.decode(contentBytes, allowMalformed: true);

      final paragraphRegex = RegExp(r'<w:p(?:\s+[^>]*)?>([\s\S]*?)<\/w:p>');
      final textRegex = RegExp(r'<w:t(?:\s+[^>]*)?>([\s\S]*?)<\/w:t>');

      final buffer = StringBuffer();
      final paragraphs = paragraphRegex.allMatches(xmlContent);

      for (final pMatch in paragraphs) {
        final pContent = pMatch.group(1) ?? '';
        final texts = textRegex
            .allMatches(pContent)
            .map((m) => m.group(1) ?? '')
            .join();
        final decoded = _decodeXmlEntities(texts).trim();
        if (decoded.isNotEmpty) {
          buffer.writeln(decoded);
        }
      }

      final result = buffer.toString().trim();
      if (result.isEmpty) {
        throw const AiExtractionException(
          'No se pudo extraer texto del documento DOCX. El archivo parece estar vacío.',
        );
      }
      return result;
    } catch (e) {
      if (e is AiExtractionException) rethrow;
      throw AiExtractionException(
        'Error al procesar el archivo DOCX: $e',
        e,
      );
    }
  }

  static String _decodeXmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  String _normalizeImageMimeType(String mime) {
    final lower = mime.toLowerCase().trim();
    if (lower == 'jpg' ||
        lower == 'jpeg' ||
        lower.endsWith('/jpeg') ||
        lower.endsWith('/jpg')) {
      return 'image/jpeg';
    }
    if (lower == 'png' || lower.endsWith('/png')) {
      return 'image/png';
    }
    if (lower == 'webp' || lower.endsWith('/webp')) {
      return 'image/webp';
    }
    if (lower == 'heic' || lower.endsWith('/heic')) {
      return 'image/heic';
    }
    if (lower == 'heif' || lower.endsWith('/heif')) {
      return 'image/heif';
    }
    if (lower.contains('/')) return lower;
    return 'image/jpeg';
  }

  Future<AiRecipeExtraction> _generateAndParse(List<Content> contents) async {
    final apiKey = await _aiConfigService.getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiConfigException(
        'No se ha configurado la API Key de Google Gemini. Por favor configúrala en Ajustes o mediante --dart-define=GEMINI_API_KEY=tu_clave.',
      );
    }

    String responseText;
    try {
      final generator = _contentGenerator;
      if (generator != null) {
        responseText = await generator(
          contents: contents,
          apiKey: apiKey,
        );
      } else {
        Object? lastError;
        String? successfulText;

        for (final modelName in _candidateModels) {
          try {
            final model = GenerativeModel(
              model: modelName,
              apiKey: apiKey,
              generationConfig: GenerationConfig(
                responseMimeType: 'application/json',
                responseSchema: recipeExtractionSchema,
                temperature: 0.1,
              ),
            );
            final response = await model.generateContent(contents);
            final text = response.text;
            if (text != null && text.trim().isNotEmpty) {
              successfulText = text;
              break;
            }
          } catch (e) {
            lastError = e;
            final errStr = e.toString();
            if (errStr.contains('API_KEY_INVALID') ||
                errStr.contains('API key not valid')) {
              throw AiExtractionException(
                'La clave de API ingresada no es válida o ha sido revocada por Google.',
                e,
              );
            }
            // Continue to the next candidate model (e.g., deprecated 404, temporary 503 spike, etc.)
          }
        }

        if (successfulText == null) {
          throw AiExtractionException(
            'Error de comunicación con el servicio de IA Gemini: $lastError',
            lastError,
          );
        }
        responseText = successfulText;
      }
    } catch (e) {
      if (e is AiConfigException || e is AiExtractionException) rethrow;
      throw AiExtractionException(
        'Error de comunicación con el servicio de IA Gemini: $e',
        e,
      );
    }

    return _parseJsonResponse(responseText);
  }

  AiRecipeExtraction _parseJsonResponse(String rawResponse) {
    try {
      var cleanJson = rawResponse.trim();
      // Remove Markdown code blocks if present
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final decoded = jsonDecode(cleanJson);
      if (decoded is! Map<String, dynamic>) {
        throw const AiExtractionException(
          'La respuesta de la IA no tiene el formato JSON de objeto esperado.',
        );
      }

      final title = decoded['title'] as String? ?? 'Receta Extraída con IA';
      final description = decoded['description'] as String?;
      final yieldPortions = (decoded['yieldPortions'] as num?)?.toInt() ?? 1;
      final prepTimeMinutes =
          (decoded['prepTimeMinutes'] as num?)?.toInt() ?? 0;
      final bakeTimeMinutes =
          (decoded['bakeTimeMinutes'] as num?)?.toInt() ?? 0;
      final moldType = decoded['moldType'] as String?;
      final moldDimension = decoded['moldDimension'] as String?;
      final rawSteps = decoded['steps'] as List<dynamic>? ?? [];
      final steps = rawSteps.map((s) => s.toString()).toList();
      final notes = decoded['notes'] as String?;

      final rawIngredients = decoded['ingredients'] as List<dynamic>? ?? [];
      final ingredients = <AiExtractedIngredient>[];

      for (final item in rawIngredients) {
        if (item is Map<String, dynamic>) {
          final name = item['name'] as String? ?? '';
          final rawQty = item['quantity'];
          final parsedQty = _parseQuantity(rawQty);
          final rawUnit = (item['unit'] as String? ?? 'g').trim();
          final canonicalUnit = _normalizeUnit(rawUnit);
          final section = (item['section'] as String? ?? 'Base').trim();
          final itemNotes = item['notes'] as String?;
          final rawText = item['rawText'] as String?;

          ingredients.add(
            AiExtractedIngredient(
              name: name,
              quantity: parsedQty,
              unit: canonicalUnit,
              section: section.isNotEmpty ? section : 'Base',
              notes: itemNotes,
              rawText: rawText,
            ),
          );
        }
      }

      return AiRecipeExtraction(
        title: title,
        description: description,
        yieldPortions: yieldPortions > 0 ? yieldPortions : 1,
        prepTimeMinutes: prepTimeMinutes >= 0 ? prepTimeMinutes : 0,
        bakeTimeMinutes: bakeTimeMinutes >= 0 ? bakeTimeMinutes : 0,
        moldType: moldType,
        moldDimension: moldDimension,
        ingredients: ingredients,
        steps: steps,
        notes: notes,
        rawResponse: rawResponse,
      );
    } catch (e) {
      if (e is AiExtractionException) rethrow;
      throw AiExtractionException(
        'Error al interpretar el resultado JSON de la receta: $e',
        e,
      );
    }
  }

  PreciseDecimal _parseQuantity(dynamic val) {
    if (val == null) return PreciseDecimal.one;
    if (val is num) {
      return PreciseDecimal.tryParse(val.toString()) ?? PreciseDecimal.one;
    }
    final str = val.toString().trim();
    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length == 2) {
        final numerator = double.tryParse(parts[0].trim());
        final denominator = double.tryParse(parts[1].trim());
        if (numerator != null && denominator != null && denominator != 0) {
          final result = numerator / denominator;
          return PreciseDecimal.tryParse(result.toString()) ??
              PreciseDecimal.one;
        }
      }
    }
    return PreciseDecimal.tryParse(str) ?? PreciseDecimal.one;
  }

  String _normalizeUnit(String rawUnit) {
    final parsed = CulinaryUnit.tryParse(rawUnit);
    if (parsed != null) {
      return parsed.symbol;
    }
    return rawUnit.toLowerCase().trim();
  }
}
