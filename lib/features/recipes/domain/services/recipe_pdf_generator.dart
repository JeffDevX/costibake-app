import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/utils/precise_decimal.dart';
import '../../../costing/domain/entities/cost_breakdown.dart';
import '../../../costing/domain/entities/pricing_strategy.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../entities/recipe.dart';
import '../entities/recipe_pdf_document_type.dart';

/// Pure domain service that generates high-fidelity PDF documents for pastry recipes (JEF-26, RF-SYS-27).
/// Supports two distinct operational modes:
/// 1. `productionSheet`: Kitchen assistant sheet with quantities and instructions, strictly omitting all financial numbers (BR-EXP-02).
/// 2. `financialSheet`: Executive cost sheet with full integral quadruple cost breakdown, markup, and dual pricing (BR-EXP-03).
class RecipePdfGenerator {
  static const PdfColor _primaryCaramel = PdfColor.fromInt(0xFFC06B3E);
  static const PdfColor _primaryDarkCaramel = PdfColor.fromInt(0xFF994D25);
  static const PdfColor _butterCream = PdfColor.fromInt(0xFFFFF9F0);
  static const PdfColor _textEspresso = PdfColor.fromInt(0xFF2C221E);
  static const PdfColor _textMuted = PdfColor.fromInt(0xFF6B5E57);
  static const PdfColor _borderSubtle = PdfColor.fromInt(0xFFE6DEC8);
  static const PdfColor _costRed = PdfColor.fromInt(0xFFC62828);
  static const PdfColor _costRedLight = PdfColor.fromInt(0xFFFFEBEE);
  static const PdfColor _profitGreen = PdfColor.fromInt(0xFF2E7D32);
  static const PdfColor _profitGreenLight = PdfColor.fromInt(0xFFE8F5E9);

  /// Generates the raw PDF bytes for a given recipe and document type.
  static Future<Uint8List> generatePdf({
    required Recipe recipe,
    required BusinessConfig config,
    required CostBreakdown costBreakdown,
    required RecipePdfDocumentType documentType,
  }) async {
    final doc = buildPdfDocument(
      recipe: recipe,
      config: config,
      costBreakdown: costBreakdown,
      documentType: documentType,
    );
    return await doc.save();
  }

