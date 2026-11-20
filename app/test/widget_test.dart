import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/receipt.dart';
import 'package:app/viewmodels/receipts_viewmodel.dart';
import 'package:app/views/receipts_list_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('top.tau2c.pds/client');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'connect':
          return true;
        case 'disconnect':
          return true;
        case 'isConnected':
          return true;
        case 'isReady':
          return true;
        case 'executeRawRequest':
          return '{"status":"Success"}';
        case 'isPdsInstalled':
          return true;
        case 'installPdsApk':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Receipts dashboard displays total spend and receipt items',
      (WidgetTester tester) async {
    final viewModel = ReceiptsViewModel();
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
      MaterialApp(
        home: ReceiptsListView(viewModel: viewModel),
      ),
    );

    expect(find.text('PDS Receipts'), findsOneWidget);
    expect(find.text('Biedronka'), findsOneWidget);
    expect(find.text('35.50 PLN'), findsWidgets);
    expect(find.text('Add Receipt'), findsOneWidget);
  });
}
