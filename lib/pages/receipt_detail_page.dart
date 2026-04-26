import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:receipts/pages/item_history_page.dart';
import 'package:receipts/src/rust/api/receipts.dart';
import 'package:system_date_time_format/system_date_time_format.dart';

class ReceiptDetailPage extends StatefulWidget {
  final Receipt receipt;

  const ReceiptDetailPage({super.key, required this.receipt});

  @override
  State<ReceiptDetailPage> createState() => _ReceiptDetailPageState();
}

class _ReceiptDetailPageState extends State<ReceiptDetailPage> {
  late Receipt _receipt;

  @override
  void initState() {
    super.initState();
    _receipt = widget.receipt;
  }

  @override
  Widget build(BuildContext context) {
    // Extract the store name string from the sealed ReceiptStore type
    final storeName = _receipt.store.when(
      other: (name) => name,
      biedronka: (_) => 'Biedronka',
      lidl: (_) => 'Lidl',
      spolem: (_) => 'Społem',
    );

    final patterns = SystemDateTimeFormat.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Details')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                storeName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat(
                  "${patterns.datePattern} ${patterns.timePattern}",
                ).format(_receipt.issuedAt.toLocal()),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${_receipt.total.toStringAsFixed(2)} zł',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Tax Total: ${_receipt.taxTotal.toStringAsFixed(2)} zł',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text('Items:', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _receipt.items.length,
                itemBuilder: (context, index) {
                  final item = _receipt.items[index];
                  // Check if EAN is populated
                  // Adjust property name 'ean' if it differs in your Rust schema
                  final hasEan = item.ean != null && item.ean!.isNotEmpty;
                  final hasStoreItemId = item.id != null && item.id!.isNotEmpty;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: InkWell(
                      onTap: hasEan || hasStoreItemId
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ItemHistoryPage(
                                    ean: item.ean,
                                    itemName: item.name,
                                    itemId: item.id,
                                    store: widget.receipt.store,
                                  ),
                                ),
                              );
                            }
                          : null, // null disables the tap effect if no EAN
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text('Price: ${item.price.toStringAsFixed(2)} zł'),
                            Text('Count: ${item.count.toStringAsFixed(3)}'),
                            Text(
                              'Item Total: ${item.total.toStringAsFixed(2)} zł',
                            ),
                            if (item.taxGroup != null)
                              Text('Tax Group: ${item.taxGroup}'),
                            if (item.discounts.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Discounts:',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              for (final discount in item.discounts)
                                Text(
                                  discount.when(
                                    value: (v) =>
                                        'Value: ${v.toStringAsFixed(2)} zł',
                                    percent: (p) =>
                                        'Percent: ${(p * 100).toStringAsFixed(2)}%',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                            if (hasStoreItemId) ...[
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${item.id}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                            if (hasEan) ...[
                              const SizedBox(height: 4),
                              Text(
                                'EAN: ${item.ean}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_receipt.discounts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Discounts:',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Number of discounts applied: ${_receipt.discounts.length}',
                ),
              ],
              if (_receipt.taxSummary.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Tax Summary:',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                for (final summary in _receipt.taxSummary)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (summary.taxGroup != null)
                            Text('Group: ${summary.taxGroup}'),
                          Text(
                            'Rate: ${(summary.taxRate * 100).toStringAsFixed(0)}%',
                          ),
                          Text(
                            'Sales Value: ${summary.salesValue.toStringAsFixed(2)} zł',
                          ),
                          Text(
                            'Tax Value: ${summary.taxValue.toStringAsFixed(2)} zł',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (_receipt.payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Payments:',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                for (final payment in _receipt.payments)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(payment.paymentType.toString()),
                          Text('${payment.value.toStringAsFixed(2)} zł'),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
