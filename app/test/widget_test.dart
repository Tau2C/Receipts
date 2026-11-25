import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/receipt.dart';
import 'package:app/services/pds_service.dart';
import 'package:app/viewmodels/receipts_viewmodel.dart';
import 'package:app/views/receipts_list_view.dart';

class FakePdsReceiptService extends PdsReceiptService {
  final List<Receipt> storedReceipts = [];

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> isPdsInstalled() async => true;

  @override
  Future<dynamic> requestAuthorization({
    String clientName = 'Receipts App',
    List<String> permissions = const ['read', 'write'],
  }) async =>
      true;

  @override
  Future<List<Receipt>> fetchReceipts() async => List.of(storedReceipts);

  @override
  Future<String> saveReceipt(Receipt receipt, List<ReceiptItem> items) async {
    storedReceipts.add(receipt);
    return 'ok';
  }

  @override
  Stream<String> watchReceiptChanges() => const Stream.empty();

  @override
  Future<String> uploadReceiptImage(Uint8List imageBytes) async => 'hash';

  @override
  Future<Uint8List?> fetchReceiptImage(String blobHash) async => null;
}

void main() {
  testWidgets('Receipts dashboard displays total spend and receipt items', (
    WidgetTester tester,
  ) async {
    final fakeService = FakePdsReceiptService();
    final viewModel = ReceiptsViewModel(service: fakeService);
    final receipt = Receipt(
      id: 'rcpt_001',
      store: 'Biedronka',
      timestamp: DateTime.now(),
      total: 35.50,
      currency: 'PLN',
    );
    final item = ReceiptItem(
      id: 'item_001',
      receiptId: 'rcpt_001',
      name: 'Bread',
      quantity: 1,
      unit: 'pcs',
      unitPrice: 3.50,
    );

    await viewModel.addReceipt(receipt, [item]);

    await tester.pumpWidget(
      MaterialApp(home: ReceiptsListView(viewModel: viewModel)),
    );

    expect(find.text('PDS Receipts'), findsOneWidget);
    expect(find.text('Biedronka'), findsOneWidget);
    expect(find.text('35.50 PLN'), findsWidgets);
    expect(find.text('Scan Receipt'), findsOneWidget);
    expect(find.text('Add Manual'), findsOneWidget);
  });
}

