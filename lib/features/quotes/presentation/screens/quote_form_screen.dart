import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../costing/domain/services/cost_calculator.dart';
import '../../../recipes/domain/entities/recipe.dart';
import '../../../recipes/domain/repositories/recipe_repository.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/quote_item.dart';
import '../bloc/quotes_bloc.dart';
import '../bloc/quotes_event.dart';
import '../widgets/quote_share_dialog.dart';

class QuoteFormScreen extends StatefulWidget {
  final Quote? quoteToEdit;

  const QuoteFormScreen({super.key, this.quoteToEdit});

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends State<QuoteFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _id;
  late TextEditingController _clientNameCtrl;
  late TextEditingController _clientPhoneCtrl;
  late TextEditingController _eventNotesCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _depositCtrl;

  late DateTime _deliveryDate;
  late QuoteStatus _status;
  late List<QuoteItem> _items;
  late DateTime _createdAt;

  @override
  void initState() {
    super.initState();
    final edit = widget.quoteToEdit;
    _id = edit?.id ?? const Uuid().v4();
    _clientNameCtrl = TextEditingController(text: edit?.clientName ?? '');
    _clientPhoneCtrl = TextEditingController(text: edit?.clientPhone ?? '');
    _eventNotesCtrl = TextEditingController(text: edit?.eventNotes ?? '');
    _discountCtrl = TextEditingController(
      text: edit != null && edit.discount > PreciseDecimal.zero
          ? edit.discount.toStringAsFixed(2)
          : '',
    );
    _depositCtrl = TextEditingController(
      text: edit != null && edit.depositAmount > PreciseDecimal.zero
          ? edit.depositAmount.toStringAsFixed(2)
          : '',
    );

    _deliveryDate = edit?.deliveryDate ?? DateTime.now().add(const Duration(days: 2));
    _status = edit?.status ?? QuoteStatus.pending;
    _items = edit?.items != null ? List.from(edit!.items) : [];
    _createdAt = edit?.createdAt ?? DateTime.now();

    _discountCtrl.addListener(() => setState(() {}));
    _depositCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _eventNotesCtrl.dispose();
    _discountCtrl.dispose();
    _depositCtrl.dispose();
    super.dispose();
  }

  PreciseDecimal get _discount {
    final text = _discountCtrl.text.trim();
    if (text.isEmpty) return PreciseDecimal.zero;
    try {
      return PreciseDecimal.fromString(text);
    } catch (_) {
      return PreciseDecimal.zero;
    }
  }

  PreciseDecimal get _deposit {
    final text = _depositCtrl.text.trim();
    if (text.isEmpty) return PreciseDecimal.zero;
    try {
      return PreciseDecimal.fromString(text);
    } catch (_) {
      return PreciseDecimal.zero;
    }
  }

  PreciseDecimal get _subtotal {
    return _items.fold(PreciseDecimal.zero, (sum, item) => sum + item.total);
  }

  PreciseDecimal get _totalAmount {
    final sub = _subtotal;
    final disc = _discount;
    if (disc >= sub) return PreciseDecimal.zero;
    return sub - disc;
  }

  PreciseDecimal get _remainingBalance {
    final tot = _totalAmount;
    final dep = _deposit;
    if (dep >= tot) return PreciseDecimal.zero;
    return tot - dep;
  }

