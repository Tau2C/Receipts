import 'package:flutter/material.dart';
import '../models/receipt.dart';
import '../viewmodels/receipts_viewmodel.dart';

class AddReceiptView extends StatefulWidget {
  final ReceiptsViewModel viewModel;

  const AddReceiptView({super.key, required this.viewModel});

  @override
  State<AddReceiptView> createState() => _AddReceiptViewState();
}

class _AddReceiptViewState extends State<AddReceiptView> {
  final _formKey = GlobalKey<FormState>();
  final _storeController = TextEditingController(text: 'Lidl');
  final _currencyController = TextEditingController(text: 'PLN');
  final List<_ItemDraft> _items = [
    _ItemDraft(name: 'Milk 3.2%', quantity: 1, unit: 'l', unitPrice: 3.49),
  ];

  @override
  void dispose() {
    _storeController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemDraft(name: '', quantity: 1, unit: 'pcs', unitPrice: 0.0));
    });
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final receiptId = 'rcpt_${DateTime.now().millisecondsSinceEpoch}';
    final receiptItems = _items.asMap().entries.map((entry) {
      final index = entry.key;
      final draft = entry.value;
      return ReceiptItem(
        id: '${receiptId}_item_$index',
        receiptId: receiptId,
        name: draft.name,
        quantity: draft.quantity,
        unit: draft.unit,
        unitPrice: draft.unitPrice,
      );
    }).toList();

    final receipt = Receipt(
      id: receiptId,
      store: _storeController.text.trim(),
      timestamp: DateTime.now(),
      total: (_totalAmount * 100).round() / 100,
      currency: _currencyController.text.trim(),
    );

    await widget.viewModel.addReceipt(receipt, receiptItems);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _storeController,
              decoration: const InputDecoration(
                labelText: 'Store Name',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Enter store' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _currencyController,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Enter currency' : null,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items (${_items.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: item.name,
                        decoration: const InputDecoration(labelText: 'Item Name'),
                        onChanged: (val) => item.name = val,
                        validator: (val) => val == null || val.isEmpty ? 'Enter name' : null,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: item.quantity.toString(),
                              decoration: const InputDecoration(labelText: 'Qty'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                setState(() {
                                  item.quantity = double.tryParse(val) ?? 1.0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: item.unit,
                              decoration: const InputDecoration(labelText: 'Unit'),
                              onChanged: (val) => item.unit = val,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: item.unitPrice.toString(),
                              decoration: const InputDecoration(labelText: 'Unit Price'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                setState(() {
                                  item.unitPrice = double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: _items.length > 1
                                ? () => setState(() => _items.removeAt(idx))
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${_totalAmount.toStringAsFixed(2)} ${_currencyController.text}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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

  _ItemDraft({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
  });
}
