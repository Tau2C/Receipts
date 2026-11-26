import 'dart:convert';
import 'dart:typed_data';
import 'package:pds_flutter/pds_flutter.dart';
import '../models/receipt.dart';

/// High-level service managing PDS receipt storage and synchronization.
class PdsReceiptService {
  final PdsClient _client;

  PdsReceiptService({PdsClient? client}) : _client = client ?? PdsClient();

  /// Connects to PDS Core service.
  Future<bool> initialize() async {
    return _client.connect();
  }

  /// Checks if client identity is authorized with PDS Core.
  Future<bool> isAuthorized() => _client.isAuthorized();

  /// Gets the registered client identifier if authorized.
  Future<String?> getClientId() => _client.getClientId();

  /// Requests client application authorization via interactive PDS dialog.
  Future<PdsAuthResult> requestAuthorization({
    String clientName = 'Receipts',
    List<String> permissions = const [
      'ReadEntities',
      'WriteEntities',
      'ReadBlobs',
      'WriteBlobs',
    ],
  }) async {
    return _client.requestAuthorization(
      clientName: clientName,
      permissions: permissions,
    );
  }

  /// Checks if PDS Core service is installed on the system.
  Future<bool> isPdsInstalled() async {
    return _client.isPdsInstalled();
  }

  /// Prompts system package installer to install PDS Core APK.
  Future<bool> installPdsApk(String apkUriString) async {
    return _client.installPdsApk(apkUriString);
  }

  /// Disconnects from PDS Core.
  Future<bool> dispose() async {
    return _client.disconnect();
  }

  /// Fetches all receipts stored in PDS.
  Future<List<Receipt>> fetchReceipts() async {
    try {
      final res = await _client.query('receipts');
      if (res.isEmpty) return [];

      final list = jsonDecode(res);
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(Receipt.fromJson)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Saves a receipt and its associated line items to PDS.
  Future<String> saveReceipt(Receipt receipt, List<ReceiptItem> items) async {
    // 1. Save line items
    for (final item in items) {
      await _client.put('receipt_items', item.toJson());
    }

    // 2. Save top-level shared receipt record
    return _client.put('receipts', receipt.toJson());
  }

  /// Fetches items for a specific receipt.
  Future<List<ReceiptItem>> fetchReceiptItems(String receiptId) async {
    try {
      final res = await _client.query('receipt_items', {
        'receipt_id': receiptId,
      });
      if (res.isEmpty) return [];

      final list = jsonDecode(res);
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(ReceiptItem.fromJson)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Uploads receipt photo to PDS CAS blob storage.
  Future<String> uploadReceiptImage(Uint8List imageBytes) {
    return _client.putBlob(imageBytes);
  }

  /// Retrieves receipt photo by blob hash.
  Future<Uint8List?> fetchReceiptImage(String blobHash) {
    return _client.getBlob(blobHash);
  }

  /// Subscribes to real-time receipt changes from PDS Core.
  Stream<String> watchReceiptChanges() {
    return _client.watchChanges(entityType: 'receipts');
  }
}
