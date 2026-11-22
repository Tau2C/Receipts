import 'dart:io';
import 'package:flutter/services.dart';
import '../models/receipt.dart';
import '../src/rust/api.dart' as rust_api;

/// Service managing WebAssembly retailer plugins and receipt fetching.
class PluginService {
  const PluginService();

  /// Loads plugin WebAssembly bytes from an asset path or a file.
  Future<Uint8List> loadPluginBytes({String? assetPath, String? filePath}) async {
    if (assetPath != null) {
      final byteData = await rootBundle.load(assetPath);
      return byteData.buffer.asUint8List();
    }
    if (filePath != null) {
      return File(filePath).readAsBytes();
    }
    throw ArgumentError('Either assetPath or filePath must be provided');
  }

  /// Inspects the plugin manifest metadata.
  Future<rust_api.BridgePluginManifest> getManifest(Uint8List wasmBytes) async {
    return rust_api.getPluginManifest(wasmBytes: wasmBytes);
  }

  /// Executes receipt fetching via the sandboxed WebAssembly plugin.
  /// Returns a tuple-like record with receipts and their associated items.
  Future<({List<Receipt> receipts, List<ReceiptItem> items})> fetchReceipts({
    required Uint8List wasmBytes,
    required String accessToken,
    String? since,
    int? limit,
  }) async {
    final pluginReceipts = await rust_api.executePluginFetchReceipts(
      wasmBytes: wasmBytes,
      accessToken: accessToken,
      since: since,
      limit: limit,
    );

    final receipts = <Receipt>[];
    final allItems = <ReceiptItem>[];

    for (final pr in pluginReceipts) {
      final receiptId = pr.externalId;
      for (var i = 0; i < pr.items.length; i++) {
        final item = pr.items[i];
        allItems.add(
          ReceiptItem(
            id: '$receiptId-item-$i',
            receiptId: receiptId,
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
            tags: {
              'name': item.name,
              'quantity': item.quantity.toString(),
              'unit': item.unit,
              'source': 'plugin',
            },
          ),
        );
      }

      receipts.add(
        Receipt(
          id: receiptId,
          store: pr.store,
          timestamp: DateTime.parse(pr.timestamp),
          total: pr.total,
          currency: pr.currency,
          tags: {
            'store': pr.store,
            'currency': pr.currency,
            'source': 'plugin',
            'external_id': pr.externalId,
          },
        ),
      );
    }

    return (receipts: receipts, items: allItems);
  }
}