  Future<void> _pickDeliveryDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'SELECCIONAR FECHA DE ENTREGA',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deliveryDate),
      helpText: 'SELECCIONAR HORA DE ENTREGA',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _deliveryDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _showAddRecipeDialog(BusinessConfig config) async {
    final recipeRepo = context.read<RecipeRepository>();
    final recipes = await recipeRepo.getAllRecipes();

    if (!mounted) return;

    if (recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay recetas guardadas en el recetario para agregar.'),
          backgroundColor: AppColors.primaryCaramel,
        ),
      );
      return;
    }

    await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Seleccionar Pastel o Receta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textEspresso,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: recipes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      // Calculate suggested selling price automatically (BR-COT-01)
                      PreciseDecimal suggestedPrice;
                      try {
                        final costBreakdown = CostCalculator.calculate(recipe: recipe, config: config);
                        suggestedPrice = costBreakdown.pricing?.effectiveBatchPrice ?? costBreakdown.suggestedBatchPrice;
                      } catch (_) {
                        suggestedPrice = recipe.customBatchPrice ?? PreciseDecimal.zero;
                      }

                      return ListTile(
                        key: Key('tile_recipe_${recipe.id}'),
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.butterCream,
                          child: Icon(Icons.cake, color: AppColors.primaryCaramel, size: 20),
                        ),
                        title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${recipe.yieldPortions} porciones • ${recipe.moldDimension ?? 'Molde estándar'}'),
                        trailing: Text(
                          '${config.currencySymbol}${suggestedPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDarkCaramel,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _addRecipeItem(recipe, suggestedPrice);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addRecipeItem(Recipe recipe, PreciseDecimal defaultPrice) {
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: defaultPrice.toStringAsFixed(2));
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Agregar "${recipe.name}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('txt_dialog_item_qty'),
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cantidad (pasteles / lotes)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('txt_dialog_item_price'),
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio Unitario',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('txt_dialog_item_notes'),
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notas / Relleno / Decoración',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const Key('btn_confirm_add_recipe_item'),
              onPressed: () {
                final qty = PreciseDecimal.fromString(
                  qtyCtrl.text.trim().isEmpty ? '1' : qtyCtrl.text.trim(),
                );
                final price = PreciseDecimal.fromString(
                  priceCtrl.text.trim().isEmpty ? '0' : priceCtrl.text.trim(),
                );
                setState(() {
                  _items.add(
                    QuoteItem(
                      id: const Uuid().v4(),
                      quoteId: _id,
                      recipeId: recipe.id,
                      concept: recipe.name,
                      type: QuoteItemType.recipe,
                      quantity: qty,
                      unitPrice: price,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    ),
                  );
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void _showAddCustomItemDialog() {
    final conceptCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Agregar Ítem o Servicio Extra'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('txt_custom_item_concept'),
                  controller: conceptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Concepto (ej. Topper acrílico, Envío, Velas)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('txt_custom_item_qty'),
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('txt_custom_item_price'),
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio Unitario',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('txt_custom_item_notes'),
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Detalles adicionales (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const Key('btn_confirm_add_custom_item'),
              onPressed: () {
                final concept = conceptCtrl.text.trim();
                if (concept.isEmpty) return;

                final qty = PreciseDecimal.fromString(
                  qtyCtrl.text.trim().isEmpty ? '1' : qtyCtrl.text.trim(),
                );
                final price = PreciseDecimal.fromString(
                  priceCtrl.text.trim().isEmpty ? '0' : priceCtrl.text.trim(),
                );
                setState(() {
                  _items.add(
                    QuoteItem(
                      id: const Uuid().v4(),
                      quoteId: _id,
                      recipeId: null,
                      concept: concept,
                      type: QuoteItemType.custom,
                      quantity: qty,
                      unitPrice: price,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    ),
                  );
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void _saveQuote({bool openShare = false, BusinessConfig? config}) {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe agregar al menos un ítem o pastel a la cotización.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final quote = Quote(
      id: _id,
      clientName: _clientNameCtrl.text.trim(),
      clientPhone: _clientPhoneCtrl.text.trim().isEmpty ? null : _clientPhoneCtrl.text.trim(),
      eventNotes: _eventNotesCtrl.text.trim().isEmpty ? null : _eventNotesCtrl.text.trim(),
      deliveryDate: _deliveryDate,
      discount: _discount,
      depositAmount: _deposit,
      status: _status,
      items: _items,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );

    context.read<QuotesBloc>().add(SaveQuoteEvent(quote));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cotización guardada exitosamente'),
        backgroundColor: Colors.green,
      ),
    );

    if (openShare && config != null) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (_) => QuoteShareDialog(quote: quote, config: config),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');
    final settingsState = context.watch<SettingsBloc>().state;
    final config = settingsState is SettingsLoaded ? settingsState.config : null;
    final currency = config?.currencySymbol ?? '\$';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quoteToEdit == null ? 'Nueva Cotización' : 'Editar Cotización'),
        backgroundColor: AppColors.butterCream,
        foregroundColor: AppColors.primaryDarkCaramel,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('btn_save_quote_top'),
            icon: const Icon(Icons.check),
            tooltip: 'Guardar',
            onPressed: () => _saveQuote(config: config),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Client Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_outline, color: AppColors.primaryCaramel),
                        SizedBox(width: 8),
                        Text(
                          'Datos del Cliente',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textEspresso),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('txt_quote_client_name'),
                      controller: _clientNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Cliente *',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Ingrese el nombre del cliente';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('txt_quote_client_phone'),
                      controller: _clientPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono / WhatsApp',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 2. Delivery & Event Details
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.event_note_outlined, color: AppColors.primaryCaramel),
                        SizedBox(width: 8),
                        Text(
                          'Entrega y Detalles',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textEspresso),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      key: const Key('btn_quote_delivery_date'),
                      onTap: _pickDeliveryDateTime,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 18, color: AppColors.primaryCaramel),
                                const SizedBox(width: 10),
                                Text(
                                  dateFormat.format(_deliveryDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textEspresso),
                                ),
                              ],
                            ),
                            const Text('Cambiar', style: TextStyle(color: AppColors.primaryDarkCaramel, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('txt_quote_event_notes'),
                      controller: _eventNotesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Detalles del Pedido (Temática, sabor, dedicatoria)',
                        prefixIcon: Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<QuoteStatus>(
                      key: const Key('dd_quote_status'),
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Estado del Pedido',
                        prefixIcon: Icon(Icons.flag_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: QuoteStatus.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 3. Items Section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pasteles e Ítems',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textEspresso),
                        ),
                        Text(
                          '${_items.length} ${_items.length == 1 ? 'ítem' : 'ítems'}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('btn_add_recipe_item'),
                            onPressed: config != null ? () => _showAddRecipeDialog(config) : null,
                            icon: const Icon(Icons.cake, size: 18),
                            label: const Text('Receta Base'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDarkCaramel,
                              side: const BorderSide(color: AppColors.primaryCaramel),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('btn_add_custom_item'),
                            onPressed: _showAddCustomItemDialog,
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Ítem Extra'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDarkCaramel,
                              side: const BorderSide(color: AppColors.primaryCaramel),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        ),
                        child: const Text(
                          'Agregue pasteles de su recetario o ítems personalizados para comenzar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.concept, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(
                              '${item.quantity.toStringAsFixed(1)} x $currency${item.unitPrice.toStringAsFixed(2)}${item.notes != null ? ' • ${item.notes}' : ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$currency${item.total.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                IconButton(
                                  key: Key('btn_remove_item_$index'),
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  onPressed: () => setState(() => _items.removeAt(index)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 4. Financial Summary Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borderSubtle),
              ),
              color: AppColors.butterCream,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Resumen Financiero',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textEspresso),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:', style: TextStyle(fontSize: 14, color: AppColors.textEspresso)),
                        Text(
                          '$currency${_subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(r'Descuento ($):', style: TextStyle(fontSize: 14, color: AppColors.textEspresso)),
                        ),
                        SizedBox(
                          width: 110,
                          height: 40,
                          child: TextFormField(
                            key: const Key('txt_quote_discount'),
                            controller: _discountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1, color: AppColors.borderSubtle),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL COTIZACIÓN:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textEspresso)),
                        Text(
                          '$currency${_totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDarkCaramel),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(r'Anticipo Recibido ($):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                        SizedBox(
                          width: 110,
                          height: 40,
                          child: TextFormField(
                            key: const Key('txt_quote_deposit'),
                            controller: _depositCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo por Cobrar:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textEspresso)),
                        Text(
                          '$currency${_remainingBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _remainingBalance > PreciseDecimal.zero ? Colors.red.shade800 : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Main Save Buttons
            ElevatedButton.icon(
              key: const Key('btn_save_and_share_quote'),
              onPressed: () => _saveQuote(openShare: true, config: config),
              icon: const Icon(Icons.send_outlined, size: 20),
              label: const Text('Guardar y Compartir (WhatsApp / PDF)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              key: const Key('btn_save_quote'),
              onPressed: () => _saveQuote(config: config),
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Solo Guardar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDarkCaramel,
                side: const BorderSide(color: AppColors.primaryCaramel),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
