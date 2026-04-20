import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipts/src/rust/api/database.dart';
import 'package:receipts/src/rust/api/receipts.dart';

class ReceiptAddPage extends StatefulWidget {
  const ReceiptAddPage({super.key});

  @override
  State<ReceiptAddPage> createState() => _ReceiptAddPageState();
}

class _ReceiptAddPageState extends State<ReceiptAddPage> {
  final _formKey = GlobalKey<FormState>();

  String _selectedStoreName = '';
  DateTime _issuedAt = DateTime.now();
  double _total = 0.0;

  final Set<String> _cachedStores = {};
  final Set<String> _cachedItems = {};
  bool _cachesLoaded = false;

  final List<ReceiptItem> _items = [];
  final List<TextEditingController> _itemControllers = [];

  final List<FocusNode> _nameFocus = [];
  final List<FocusNode> _priceFocus = [];
  final List<FocusNode> _countFocus = [];
  final List<FocusNode> _totalFocus = [];

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd HH:mm').format(_issuedAt);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _storeController.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    for (final f in _nameFocus) f.dispose();
    for (final f in _priceFocus) f.dispose();
    for (final f in _countFocus) f.dispose();
    for (final f in _totalFocus) f.dispose();

    super.dispose();
  }

  Future<void> _loadSuggestionsCache() async {
    if (_cachesLoaded) return;
    try {
      final db = context.read<DatabaseService>();
      final receipts = await db.receipts;

      for (final r in receipts) {
        final storeName = r.store.when(
          other: (name) => name,
          biedronka: (_) => 'Biedronka',
          lidl: (_) => 'Lidl',
          spolem: (_) => 'Społem',
        );
        _cachedStores.add(storeName);

        for (final item in r.items) {
          _cachedItems.add(item.name);
        }
      }
      _cachesLoaded = true;
    } catch (e) {
      debugPrint('Failed to load suggestion cache: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _issuedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_issuedAt),
    );

    if (pickedTime == null) return;

    setState(() {
      _issuedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _dateController.text = DateFormat('yyyy-MM-dd HH:mm').format(_issuedAt);
    });
  }

  void _addItem() {
    setState(() {
      _items.add(
        ReceiptItem(
          name: '',
          price: 0.0,
          count: 1.0,
          total: 0.0,
          discounts: [],
        ),
      );
      _itemControllers.add(TextEditingController());
      _nameFocus.add(FocusNode());
      _priceFocus.add(FocusNode());
      _countFocus.add(FocusNode());
      _totalFocus.add(FocusNode());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _itemControllers[index].dispose();
      _itemControllers.removeAt(index);
    });
    _nameFocus[index].dispose();
    _priceFocus[index].dispose();
    _countFocus[index].dispose();
    _totalFocus[index].dispose();

    _nameFocus.removeAt(index);
    _priceFocus.removeAt(index);
    _countFocus.removeAt(index);
    _totalFocus.removeAt(index);
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final text = _storeController.text.trim();
    if (text.isEmpty) return;
    _selectedStoreName = text;

    ReceiptStore receiptStore;
    final lowerName = _selectedStoreName.toLowerCase();
    if (lowerName.contains('biedronka')) {
      receiptStore = ReceiptStore.biedronka(id: _selectedStoreName);
    } else if (lowerName.contains('lidl')) {
      receiptStore = ReceiptStore.lidl(id: _selectedStoreName);
    } else if (lowerName.contains('społem') || lowerName.contains('spolem')) {
      receiptStore = ReceiptStore.spolem(id: _selectedStoreName);
    } else {
      receiptStore = ReceiptStore.other(name: _selectedStoreName);
    }

    final newReceipt = Receipt(
      store: receiptStore,
      issuedAt: _issuedAt.toUtc(),
      total: _total,
      items: _items,
      discounts: <ReceiptDiscount>[],
      taxSummary: <ReceiptTaxSummary>[],
      taxTotal: 0.0,
      payments: <ReceiptPayment>[],
    );

    final db = context.read<DatabaseService>();

    try {
      await db.insertReceipt(receipt: newReceipt);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save receipt: $e')));
      }
    }
  }

  Future<List<String>> _getStoreSuggestions(String pattern) async {
    await _loadSuggestionsCache();
    return _cachedStores
        .where((s) => s.toLowerCase().contains(pattern.toLowerCase()))
        .toList();
  }

  Future<List<String>> _getItemSuggestions(String pattern) async {
    await _loadSuggestionsCache();
    return _cachedItems
        .where((i) => i.toLowerCase().contains(pattern.toLowerCase()))
        .toList();
  }

  Widget _buildItem(int index) {
    final controller = _itemControllers[index];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            TypeAheadField<String>(
              suggestionsCallback: _getItemSuggestions,
              itemBuilder: (context, suggestion) {
                return ListTile(title: Text(suggestion));
              },
              onSelected: (suggestion) {
                controller.text = suggestion;
                _items[index] = _items[index].copyWith(name: suggestion);
                _priceFocus[index].requestFocus();
              },
              builder: (context, fieldController, focusNode) {
                return TextFormField(
                  controller: controller,
                  focusNode: _nameFocus[index],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Item Name ${index + 1}',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter item name';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    _items[index] = _items[index].copyWith(name: value);
                  },
                  onFieldSubmitted: (_) {
                    _priceFocus[index].requestFocus();
                  },
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _items[index].price.toStringAsFixed(2),
                    textInputAction: TextInputAction.next,
                    focusNode: _priceFocus[index],
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final price = double.tryParse(v) ?? 0;
                      final count = _items[index].count;
                      _items[index] = _items[index].copyWith(
                        price: price,
                        total: price * count,
                      );
                      setState(() {});
                    },
                    onFieldSubmitted: (_) {
                      _countFocus[index].requestFocus();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: _items[index].count.toStringAsFixed(3),
                    textInputAction: TextInputAction.next,
                    focusNode: _countFocus[index],
                    decoration: const InputDecoration(labelText: 'Count'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final count = double.tryParse(v) ?? 0;
                      final price = _items[index].price;
                      _items[index] = _items[index].copyWith(
                        count: count,
                        total: price * count,
                      );
                      setState(() {});
                    },
                    onFieldSubmitted: (_) {
                      _totalFocus[index].requestFocus();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: _items[index].total.toStringAsFixed(2),
                    focusNode: _totalFocus[index],
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total'),
                    onChanged: (v) {
                      final total = double.tryParse(v) ?? 0;
                      _items[index] = _items[index].copyWith(total: total);
                    },
                    onFieldSubmitted: (_) {
                      if (index < _items.length - 1) {
                        _nameFocus[index + 1].requestFocus();
                      } else {
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Receipt'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveForm),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                TypeAheadField<String>(
                  controller: _storeController,
                  suggestionsCallback: _getStoreSuggestions,
                  itemBuilder: (context, suggestion) {
                    return ListTile(title: Text(suggestion));
                  },
                  onSelected: (storeName) {
                    setState(() {
                      _selectedStoreName = storeName;
                      _storeController.text = storeName;
                    });
                    FocusScope.of(context).nextFocus();
                  },
                  builder: (context, controller, focusNode) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Store'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Select or enter store';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).nextFocus();
                      },
                    );
                  },
                ),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () => _selectDate(context),
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Total Amount'),
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.number,
                  onSaved: (value) {
                    _total = double.tryParse(value ?? '') ?? 0;
                  },
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).unfocus();
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addItem,
                    ),
                  ],
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (_, i) => _buildItem(i),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on ReceiptItem {
  ReceiptItem copyWith({
    String? ean,
    String? name,
    double? price,
    double? count,
    List<ReceiptItemDiscount>? discounts,
    double? total,
    TaxGroup? taxGroup,
    double? taxRate,
  }) {
    return ReceiptItem(
      ean: ean ?? this.ean,
      name: name ?? this.name,
      price: price ?? this.price,
      count: count ?? this.count,
      discounts: discounts ?? this.discounts,
      total: total ?? this.total,
      taxGroup: taxGroup ?? this.taxGroup,
      taxRate: taxRate ?? this.taxRate,
    );
  }
}
