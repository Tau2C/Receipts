import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipts/src/rust/api/database.dart';
import 'package:receipts/src/rust/api/receipts.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:system_date_time_format/system_date_time_format.dart';

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

  final List<_ReceiptItemData> _items = [];
  final List<ReceiptDiscount> _discounts = [];
  final List<_ReceiptTaxSummaryData> _taxSummary = [];
  final List<_ReceiptPaymentData> _payments = [];
  final List<TextEditingController> _itemControllers = [];
  final List<TextEditingController> _totalControllers = [];
  final List<TextEditingController> _eanControllers = [];

  final List<FocusNode> _nameFocus = [];
  final List<FocusNode> _priceFocus = [];
  final List<FocusNode> _countFocus = [];
  final List<FocusNode> _totalFocus = [];
  final List<FocusNode> _eanFocus = [];
  final List<FocusNode> _taxGroupFocus = [];
  final List<FocusNode> _taxRateFocus = [];

  final List<FocusNode> _taxSummaryGroupFocus = [];
  final List<FocusNode> _taxSummaryRateFocus = [];
  final List<FocusNode> _taxSummarySalesValueFocus = [];
  final List<FocusNode> _taxSummaryTaxValueFocus = [];

  bool _didInit = false;

  final List<FocusNode> _paymentValueFocus = [];
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      final patterns = SystemDateTimeFormat.of(context);

      _dateController.text = DateFormat(
        "${patterns.datePattern} ${patterns.timePattern}",
      ).format(_issuedAt);
      _didInit = true;
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _storeController.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    for (final c in _totalControllers) {
      c.dispose();
    }
    for (final c in _eanControllers) {
      c.dispose();
    }
    for (final f in _nameFocus) {
      f.dispose();
    }
    for (final f in _priceFocus) {
      f.dispose();
    }
    for (final f in _countFocus) {
      f.dispose();
    }
    for (final f in _totalFocus) {
      f.dispose();
    }
    for (final f in _eanFocus) {
      f.dispose();
    }
    for (final f in _taxGroupFocus) {
      f.dispose();
    }
    for (final f in _taxRateFocus) {
      f.dispose();
    }
    for (final f in _taxSummaryGroupFocus) {
      f.dispose();
    }
    for (final f in _taxSummaryRateFocus) {
      f.dispose();
    }
    for (final f in _taxSummarySalesValueFocus) {
      f.dispose();
    }
    for (final f in _taxSummaryTaxValueFocus) {
      f.dispose();
    }
    for (final f in _paymentValueFocus) {
      f.dispose();
    }

    super.dispose();
  }

  Future<void> _scanBarcode(int index) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()),
    );
    setState(() {
      if (res is String && res != '-1') {
        _items[index] = _items[index].copyWith(ean: res);
        _eanControllers[index].text = res;
      }
    });
  }

  void _addDiscount() {
    setState(() {
      _discounts.add(ReceiptDiscount());
    });
  }

  void _removeDiscount(int index) {
    setState(() {
      _discounts.removeAt(index);
    });
  }

  void _updateItemTotal(int index) {
    if (index >= _items.length || _items[index].isTotalManual) return;

    final item = _items[index];
    double baseTotal = item.price * item.count;
    double discountsValue = 0;

    for (final discount in item.discounts) {
      discount.type.when(
        value: (_) {
          discountsValue += discount.value;
        },
        percent: (_) {
          // discount.value is a percentage, e.g. 10 for 10%
          discountsValue += baseTotal * (discount.value / 100.0);
        },
      );
    }

    final newTotal = baseTotal - discountsValue;

    setState(() {
      if (index < _items.length) {
        _items[index] = item.copyWith(total: newTotal);
        if (index < _totalControllers.length) {
          _totalControllers[index].text = newTotal.toStringAsFixed(2);
        }
      }
    });
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

    if (!context.mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_issuedAt),
    );

    if (pickedTime == null) return;

    if (!context.mounted) return;
    final patterns = SystemDateTimeFormat.of(context);

    setState(() {
      _issuedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _dateController.text = DateFormat(
        "${patterns.datePattern} ${patterns.timePattern}",
      ).format(_issuedAt);
    });
  }

  void _addItem() {
    setState(() {
      _items.add(
        _ReceiptItemData(
          name: '',
          price: 0.0,
          count: 1.0,
          total: 0.0,
          discounts: [],
          ean: null,
          taxGroup: null,
          taxRate: null,
        ),
      );
      _itemControllers.add(TextEditingController());
      _totalControllers.add(TextEditingController(text: '0.00'));
      _eanControllers.add(TextEditingController());
      _nameFocus.add(FocusNode());
      _priceFocus.add(FocusNode());
      _countFocus.add(FocusNode());
      _totalFocus.add(FocusNode());
      _eanFocus.add(FocusNode());
      _taxGroupFocus.add(FocusNode());
      _taxRateFocus.add(FocusNode());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _nameFocus[index].dispose();
      _priceFocus[index].dispose();
      _countFocus[index].dispose();
      _totalFocus[index].dispose();
      _eanFocus[index].dispose();
      _taxGroupFocus[index].dispose();
      _taxRateFocus[index].dispose();

      _items.removeAt(index);
      _itemControllers[index].dispose();
      _itemControllers.removeAt(index);
      _totalControllers[index].dispose();
      _totalControllers.removeAt(index);
      _eanControllers[index].dispose();
      _eanControllers.removeAt(index);

      _nameFocus.removeAt(index);
      _priceFocus.removeAt(index);
      _countFocus.removeAt(index);
      _totalFocus.removeAt(index);
      _eanFocus.removeAt(index);
      _taxGroupFocus.removeAt(index);
      _taxRateFocus.removeAt(index);
    });
  }

  void _addTaxSummary() {
    setState(() {
      _taxSummary.add(
        _ReceiptTaxSummaryData(taxRate: 0.0, salesValue: 0.0, taxValue: 0.0),
      );
      _taxSummaryGroupFocus.add(FocusNode());
      _taxSummaryRateFocus.add(FocusNode());
      _taxSummarySalesValueFocus.add(FocusNode());
      _taxSummaryTaxValueFocus.add(FocusNode());
    });
  }

  Widget _buildTaxSummary(int index) {
    final taxSummary = _taxSummary[index];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            TextFormField(
              initialValue: taxSummary.taxGroup,
              focusNode: _taxSummaryGroupFocus[index],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Tax Group'),
              onChanged: (v) {
                _taxSummary[index] = _taxSummary[index].copyWith(taxGroup: v);
              },
              onFieldSubmitted: (_) {
                _taxSummaryRateFocus[index].requestFocus();
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: taxSummary.taxRate.toStringAsFixed(2),
                    focusNode: _taxSummaryRateFocus[index],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Tax Rate (%)',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final rate = double.tryParse(v) ?? 0.0;
                      _taxSummary[index] = _taxSummary[index].copyWith(
                        taxRate: rate,
                      );
                    },
                    onFieldSubmitted: (_) {
                      _taxSummarySalesValueFocus[index].requestFocus();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: taxSummary.salesValue.toStringAsFixed(2),
                    focusNode: _taxSummarySalesValueFocus[index],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Sales Value'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final value = double.tryParse(v) ?? 0.0;
                      _taxSummary[index] = _taxSummary[index].copyWith(
                        salesValue: value,
                      );
                    },
                    onFieldSubmitted: (_) {
                      _taxSummaryTaxValueFocus[index].requestFocus();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: taxSummary.taxValue.toStringAsFixed(2),
                    focusNode: _taxSummaryTaxValueFocus[index],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Tax Value'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final value = double.tryParse(v) ?? 0.0;
                      _taxSummary[index] = _taxSummary[index].copyWith(
                        taxValue: value,
                      );
                    },
                    onFieldSubmitted: (_) {
                      if (_taxSummary.length > 1 &&
                          _taxSummary.indexOf(taxSummary) <
                              _taxSummary.length - 1) {
                        _taxSummaryGroupFocus[_taxSummary.indexOf(taxSummary) +
                                1]
                            .requestFocus();
                      } else {
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _removeTaxSummary(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _removeTaxSummary(int index) {
    setState(() {
      _taxSummary.removeAt(index);
    });
    _taxSummaryGroupFocus[index].dispose();
    _taxSummaryRateFocus[index].dispose();
    _taxSummarySalesValueFocus[index].dispose();
    _taxSummaryTaxValueFocus[index].dispose();

    _taxSummaryGroupFocus.removeAt(index);
    _taxSummaryRateFocus.removeAt(index);
    _taxSummarySalesValueFocus.removeAt(index);
    _taxSummaryTaxValueFocus.removeAt(index);
  }

  void _addPayment() {
    setState(() {
      _payments.add(
        _ReceiptPaymentData(
          paymentType: ReceiptPaymentType.cash(), // Default to cash
          value: 0.0,
        ),
      );
      _paymentValueFocus.add(FocusNode());
    });
  }

  void _removePayment(int index) {
    setState(() {
      _payments.removeAt(index);
    });
    _paymentValueFocus[index].dispose();
    _paymentValueFocus.removeAt(index);
  }

  Widget _buildPayment(int index) {
    final payment = _payments[index];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<ReceiptPaymentType>(
                initialValue: payment.paymentType,
                decoration: const InputDecoration(labelText: 'Payment Type'),
                items: ReceiptPaymentType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.toString().split('.').last),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _payments[index] = _payments[index].copyWith(
                        paymentType: v,
                      );
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: TextFormField(
                initialValue: payment.value.toStringAsFixed(2),
                focusNode: _paymentValueFocus[index],
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Value'),
                onChanged: (v) {
                  final value = double.tryParse(v) ?? 0.0;
                  _payments[index] = _payments[index].copyWith(value: value);
                },
                onFieldSubmitted: (_) {
                  if (_payments.length > 1 &&
                      _payments.indexOf(payment) < _payments.length - 1) {
                    _paymentValueFocus[_payments.indexOf(payment) + 1]
                        .requestFocus();
                  } else {
                    FocusScope.of(context).unfocus();
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _removePayment(index),
            ),
          ],
        ),
      ),
    );
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
      receiptStore = ReceiptStore.biedronka(_selectedStoreName);
    } else if (lowerName.contains('lidl')) {
      receiptStore = ReceiptStore.lidl(_selectedStoreName);
    } else if (lowerName.contains('społem') || lowerName.contains('spolem')) {
      receiptStore = ReceiptStore.spolem(_selectedStoreName);
    } else {
      receiptStore = ReceiptStore.other(_selectedStoreName);
    }

    final taxTotal = _taxSummary.fold<double>(
      0.0,
      (sum, item) => sum + item.taxValue,
    );

    var receiptTotal = _total;
    if (receiptTotal == 0.0) {
      receiptTotal = _items.fold<double>(0.0, (sum, item) => sum + item.total);
    }

    final newReceipt = Receipt(
      store: receiptStore,
      issuedAt: _issuedAt.toUtc(),
      total: receiptTotal,
      items: _items.map((e) => e.toApi()).toList(),
      discounts: _discounts,
      taxSummary: _taxSummary.map((e) => e.toApi()).toList(),
      taxTotal: taxTotal,
      payments: _payments.map((e) => e.toApi()).toList(),
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
    final totalController = _totalControllers[index];
    final eanController = _eanControllers[index];
    final item = _items[index];

    totalController.text = item.total.toStringAsFixed(2);
    eanController.text = item.ean ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            TypeAheadField<String>(
              controller: controller,
              focusNode: _nameFocus[index],
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
                  controller: fieldController,
                  focusNode: focusNode,
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
            TextFormField(
              controller: eanController,
              textInputAction: TextInputAction.next,
              focusNode: _eanFocus[index],
              decoration: InputDecoration(
                labelText: 'EAN',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () => _scanBarcode(index),
                ),
              ),
              onChanged: (v) {
                _items[index] = _items[index].copyWith(ean: v);
              },
              onFieldSubmitted: (_) {
                _priceFocus[index].requestFocus();
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.price.toStringAsFixed(2),
                    textInputAction: TextInputAction.next,
                    focusNode: _priceFocus[index],
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final price = double.tryParse(v) ?? 0;
                      _items[index] = _items[index].copyWith(price: price);
                      _updateItemTotal(index);
                    },
                    onFieldSubmitted: (_) {
                      _countFocus[index].requestFocus();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: item.count.toStringAsFixed(3),
                    textInputAction: TextInputAction.next,
                    focusNode: _countFocus[index],
                    decoration: const InputDecoration(labelText: 'Count'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final count = double.tryParse(v) ?? 0;
                      _items[index] = _items[index].copyWith(count: count);
                      _updateItemTotal(index);
                    },
                    onFieldSubmitted: (_) {
                      _totalFocus[index].requestFocus();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: totalController,
                    focusNode: _totalFocus[index],
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total'),
                    onChanged: (v) {
                      if (v.isEmpty) {
                        _items[index] = _items[index].copyWith(
                          isTotalManual: false,
                        );
                        _updateItemTotal(index);
                      } else {
                        final total = double.tryParse(v) ?? 0;
                        _items[index] = _items[index].copyWith(
                          total: total,
                          isTotalManual: true,
                        );
                      }
                    },
                    onFieldSubmitted: (_) {
                      _taxGroupFocus[index].requestFocus();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            TextFormField(
              initialValue: item.taxGroup,
              textInputAction: TextInputAction.next,
              focusNode: _taxGroupFocus[index],
              decoration: const InputDecoration(labelText: 'Tax Group'),
              onChanged: (v) {
                _ReceiptTaxSummaryData? matchingSummary;
                for (final summary in _taxSummary) {
                  if (summary.taxGroup?.toUpperCase() == v.toUpperCase()) {
                    matchingSummary = summary;
                    break;
                  }
                }

                if (matchingSummary == null) {
                  // TODO: Automatically add tax summary section for that group
                }

                setState(() {
                  _items[index] = _items[index].copyWith(
                    taxGroup: v,
                    taxRate: matchingSummary?.taxRate,
                  );
                });
              },
              onFieldSubmitted: (_) {
                _taxRateFocus[index].requestFocus();
              },
            ),
            TextFormField(
              initialValue: item.taxRate != null
                  ? (item.taxRate! * 100).toStringAsFixed(0)
                  : '',
              textInputAction: TextInputAction.done,
              focusNode: _taxRateFocus[index],
              decoration: const InputDecoration(labelText: 'Tax Rate (%)'),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final taxRate = double.tryParse(v);
                _items[index] = _items[index].copyWith(
                  taxRate: taxRate != null ? taxRate / 100.0 : null,
                );
              },
              onFieldSubmitted: (_) {
                if (index < _items.length - 1) {
                  _nameFocus[index + 1].requestFocus();
                } else {
                  FocusScope.of(context).unfocus();
                }
              },
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item Discounts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addItemDiscount(index),
                ),
              ],
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: item.discounts.length,
              itemBuilder: (context, discountIndex) {
                return _buildItemDiscount(index, discountIndex);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addItemDiscount(int itemIndex) {
    setState(() {
      _items[itemIndex].discounts.add(
        _ReceiptItemDiscountData(
          type: ReceiptItemDiscount.value(0),
          value: 0.0,
        ),
      );
      _updateItemTotal(itemIndex);
    });
  }

  void _removeItemDiscount(int itemIndex, int discountIndex) {
    setState(() {
      _items[itemIndex].discounts.removeAt(discountIndex);
      _updateItemTotal(itemIndex);
    });
  }

  Widget _buildItemDiscount(int itemIndex, int discountIndex) {
    final discount = _items[itemIndex].discounts[discountIndex];
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<ReceiptItemDiscount>(
            initialValue: discount.type,
            items: [
              DropdownMenuItem(
                value: ReceiptItemDiscount.value(0),
                child: const Text('Value'),
              ),
              DropdownMenuItem(
                value: ReceiptItemDiscount.percent(0),
                child: const Text('Percent'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                _items[itemIndex].discounts[discountIndex] = _items[itemIndex]
                    .discounts[discountIndex]
                    .copyWith(type: v);
                _updateItemTotal(itemIndex);
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: TextFormField(
            initialValue: discount.value.toStringAsFixed(2),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Value'),
            onChanged: (v) {
              final value = double.tryParse(v) ?? 0.0;
              _items[itemIndex].discounts[discountIndex] = _items[itemIndex]
                  .discounts[discountIndex]
                  .copyWith(value: value);
              _updateItemTotal(itemIndex);
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => _removeItemDiscount(itemIndex, discountIndex),
        ),
      ],
    );
  }

  Widget _buildDiscount(int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Discount ${index + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _removeDiscount(index),
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discounts',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addDiscount,
                    ),
                  ],
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _discounts.length,
                  itemBuilder: (_, i) => _buildDiscount(i),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tax Summary',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addTaxSummary,
                    ),
                  ],
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _taxSummary.length,
                  itemBuilder: (_, i) => _buildTaxSummary(i),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payments',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addPayment,
                    ),
                  ],
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _payments.length,
                  itemBuilder: (_, i) => _buildPayment(i),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptPaymentData {
  ReceiptPaymentType paymentType;
  double value;

  _ReceiptPaymentData({required this.paymentType, required this.value});

  ReceiptPayment toApi() {
    return ReceiptPayment(paymentType: paymentType, value: value);
  }

  _ReceiptPaymentData copyWith({
    ReceiptPaymentType? paymentType,
    double? value,
  }) {
    return _ReceiptPaymentData(
      paymentType: paymentType ?? this.paymentType,
      value: value ?? this.value,
    );
  }
}

class _ReceiptTaxSummaryData {
  String? taxGroup;
  double taxRate;
  double salesValue;
  double taxValue;

  _ReceiptTaxSummaryData({
    this.taxGroup,
    required this.taxRate,
    required this.salesValue,
    required this.taxValue,
  });

  ReceiptTaxSummary toApi() {
    return ReceiptTaxSummary(
      taxGroup: taxGroup,
      taxRate: taxRate / 100.0,
      valueBrutto: salesValue,
      taxValue: taxValue,
    );
  }

  _ReceiptTaxSummaryData copyWith({
    String? taxGroup,
    double? taxRate,
    double? salesValue,
    double? taxValue,
  }) {
    return _ReceiptTaxSummaryData(
      taxGroup: taxGroup ?? this.taxGroup,
      taxRate: taxRate ?? this.taxRate,
      salesValue: salesValue ?? this.salesValue,
      taxValue: taxValue ?? this.taxValue,
    );
  }
}

class _ReceiptItemDiscountData {
  ReceiptItemDiscount type;
  double value;

  _ReceiptItemDiscountData({required this.type, required this.value});

  ReceiptItemDiscount toApi() {
    return type.when(
      value: (_) => ReceiptItemDiscount.value(value),
      percent: (_) => ReceiptItemDiscount.percent(value / 100.0),
    );
  }

  _ReceiptItemDiscountData copyWith({
    ReceiptItemDiscount? type,
    double? value,
  }) {
    return _ReceiptItemDiscountData(
      type: type ?? this.type,
      value: value ?? this.value,
    );
  }
}

class _ReceiptItemData {
  String? ean;
  String name;
  double price;
  double count;
  List<_ReceiptItemDiscountData> discounts;
  double total;
  String? taxGroup;
  double? taxRate;
  bool isTotalManual;

  _ReceiptItemData({
    this.ean,
    required this.name,
    required this.price,
    required this.count,
    this.discounts = const [],
    required this.total,
    this.taxGroup,
    this.taxRate,
    this.isTotalManual = false,
  });

  ReceiptItem toApi() {
    return ReceiptItem(
      ean: ean,
      name: name,
      price: price,
      count: count,
      discounts: discounts.map((d) => d.toApi()).toList(),
      total: total,
      taxGroup: taxGroup,
      taxRate: taxRate,
    );
  }

  _ReceiptItemData copyWith({
    String? ean,
    String? name,
    double? price,
    double? count,
    List<_ReceiptItemDiscountData>? discounts,
    double? total,
    String? taxGroup,
    double? taxRate,
    bool? isTotalManual,
  }) {
    return _ReceiptItemData(
      ean: ean ?? this.ean,
      name: name ?? this.name,
      price: price ?? this.price,
      count: count ?? this.count,
      discounts: discounts ?? this.discounts,
      total: total ?? this.total,
      taxGroup: taxGroup ?? this.taxGroup,
      taxRate: taxRate ?? this.taxRate,
      isTotalManual: isTotalManual ?? this.isTotalManual,
    );
  }
}
