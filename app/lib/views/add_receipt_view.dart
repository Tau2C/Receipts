import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';
import '../viewmodels/receipts_viewmodel.dart';

class AddReceiptView extends StatefulWidget {
  final ReceiptsViewModel viewModel;
  final String? initialImageBlobHash;
  final Uint8List? imagePreviewBytes;

  const AddReceiptView({
    super.key,
    required this.viewModel,
    this.initialImageBlobHash,
    this.imagePreviewBytes,
  });

  @override
  State<AddReceiptView> createState() => _AddReceiptViewState();
}

class _AddReceiptViewState extends State<AddReceiptView> {
  final _formKey = GlobalKey<FormState>();
  final _storeController = TextEditingController(text: 'Lidl');
  final _currencyController = TextEditingController(text: 'PLN');
  final _discountController = TextEditingController(text: '0.00');

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  static const List<String> _popularStores = [
    'Lidl',
    'Biedronka',
    'Carrefour',
    'Auchan',
    'Dino',
    'Kaufland',
    'Żabka',
  ];

  static const List<String> _standardUnits = [
    'pcs',
    'kg',
    'g',
    'l',
    'ml',
  ];

  final List<_ItemDraft> _items = [
    _ItemDraft(
      name: 'Milk 3.2%',
      quantity: 1,
      unit: 'l',
      unitPrice: 3.49,
      tags: {'category': 'groceries:dairy'},
    ),
  ];

  @override
  void dispose() {
    _storeController.dispose();
    _currencyController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(
        _ItemDraft(
          name: '',
          quantity: 1,
          unit: 'pcs',
          unitPrice: 0.0,
          tags: {},
        ),
      );
    });
  }

  double get _subtotalAmount {
    return _items.fold(
      0.0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );
  }

  double get _discountAmount {
    return double.tryParse(_discountController.text.trim()) ?? 0.0;
  }

  double get _finalTotalAmount {
    final sub = _subtotalAmount;
    final disc = _discountAmount;
    final net = sub - disc;
    return net > 0 ? (net * 100).round() / 100 : 0.0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  DateTime get _combinedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final receiptId = 'rcpt_${DateTime.now().millisecondsSinceEpoch}';
    final receiptItems = _items.asMap().entries.map((entry) {
      final index = entry.key;
      final draft = entry.value;

      final tags = Map<String, String>.from(draft.tags);
      if (draft.categoryText.trim().isNotEmpty) {
        tags['category'] = draft.categoryText.trim();
      }

      return ReceiptItem(
        id: '${receiptId}_item_$index',
        receiptId: receiptId,
        name: draft.name.trim(),
        quantity: draft.quantity,
        unit: draft.unit,
        unitPrice: draft.unitPrice,
        tags: tags,
      );
    }).toList();

    final receiptTags = <String, String>{};
    if (_discountAmount > 0) {
      receiptTags['discount'] = _discountAmount.toStringAsFixed(2);
    }

    final receipt = Receipt(
      id: receiptId,
      store: _storeController.text.trim(),
      timestamp: _combinedDateTime,
      total: _finalTotalAmount,
      currency: _currencyController.text.trim().toUpperCase(),
      imageBlobHash: widget.initialImageBlobHash,
      tags: receiptTags,
    );

    await widget.viewModel.addReceipt(receipt, receiptItems);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
            tooltip: 'Save Receipt',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (widget.imagePreviewBytes != null)
              Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  children: [
                    Image.memory(
                      widget.imagePreviewBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Rectified Receipt Image Attached',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            // Store autocomplete & selection chips
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _storeController.text),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _popularStores;
                }
                return _popularStores.where(
                  (s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                );
              },
              onSelected: (val) {
                _storeController.text = val;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Keep controller synchronized
                controller.addListener(() {
                  _storeController.text = controller.text;
                });
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Store Name',
                    prefixIcon: Icon(Icons.store),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Enter store' : null,
                );
              },
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _popularStores.map((store) {
                  final isSelected = _storeController.text == store;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(store),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _storeController.text = store;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // Date & Time pickers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(dateFormat.format(_selectedDate)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(
                      '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Currency & Discount
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _currencyController,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Enter currency' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _discountController,
                    decoration: const InputDecoration(
                      labelText: 'Discount / Rebate',
                      prefixIcon: Icon(Icons.discount_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Items header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items (${_items.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Line items list
            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: item.name,
                              decoration: const InputDecoration(
                                labelText: 'Item Name',
                                isDense: true,
                              ),
                              onChanged: (val) => item.name = val,
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                      ? 'Enter item name'
                                      : null,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: _items.length > 1
                                ? () => setState(() => _items.removeAt(idx))
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: item.quantity.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                                isDense: true,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (val) {
                                setState(() {
                                  item.quantity = double.tryParse(val) ?? 1.0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _standardUnits.contains(item.unit)
                                  ? item.unit
                                  : _standardUnits.first,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                isDense: true,
                              ),
                              items: _standardUnits
                                  .map((u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(u),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => item.unit = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              initialValue: item.unitPrice.toString(),
                              decoration: InputDecoration(
                                labelText: 'Unit Price (${_currencyController.text})',
                                isDense: true,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (val) {
                                setState(() {
                                  item.unitPrice = double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: item.categoryText,
                        decoration: const InputDecoration(
                          labelText: 'Category / Tag (e.g. food:beverage)',
                          prefixIcon: Icon(Icons.label_outline, size: 18),
                          isDense: true,
                        ),
                        onChanged: (val) => item.categoryText = val,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            // Summary Card
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text(
                          '${_subtotalAmount.toStringAsFixed(2)} ${_currencyController.text}',
                        ),
                      ],
                    ),
                    if (_discountAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount / Rebate:'),
                          Text(
                            '-${_discountAmount.toStringAsFixed(2)} ${_currencyController.text}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total to Pay:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${_finalTotalAmount.toStringAsFixed(2)} ${_currencyController.text}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDraft {
  String name;
  double quantity;
  String unit;
  double unitPrice;
  String categoryText;
  Map<String, String> tags;

  _ItemDraft({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    Map<String, String>? tags,
  })  : categoryText = '',
        tags = tags ?? {};
}