  /// Builds the `pw.Document` instance without rendering to bytes.
  static pw.Document buildPdfDocument({
    required Recipe recipe,
    required BusinessConfig config,
    required CostBreakdown costBreakdown,
    required RecipePdfDocumentType documentType,
  }) {
    final pdf = pw.Document(
      title: '${recipe.name} - ${documentType == RecipePdfDocumentType.productionSheet ? 'Ficha de Produccion' : 'Ficha Tecnica Financiera'}',
      author: config.businessName,
      creator: 'CostiBake - RecetarioApp',
    );

    final fontBase = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontOblique = pw.Font.helveticaOblique();

    final theme = pw.ThemeData.withFont(
      base: fontBase,
      bold: fontBold,
      italic: fontOblique,
    );

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        header: (context) => _buildHeader(
          context: context,
          recipe: recipe,
          config: config,
          documentType: documentType,
        ),
        footer: (context) => _buildFooter(context: context, config: config),
        build: (context) {
          if (documentType == RecipePdfDocumentType.productionSheet) {
            return _buildProductionSheetContent(
              recipe: recipe,
            );
          } else {
            return _buildFinancialSheetContent(
              recipe: recipe,
              config: config,
              breakdown: costBreakdown,
            );
          }
        },
      ),
    );

    return pdf;
  }

  // =========================================================================
  // HEADER & FOOTER
  // =========================================================================

  static pw.Widget _buildHeader({
    required pw.Context context,
    required Recipe recipe,
    required BusinessConfig config,
    required RecipePdfDocumentType documentType,
  }) {
    final isProduction = documentType == RecipePdfDocumentType.productionSheet;
    final title = isProduction
        ? 'FICHA DE PRODUCCIÓN CULINARIA'
        : 'FICHA TÉCNICA FINANCIERA Y DE COSTEO';
    final subtitle = isProduction
        ? 'Taller de Cocina | Uso Interno Operativo (Confidencialidad de Costos)'
        : 'Administración y Finanzas | Costeo Paramétrico Integral';

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormat.format(DateTime.now());

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _primaryCaramel, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  config.businessName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryDarkCaramel,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _textEspresso,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  subtitle,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: isProduction ? _butterCream : _profitGreenLight,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(
                    color: isProduction ? _borderSubtle : _profitGreen,
                  ),
                ),
                child: pw.Text(
                  isProduction ? 'ROL: PRODUCCIÓN' : 'ROL: GERENCIA / COSTOS',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: isProduction ? _primaryDarkCaramel : _profitGreen,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Emisión: $formattedDate',
                style: const pw.TextStyle(fontSize: 8, color: _textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter({
    required pw.Context context,
    required BusinessConfig config,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _borderSubtle, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${config.businessName} | Generado con CostiBake (Sistema Offline-First)',
            style: const pw.TextStyle(fontSize: 8, color: _textMuted),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _textMuted),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. FICHA DE PRODUCCIÓN CULINARIA (BR-EXP-02)
  // =========================================================================

  static List<pw.Widget> _buildProductionSheetContent({
    required Recipe recipe,
  }) {
    return [
      _buildRecipeGeneralCard(recipe: recipe, isProduction: true),
      pw.SizedBox(height: 12),

      if (recipe.isIncomplete) ...[
        _buildIncompleteWarningBanner(
          message:
              'ATENCIÓN COCINA: Esta receta tiene insumos marcados para revisión o eliminados. '
              'Verifique con el encargado antes de iniciar la producción.',
        ),
        pw.SizedBox(height: 12),
      ],

      // Tabla de ingredientes
      _buildSectionHeader('1. INGREDIENTES E INSUMOS DIRECTOS'),
      pw.SizedBox(height: 6),
      _buildProductionIngredientsTable(recipe),
      pw.SizedBox(height: 14),

      // Sub-recetas modulares (si existen)
      if (recipe.subRecipes.isNotEmpty) ...[
        _buildSectionHeader('2. SUB-RECETAS Y COMPONENTES MODULARES'),
        pw.SizedBox(height: 6),
        _buildProductionSubRecipesTable(recipe),
        pw.SizedBox(height: 14),
      ],

      // Empaques requeridos
      if (recipe.packaging.isNotEmpty) ...[
        _buildSectionHeader('3. MATERIALES DE EMPAQUE Y PRESENTACIÓN'),
        pw.SizedBox(height: 6),
        _buildProductionPackagingTable(recipe),
        pw.SizedBox(height: 14),
      ],

      // Notas e instrucciones culinarias
      if (recipe.description != null && recipe.description!.trim().isNotEmpty) ...[
        _buildSectionHeader('4. INSTRUCCIONES Y NOTAS DE PREPARACIÓN'),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _butterCream,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: _borderSubtle),
          ),
          child: pw.Text(
            recipe.description!.trim(),
            style: const pw.TextStyle(fontSize: 9, color: _textEspresso, lineSpacing: 1.3),
          ),
        ),
      ],
    ];
  }

  static pw.Widget _buildProductionIngredientsTable(Recipe recipe) {
    if (recipe.ingredients.isEmpty) {
      return pw.Text(
        'No se han registrado ingredientes en esta receta.',
        style: const pw.TextStyle(fontSize: 9, color: _textMuted),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _butterCream),
        children: [
          _tableCell('Ingrediente / Insumo', isHeader: true, flex: 4),
          _tableCell('Componente / Sección', isHeader: true, flex: 3),
          _tableCell('Cantidad Exacta', isHeader: true, flex: 3, align: pw.TextAlign.right),
          _tableCell('Observaciones', isHeader: true, flex: 3),
        ],
      ),
    ];

    for (var i = 0; i < recipe.ingredients.length; i++) {
      final ing = recipe.ingredients[i];
      final isEven = i % 2 == 0;
      final isOrphan = ing.isOrphaned;

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isOrphan
                ? _costRedLight
                : isEven
                    ? PdfColors.white
                    : const PdfColor(0.98, 0.98, 0.98),
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    ing.cleanHistoricalName,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: isOrphan ? _costRed : _textEspresso,
                    ),
                  ),
                  if (isOrphan)
                    pw.Text(
                      '[!] [REQUIERE REVISIÓN - ELIMINADO]',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: _costRed,
                      ),
                    ),
                ],
              ),
            ),
            _tableCell(ing.section, flex: 3),
            _tableCell(
              '${ing.quantity.toStringAsFixed(2)} ${ing.unit}',
              flex: 3,
              align: pw.TextAlign.right,
              bold: true,
            ),
            _tableCell(ing.notes ?? '-', flex: 3, muted: true),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _borderSubtle, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(3),
        3: pw.FlexColumnWidth(3),
      },
      children: rows,
    );
  }

  static pw.Widget _buildProductionSubRecipesTable(Recipe recipe) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _butterCream),
        children: [
          _tableCell('Sub-receta / Componente Base', isHeader: true, flex: 5),
          _tableCell('Sección Destino', isHeader: true, flex: 3),
          _tableCell('Porciones / Factor', isHeader: true, flex: 3, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (var i = 0; i < recipe.subRecipes.length; i++) {
      final sub = recipe.subRecipes[i];
      final isEven = i % 2 == 0;
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? PdfColors.white : const PdfColor(0.98, 0.98, 0.98),
          ),
          children: [
            _tableCell(sub.childRecipeName, flex: 5, bold: true),
            _tableCell(sub.section, flex: 3),
            _tableCell(
              '${sub.quantityFactor.toStringAsFixed(2)} lote(s)',
              flex: 3,
              align: pw.TextAlign.right,
              bold: true,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _borderSubtle, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(3),
      },
      children: rows,
    );
  }

  static pw.Widget _buildProductionPackagingTable(Recipe recipe) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _butterCream),
        children: [
          _tableCell('Material de Empaque / Descartable', isHeader: true, flex: 7),
          _tableCell('Cantidad Requerida', isHeader: true, flex: 3, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (var i = 0; i < recipe.packaging.length; i++) {
      final pack = recipe.packaging[i];
      final isEven = i % 2 == 0;
      final isOrphan = pack.isOrphaned;

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isOrphan
                ? _costRedLight
                : isEven
                    ? PdfColors.white
                    : const PdfColor(0.98, 0.98, 0.98),
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    pack.cleanHistoricalName,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: isOrphan ? _costRed : _textEspresso,
                    ),
                  ),
                  if (isOrphan)
                    pw.Text(
                      '[!] [REQUIERE REVISIÓN - ELIMINADO]',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: _costRed,
                      ),
                    ),
                ],
              ),
            ),
            _tableCell(
              '${pack.pieceQuantity} pz',
              flex: 3,
              align: pw.TextAlign.right,
              bold: true,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _borderSubtle, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(7),
        1: pw.FlexColumnWidth(3),
      },
      children: rows,
    );
  }

  // =========================================================================
  // 2. FICHA TÉCNICA FINANCIERA (BR-EXP-03)
  // =========================================================================

  static List<pw.Widget> _buildFinancialSheetContent({
    required Recipe recipe,
    required BusinessConfig config,
    required CostBreakdown breakdown,
  }) {
    final currency = config.currencySymbol;

    return [
      _buildRecipeGeneralCard(recipe: recipe, isProduction: false),
      pw.SizedBox(height: 12),

      if (recipe.isIncomplete) ...[
        _buildIncompleteWarningBanner(
          message:
              '[!] RECETA EN ESTADO INCOMPLETO (BR-FRC-03 / BR-EXP-04): '
              'Esta receta contiene insumos huérfanos o eliminados del catálogo. '
              'El costo integral y los precios de venta sugeridos están inhabilitados o subestimados '
              'hasta que asigne los insumos sustitutos correspondientes en la aplicación.',
        ),
        pw.SizedBox(height: 12),
      ],

      // 1. Insumos con costos
      _buildSectionHeader('1. DESGLOSE DE MATERIAS PRIMAS (CI)'),
      pw.SizedBox(height: 6),
      _buildFinancialIngredientsTable(recipe, currency),
      pw.SizedBox(height: 12),

      // 2. Sub-recetas (si existen)
      if (recipe.subRecipes.isNotEmpty) ...[
        _buildSectionHeader('2. COMPONENTES Y SUB-RECETAS MODULARES'),
        pw.SizedBox(height: 6),
        _buildFinancialSubRecipesTable(recipe, currency),
        pw.SizedBox(height: 12),
      ],

      // 3. Empaques con costos
      if (recipe.packaging.isNotEmpty) ...[
        _buildSectionHeader('3. MATERIALES DE EMPAQUE Y DESCARTABLES (CE)'),
        pw.SizedBox(height: 6),
        _buildFinancialPackagingTable(recipe, currency),
        pw.SizedBox(height: 12),
      ],

      // 4. Mano de Obra y Overhead
      _buildSectionHeader('4. MANO DE OBRA (CMO) Y COSTOS INDIRECTOS / OVERHEAD (COH)'),
      pw.SizedBox(height: 6),
      _buildLaborAndOverheadCard(recipe, config, breakdown),
      pw.SizedBox(height: 14),

      // 5. Consolidación Financiera y Precios de Venta
      _buildSectionHeader('5. CONSOLIDACIÓN FINANCIERA Y ESTRATEGIA DE PRECIOS'),
      pw.SizedBox(height: 6),
      _buildFinancialSummaryAndPricingCard(recipe, config, breakdown),
    ];
  }

  static pw.Widget _buildFinancialIngredientsTable(Recipe recipe, String currency) {
    if (recipe.ingredients.isEmpty) {
      return pw.Text(
        'No se han registrado ingredientes en esta receta.',
        style: const pw.TextStyle(fontSize: 9, color: _textMuted),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _butterCream),
        children: [
          _tableCell('Insumo', isHeader: true, flex: 4),
          _tableCell('Sección', isHeader: true, flex: 2),
          _tableCell('Cantidad', isHeader: true, flex: 2, align: pw.TextAlign.right),
          _tableCell('Costo Base', isHeader: true, flex: 2, align: pw.TextAlign.right),
          _tableCell('Subtotal', isHeader: true, flex: 2, align: pw.TextAlign.right),
        ],
      ),
    ];

    PreciseDecimal total = PreciseDecimal.zero;

    for (var i = 0; i < recipe.ingredients.length; i++) {
      final ing = recipe.ingredients[i];
      final isEven = i % 2 == 0;
      final isOrphan = ing.isOrphaned;
      final cost = ing.calculateItemCost();
      total += cost;

      final baseUnit = ing.baseUnit ?? ing.unit;

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isOrphan
                ? _costRedLight
                : isEven
                    ? PdfColors.white
                    : const PdfColor(0.98, 0.98, 0.98),
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    ing.cleanHistoricalName,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: isOrphan ? _costRed : _textEspresso,
                    ),
                  ),
                  if (isOrphan)
                    pw.Text(
                      '[!] [HUÉRFANO - \$0.00]',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: _costRed,
                      ),
                    ),
                ],
              ),
            ),
            _tableCell(ing.section, flex: 2),
            _tableCell(
              '${ing.quantity.toStringAsFixed(2)} ${ing.unit}',
              flex: 2,
              align: pw.TextAlign.right,
            ),
            _tableCell(
              isOrphan
                  ? '$currency 0.00'
                  : '$currency${ing.unitCost.toStringAsFixed(4)}/$baseUnit',
              flex: 2,
              align: pw.TextAlign.right,
              muted: true,
            ),
            _tableCell(
              '$currency${cost.toStringAsFixed(2)}',
              flex: 2,
              align: pw.TextAlign.right,
              bold: true,
              textColor: isOrphan ? _costRed : _textEspresso,
            ),
          ],
        ),
      );
    }

    // Fila de Total Insumos
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _butterCream),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              'SUBTOTAL INSUMOS DIRECTOS (CI)',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _primaryDarkCaramel,
              ),
            ),
          ),
          _tableCell('', flex: 2),
          _tableCell('', flex: 2),
          _tableCell('', flex: 2),
          _tableCell(
            '$currency${total.toStringAsFixed(2)}',
            flex: 2,
            align: pw.TextAlign.right,
            bold: true,
            textColor: _primaryDarkCaramel,
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _borderSubtle, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
        4: pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  static pw.Widget _buildFinancialSubRecipesTable(Recipe recipe, String currency) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _butterCream),
        children: [
          _tableCell('Sub-receta', isHeader: true, flex: 4),
          _tableCell('Sección', isHeader: true, flex: 2),
          _tableCell('Factor / Porciones', isHeader: true, flex: 2, align: pw.TextAlign.right),
          _tableCell('Costo Base Lote', isHeader: true, flex: 2, align: pw.TextAlign.right),
          _tableCell('Subtotal', isHeader: true, flex: 2, align: pw.TextAlign.right),
        ],
      ),
    ];

    PreciseDecimal total = PreciseDecimal.zero;

    for (var i = 0; i < recipe.subRecipes.length; i++) {
      final sub = recipe.subRecipes[i];
      final isEven = i % 2 == 0;
      final cost = sub.calculateItemCost();
      total += cost;

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? PdfColors.white : const PdfColor(0.98, 0.98, 0.98),
          ),
          children: [
            _tableCell(sub.childRecipeName, flex: 4, bold: true),
            _tableCell(sub.section, flex: 2),
            _tableCell(
              '${sub.quantityFactor.toStringAsFixed(2)} lote',
              flex: 2,
              align: pw.TextAlign.right,
            ),
            _tableCell(
              '$currency${sub.unitCost.toStringAsFixed(2)}',
              flex: 2,
              align: pw.TextAlign.right,
              muted: true,
            ),
            _tableCell(
              '$currency${cost.toStringAsFixed(2)}',
              flex: 2,
              align: pw.TextAlign.right,
              bold: true,
            ),
          ],
        ),
      );
    }

    // Fila total sub-recetas
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _butterCream),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              'SUBTOTAL SUB-RECETAS MODULARES',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _primaryDarkCaramel,
              ),
            ),
          ),
          _tableCell('', flex: 2),
          _tableCell('', flex: 2),
          _tableCell('', flex: 2),
          _tableCell(
            '$currency${total.toStringAsFixed(2)}',
            flex: 2,
            align: pw.TextAlign.right,
            bold: true,
            textColor: _primaryDarkCaramel,
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _borderSubtle, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
        4: pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  static pw.Widget _buildFinancialPackagingTable(Recipe recipe, String currency) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _butterCream),
        children: [
          _tableCell('Material de Empaque / Descartable', isHeader: true, flex: 5),
          _tableCell('Piezas', isHeader: true, flex: 2, align: pw.TextAlign.right),
          _tableCell('Costo Unitario', isHeader: true, flex: 2, align: pw.TextAlign.right),
          _tableCell('Subtotal', isHeader: true, flex: 2, align: pw.TextAlign.right),
        ],
      ),
    ];

    PreciseDecimal total = PreciseDecimal.zero;

    for (var i = 0; i < recipe.packaging.length; i++) {
      final pack = recipe.packaging[i];
      final isEven = i % 2 == 0;
      final isOrphan = pack.isOrphaned;
      final cost = pack.calculateItemCost();
      total += cost;

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isOrphan
                ? _costRedLight
                : isEven
                    ? PdfColors.white
                    : const PdfColor(0.98, 0.98, 0.98),
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    pack.cleanHistoricalName,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: isOrphan ? _costRed : _textEspresso,
                    ),
                  ),
                  if (isOrphan)
                    pw.Text(
                      '[!] [HUÉRFANO - \$0.00]',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: _costRed,
                      ),
                    ),
                ],
              ),
            ),
            _tableCell(
              '${pack.pieceQuantity} pz',
              flex: 2,
              align: pw.TextAlign.right,
            ),
            _tableCell(
              isOrphan ? '$currency 0.00' : '$currency${pack.unitCost.toStringAsFixed(2)}/pz',
              flex: 2,
              align: pw.TextAlign.right,
              muted: true,
            ),
            _tableCell(
              '$currency${cost.toStringAsFixed(2)}',
              flex: 2,
              align: pw.TextAlign.right,
              bold: true,
              textColor: isOrphan ? _costRed : _textEspresso,
            ),
          ],
        ),
      );
    }

    // Fila total empaques
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _butterCream),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              'SUBTOTAL EMPAQUES DIRECTOS (CE)',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _primaryDarkCaramel,
              ),
            ),
          ),
          _tableCell('', flex: 2),
          _tableCell('', flex: 2),
          _tableCell(
            '$currency${total.toStringAsFixed(2)}',
            flex: 2,
            align: pw.TextAlign.right,
            bold: true,
            textColor: _primaryDarkCaramel,
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _borderSubtle, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  static pw.Widget _buildLaborAndOverheadCard(
    Recipe recipe,
    BusinessConfig config,
    CostBreakdown breakdown,
  ) {
    final currency = config.currencySymbol;
    final effectiveLaborRate = recipe.laborHourlyRateOverride ?? config.laborHourlyRate;
    final effectiveOverhead = recipe.overheadPercentageOverride ?? config.overheadPercentage;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.98, 0.98, 0.98),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _borderSubtle, width: 0.5),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                flex: 7,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Mano de Obra Directa (CMO)',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textEspresso),
                    ),
                    pw.Text(
                      '${recipe.prepTimeMinutes} min de preparación (${(recipe.prepTimeMinutes / 60).toStringAsFixed(2)} h) × $currency${effectiveLaborRate.toStringAsFixed(2)}/hora'
                      '${recipe.laborHourlyRateOverride != null ? ' [Tarifa Personalizada]' : ' [Tarifa Global]'}',
                      style: const pw.TextStyle(fontSize: 8, color: _textMuted),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  '$currency${breakdown.laborCost.toStringAsFixed(2)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _textEspresso),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: _borderSubtle, thickness: 0.5),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                flex: 7,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Costos Indirectos de Fabricación / Overhead (COH)',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textEspresso),
                    ),
                    pw.Text(
                      '${effectiveOverhead.toStringAsFixed(1)}% aplicado sobre base directa ($currency${breakdown.directMaterialCost.toStringAsFixed(2)})'
                      '${recipe.overheadPercentageOverride != null ? ' [Overhead Personalizado]' : ' [Overhead Global]'}',
                      style: const pw.TextStyle(fontSize: 8, color: _textMuted),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  '$currency${breakdown.overheadCost.toStringAsFixed(2)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _textEspresso),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFinancialSummaryAndPricingCard(
    Recipe recipe,
    BusinessConfig config,
    CostBreakdown breakdown,
  ) {
    final currency = config.currencySymbol;
    final isCustomBatch = recipe.customBatchPrice != null;

    final batchPrice = breakdown.suggestedBatchPrice;
    final portionPrice = breakdown.suggestedPortionPrice;
    final grossProfit = breakdown.netProfitBatch;
    final effectiveMargin = breakdown.pricing?.realMarginOnSalesBatch ??
        (batchPrice > PreciseDecimal.zero
            ? (grossProfit / batchPrice) * PreciseDecimal.fromInt(100)
            : PreciseDecimal.zero);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _butterCream,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _primaryCaramel, width: 1),
      ),
      child: pw.Column(
        children: [
          // Fila: CTP y CUP
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'COSTO TOTAL DE PRODUCCIÓN (CTP)',
                    style: const pw.TextStyle(fontSize: 8.5, color: _textMuted),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '$currency${breakdown.totalProductionCost.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: _textEspresso,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'COSTO POR PORCIÓN (CUP)',
                    style: const pw.TextStyle(fontSize: 8.5, color: _textMuted),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '$currency${breakdown.costPerPortion.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryDarkCaramel,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: _borderSubtle, thickness: 0.5),
          pw.SizedBox(height: 8),

          // Parámetros de fijación comercial
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Estrategia de Margen Comercial:',
                style: const pw.TextStyle(fontSize: 8.5, color: _textMuted),
              ),
              pw.Text(
                '${recipe.targetProfitMargin.toStringAsFixed(1)}% '
                '(${recipe.pricingMode == PricingMode.marginOnSales ? 'Margen sobre Venta' : 'Markup sobre Costo'})'
                ' | Redondeo: ${recipe.roundingRule.name}',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _textEspresso),
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // Precios sugeridos (Lote vs Porción)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: _profitGreenLight,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PRECIO VENTA LOTE / PASTEL COMPLETO'
                      '${isCustomBatch ? ' [MANUAL]' : ''}',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _profitGreen,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$currency${batchPrice.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: _profitGreen,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'PRECIO POR REBANADA / PORCIÓN',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _profitGreen,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$currency${portionPrice.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _profitGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // Margen y Ganancia neta
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Utilidad Bruta Proyectada por Lote:',
                style: const pw.TextStyle(fontSize: 8.5, color: _textMuted),
              ),
              pw.Text(
                '$currency${grossProfit.toStringAsFixed(2)} '
                '(${effectiveMargin.toStringAsFixed(1)}% margen real)',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _profitGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SHARED WIDGETS
  // =========================================================================

  static pw.Widget _buildRecipeGeneralCard({
    required Recipe recipe,
    required bool isProduction,
  }) {
    final statusColor = recipe.isActive
        ? _profitGreen
        : recipe.isIncomplete
            ? _costRed
            : _textMuted;

    final moldText = recipe.moldDimension != null && recipe.moldDimension!.isNotEmpty
        ? '${recipe.moldType ?? 'Molde'} ${recipe.moldDimension}'
        : (recipe.moldType ?? 'No especificado');

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _butterCream,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _borderSubtle),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  recipe.name,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _textEspresso,
                  ),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: recipe.isIncomplete ? _costRedLight : PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: statusColor),
                ),
                child: pw.Text(
                  recipe.status,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _infoPill('Rendimiento', '${recipe.yieldPortions} porciones'),
              _infoPill('Molde', moldText),
              _infoPill('Prep / Horno', '${recipe.prepTimeMinutes} min / ${recipe.bakeTimeMinutes} min'),
              _infoPill('Tiempo Total', '${recipe.totalTimeMinutes} min'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoPill(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: _textMuted)),
        pw.SizedBox(height: 1),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _textEspresso),
        ),
      ],
    );
  }

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: const pw.BoxDecoration(
        color: _primaryDarkCaramel,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildIncompleteWarningBanner({required String message}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _costRedLight,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _costRed, width: 1),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: const pw.BoxDecoration(
              color: _costRed,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              'ALERTA',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              message,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _costRed,
                lineSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool bold = false,
    bool muted = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? textColor,
    required int flex,
  }) {
    final style = pw.TextStyle(
      fontSize: 8,
      fontWeight: isHeader || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: textColor ?? (isHeader ? _primaryDarkCaramel : (muted ? _textMuted : _textEspresso)),
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(text, textAlign: align, style: style),
    );
  }
}
