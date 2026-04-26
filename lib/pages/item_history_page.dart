import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipts/src/rust/api/database.dart';
import 'package:receipts/src/rust/api/receipts.dart';
import 'package:system_date_time_format/system_date_time_format.dart';

class ItemHistoryPage extends StatefulWidget {
  final String? ean;
  final String itemName;
  final ReceiptStore? store;
  final String? itemId;

  const ItemHistoryPage({
    super.key,
    required this.ean,
    required this.itemName,
    required this.store,
    required this.itemId,
  });

  @override
  State<ItemHistoryPage> createState() => _ItemHistoryPageState();
}

class _ItemHistoryPageState extends State<ItemHistoryPage> {
  late Future<List<ReceiptItemSummary>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchItemHistory();
  }

  Future<List<ReceiptItemSummary>> _fetchItemHistory() async {
    return await context.read<DatabaseService>().getItem(
      ean: widget.ean,
      itemId: widget.itemId,
      store: widget.store,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.itemName)),
      body: FutureBuilder<List<ReceiptItemSummary>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading history: ${snapshot.error}'),
            );
          }

          final summaries = snapshot.data;
          if (summaries == null || summaries.isEmpty) {
            return const Center(
              child: Text('No price history found for this item.'),
            );
          }

          return ListView.separated(
            itemCount: summaries.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final summary = summaries[index];

              // Map the store enum back to a string
              final storeName = summary.store.when(
                other: (name) => name,
                biedronka: (_) => 'Biedronka',
                lidl: (_) => 'Lidl',
                spolem: (_) => 'Społem',
              );

              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(
                  '${summary.item.price.toStringAsFixed(2)} zł',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(storeName),
                trailing: Text(
                  DateFormat(
                    SystemDateTimeFormat.of(context).datePattern,
                  ).format(summary.date),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
