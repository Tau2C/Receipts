import 'package:flutter/material.dart';
import 'package:shopledger/src/rust/api/simple.dart';
import 'package:shopledger/src/database_helper.dart';

class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({super.key});

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  late Future<List<Receipt>> _receipts;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _receipts = _dbHelper.readAllReceipts();
  }

  Future<void> _fetchAndStoreReceipts() async {
    try {
      final rustReceipts = await fetchReceipts();
      for (var rustReceipt in rustReceipts) {
        await _dbHelper.createReceipt(rustReceipt);
      }
      setState(() {
        _receipts = _dbHelper.readAllReceipts();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch receipts: $e')),
      );
    }
  }

  String _storeToString(Store store) {
    return store.when(
      biedronka: () => 'Biedronka',
      lidl: () => 'Lidl',
      other: (name) => name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Receipt>>(
        future: _receipts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No receipts found.'));
          } else {
            final receipts = snapshot.data!;
            return ListView.builder(
              itemCount: receipts.length,
              itemBuilder: (context, index) {
                final receipt = receipts[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Store: ${_storeToString(receipt.store)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Total: ${receipt.total.toStringAsFixed(2)}'),
                        Text(
                            'Date: ${receipt.date.toLocal().toString().split(' ')[0]}'),
                        ...receipt.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                                '${item.name} x${item.count} @ ${item.unitPrice.toStringAsFixed(2)} = ${item.price.toStringAsFixed(2)}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchAndStoreReceipts,
        child: const Icon(Icons.download),
      ),
    );
  }
}
