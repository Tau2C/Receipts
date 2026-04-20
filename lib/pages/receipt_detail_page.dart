import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:receipts/src/rust/api/receipts.dart'; // Import the new Rust bindings

class ReceiptDetailPage extends StatefulWidget {
  final Receipt receipt; // Changed from ManualReceipt

  const ReceiptDetailPage({super.key, required this.receipt});

  @override
  State<ReceiptDetailPage> createState() => _ReceiptDetailPageState();
}

class _ReceiptDetailPageState extends State<ReceiptDetailPage> {
  late Receipt _receipt; // Changed from ManualReceipt

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

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              storeName, // Use the extracted string
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(_receipt.issuedAt),
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
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
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
                        ],
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
