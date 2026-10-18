import 'dart:typed_data';
import '../entities/ai_recipe_extraction.dart';

/// Contract for AI multimodal recipe extraction services.
/// Extracts recipe metadata, portions, times, and ingredients from images, PDFs, DOCX files, or text.
abstract class AiRecipeExtractor {
  /// Analyzes an image (JPEG, PNG, HEIC, WEBP) containing a recipe.
  Future<AiRecipeExtraction> extractFromImage({
    required Uint8List imageBytes,
    required String mimeType,
  });

  /// Analyzes a PDF document containing a recipe.
  Future<AiRecipeExtraction> extractFromPdf({
    required Uint8List pdfBytes,
  });

  /// Analyzes a Word DOCX document containing a recipe.
  Future<AiRecipeExtraction> extractFromDocx({
    required Uint8List docxBytes,
  });

  /// Analyzes raw plain text containing a recipe.
  Future<AiRecipeExtraction> extractFromText({
    required String text,
  });
}
