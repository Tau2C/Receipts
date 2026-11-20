import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';
import '../viewmodels/receipts_viewmodel.dart';

class ReceiptDetailView extends StatefulWidget {
  final Receipt receipt;
  final ReceiptsViewModel viewModel;

  const ReceiptDetailView({
    super.key,
    required this.receipt,
    required this.viewModel,
  });

  @override
  State<ReceiptDetailView> createState() => _ReceiptDetailViewState();
}

class _ReceiptDetailViewState extends State<ReceiptDetailView> {
  late Future<List<ReceiptItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.viewModel.loadReceiptItems(widget.receipt.id);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receipt.store),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.receipt.store,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${widget.receipt.total.toStringAsFixed(2)} ${widget.receipt.currency}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date: ${dateFormat.format(widget.receipt.timestamp)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (widget.receipt.imageBlobHash != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.image, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Blob: ${widget.receipt.imageBlobHash}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Line Items',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<ReceiptItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No line items recorded for this receipt.'),
                  ),
                );
              }
              return Column(
                children: items.map((item) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.quantity} ${item.unit} @ ${item.unitPrice.toStringAsFixed(2)}',
                      ),
                      trailing: Text(
                        '${item.totalPrice.toStringAsFixed(2)} ${widget.receipt.currency}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
