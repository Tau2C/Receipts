import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipts/pages/receipt_add_page.dart';
import 'package:receipts/pages/receipt_detail_page.dart';
import 'package:receipts/src/rust/api/database.dart';
import 'package:receipts/src/rust/api/receipts.dart';
import 'package:system_date_time_format/system_date_time_format.dart';

class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({super.key});

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  List<Receipt>? _receipts;

  @override
  void initState() {
    super.initState();
    _refreshReceipts();
  }

  Future<void> _refreshReceipts() async {
    final db = context.read<DatabaseService>();
    final receipts = await db.receipts;
    if (mounted) {
      setState(() {
        _receipts = receipts;
      });
    }
  }

  Widget _buildBody() {
    if (_receipts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_receipts!.isEmpty) {
      return const Center(child: Text('No receipts found.'));
    }

    final receipts = _receipts!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent receipts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text('A simple overview of your saved purchases.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...receipts.map((receipt) {
          final storeName = receipt.store.when(
            other: (name) => name,
            biedronka: (_) => "Biedronka",
            lidl: (_) => "Lidl",
            spolem: (_) => "Społem",
          );

          final retailerId = receipt.store.when(
            other: (_) => null,
            biedronka: (id) => id,
            lidl: (id) => id,
            spolem: (id) => id,
          );

          final patterns = SystemDateTimeFormat.of(context);

          return Dismissible(
            key: ValueKey(receipt.id),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              final deletedReceipt = receipt;
              setState(() {
                receipts.remove(deletedReceipt);
              });

              final db = context.read<DatabaseService>();
              if (deletedReceipt.id != null) {
                // Fixed the parameter passing for the rust-bridge call
                db.deleteReceipt(id: deletedReceipt.id!.toInt()).catchError((
                  e,
                ) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e')),
                    );
                    _refreshReceipts();
                  }
                });
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$storeName receipt deleted')),
              );
            },
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.receipt_long_rounded),
                ),
                title: Text(storeName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat(
                        "${patterns.datePattern} ${patterns.timePattern}",
                      ).format(receipt.issuedAt.toLocal()),
                    ),
                    if (retailerId != null && retailerId.isNotEmpty)
                      Text(
                        'ID: $retailerId',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                trailing: Text(
                  '${receipt.total.toStringAsFixed(2)} zł',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ReceiptDetailPage(receipt: receipt),
                    ),
                  );
                  if (mounted) {
                    _refreshReceipts();
                  }
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipts')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ReceiptAddPage()),
          );
          if (mounted) {
            _refreshReceipts();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
