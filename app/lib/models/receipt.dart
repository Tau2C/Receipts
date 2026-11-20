/// Represents a shared receipt record conforming to PDS receipts entity.
class Receipt {
  final String id;
  final String store;
  final DateTime timestamp;
  final double total;
  final String currency;
  final String? imageBlobHash;
  final String? itemsRef;
  final Map<String, String> tags;

  Receipt({
    required this.id,
    required this.store,
    required this.timestamp,
    required this.total,
    required this.currency,
    this.imageBlobHash,
    this.itemsRef,
    Map<String, String>? tags,
  }) : tags = tags ?? {};

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String? ?? '',
      store: json['store'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'PLN',
      imageBlobHash: json['image_blob_hash'] as String?,
      itemsRef: json['items_ref'] as String?,
      tags: (json['tags'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store': store,
      'timestamp': timestamp.toIso8601String(),
      'total': total,
      'currency': currency,
      'image_blob_hash': ?imageBlobHash,
      'items_ref': ?itemsRef,
      'tags': tags,
    };
  }
}

/// Represents a linked receipt item record conforming to PDS receipt_items entity.
class ReceiptItem {
  final String id;
  final String receiptId;
  final String name;
  final String? variantRef;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final Map<String, String> tags;

  ReceiptItem({
    required this.id,
    required this.receiptId,
    required this.name,
    this.variantRef,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    double? totalPrice,
    Map<String, String>? tags,
  })  : totalPrice = totalPrice ?? ((quantity * unitPrice * 100).round() / 100),
        tags = tags ?? {};

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      id: json['id'] as String? ?? '',
      receiptId: json['receipt_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      variantRef: json['variant_ref'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'pcs',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble(),
      tags: (json['tags'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'receipt_id': receiptId,
      'name': name,
      'variant_ref': ?variantRef,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'tags': tags,
    };
  }
}
