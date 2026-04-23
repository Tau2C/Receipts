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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(storeName, style: Theme.of(context).textTheme.headlineMedium),
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
            const SizedBox(height: 16),
            Text('Items:', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _receipt.items.length,
                itemBuilder: (context, index) {
                  final item = _receipt.items[index];
                  // Check if EAN is populated
                  // Adjust property name 'ean' if it differs in your Rust schema
                  final hasEan = item.ean != null && item.ean!.isNotEmpty;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: InkWell(
                      onTap: hasEan
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ItemHistoryPage(
                                    ean: item.ean!,
                                    itemName: item.name,
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
                            Text('Count: ${item.count}'),
                            Text(
                              'Item Total: ${item.total.toStringAsFixed(2)} zł',
                            ),
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
            ),
          ],
        ),
      ),
    );
  }
}
