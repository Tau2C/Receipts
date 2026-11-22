import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../viewmodels/receipts_viewmodel.dart';
import 'add_receipt_view.dart';
import 'receipt_detail_view.dart';

class ReceiptsListView extends StatelessWidget {
  final ReceiptsViewModel viewModel;

  const ReceiptsListView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('PDS Receipts'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Center(
                  child: Chip(
                    avatar: Icon(
                      viewModel.isConnected ? Icons.check_circle : Icons.error,
                      size: 16,
                      color: viewModel.isConnected ? Colors.green : Colors.red,
                    ),
                    label: Text(
                      viewModel.isConnected ? 'PDS Connected' : 'Disconnected',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: viewModel.loadReceipts,
              ),
            ],
          ),
          body: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Total Spend',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${viewModel.totalSpend.toStringAsFixed(2)} PLN',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      Container(
                        height: 36,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      Column(
                        children: [
                          Text(
                            'Receipts',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${viewModel.receipts.length}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (viewModel.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: MaterialBanner(
                    content: Text(viewModel.errorMessage!),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.errorContainer,
                    actions: [
                      if (!viewModel.isPdsInstalled)
                        FilledButton.icon(
                          onPressed: () {
                            viewModel.installPds(
                              'https://github.com/Tau2C/pds-android/releases/latest',
                            );
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('ZAINSTALUJ PDS'),
                        ),
                      if (viewModel.isConnected && !viewModel.isAuthorized)
                        FilledButton.icon(
                          onPressed: viewModel.authorize,
                          icon: const Icon(Icons.security),
                          label: const Text('AUTORYZUJ'),
                        ),
                      TextButton(
                        onPressed: viewModel.initialize,
                        child: const Text('PONÓW'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : viewModel.receipts.isEmpty
                    ? const Center(
                        child: Text(
                          'No receipts found in PDS.\nTap + to add your first receipt.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: viewModel.receipts.length,
                        itemBuilder: (context, index) {
                          final receipt = viewModel.receipts[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  receipt.store.isNotEmpty
                                      ? receipt.store[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text(
                                receipt.store,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                dateFormat.format(receipt.timestamp),
                              ),
                              trailing: Text(
                                '${receipt.total.toStringAsFixed(2)} ${receipt.currency}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReceiptDetailView(
                                      receipt: receipt,
                                      viewModel: viewModel,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddReceiptView(viewModel: viewModel),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Receipt'),
          ),
        );
      },
    );
  }
}
