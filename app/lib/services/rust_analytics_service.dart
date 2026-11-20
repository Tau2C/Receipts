import 'dart:convert';
import '../models/receipt.dart';
import '../src/rust/api.dart' as rust_api;

/// Service interfacing with the native Rust core library via flutter_rust_bridge.
class RustAnalyticsService {
  const RustAnalyticsService();

  /// Derives brand, clean product name, and standard unit price (per kg/l/pcs).
  Future<List<rust_api.BridgeNormalizedItem>> normalizeReceiptItems(
    List<ReceiptItem> items,
  ) async {
    final bridgeItems = items.map(_toBridgeItem).toList();
    return rust_api.normalizeReceiptItems(items: bridgeItems);
  }

  /// Calculates total expenditure grouped by category across provided receipt items.
  Future<List<rust_api.BridgeCategorySpend>> calculateCategorySpend(
    List<ReceiptItem> items,
  ) async {
    final bridgeItems = items.map(_toBridgeItem).toList();
    return rust_api.calculateCategorySpend(items: bridgeItems);
  }

  /// Calculates price trend (min, max, avg, latest) for a product variant.
  Future<rust_api.BridgePriceTrendResult?> calculatePriceTrend({
    required String variantRef,
    required List<rust_api.BridgePricePoint> points,
  }) async {
    return rust_api.calculatePriceTrend(variantRef: variantRef, points: points);
  }

  static rust_api.BridgeReceiptItem _toBridgeItem(ReceiptItem item) {
    return rust_api.BridgeReceiptItem(
      id: item.id,
      receiptId: item.receiptId,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      unitPrice: item.unitPrice,
      totalPrice: item.totalPrice,
      tagsJson: jsonEncode(item.tags),
    );
  }
}
