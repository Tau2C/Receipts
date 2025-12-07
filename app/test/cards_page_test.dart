import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shopledger/src/cards_page.dart';
import 'package:shopledger/src/database_helper.dart';
import 'package:shopledger/src/card_item.dart';
import 'package:barcode_widget/barcode_widget.dart';

import 'cards_page_test.mocks.dart';

@GenerateMocks([DatabaseHelper])
void main() {
  late MockDatabaseHelper mockDbHelper;

  setUp(() {
    mockDbHelper = MockDatabaseHelper();
  });

  testWidgets('CardsPage displays cards from database',
      (WidgetTester tester) async {
    final cards = [
      CardItem(
        id: 1,
        storeName: 'Test Store 1',
        logoAsset: 'assets/images/test1.png',
        comment: 'Test comment 1',
        barcodeData: '111',
        barcodeType: BarcodeType.Code128,
      ),
      CardItem(
        id: 2,
        storeName: 'Test Store 2',
        logoAsset: 'assets/images/test2.png',
        comment: 'Test comment 2',
        barcodeData: '222',
        barcodeType: BarcodeType.QrCode,
      ),
    ];

    when(mockDbHelper.readAllCards()).thenAnswer((_) async => cards);

    await tester.pumpWidget(MaterialApp(
      home: CardsPage(dbHelper: mockDbHelper),
    ));

    // Let the FutureBuilder rebuild
    await tester.pump();

    expect(find.text('Test Store 1'), findsOneWidget);
    expect(find.text('Test Store 2'), findsOneWidget);
  });

  testWidgets('Can add a new card', (WidgetTester tester) async {
    when(mockDbHelper.readAllCards()).thenAnswer((_) async => []);
    when(mockDbHelper.create(any)).thenAnswer((realInvocation) async {
      final card = realInvocation.positionalArguments.first as CardItem;
      return card.copy(id: 1);
    });

    await tester.pumpWidget(MaterialApp(
      home: CardsPage(dbHelper: mockDbHelper),
    ));
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'New Store');
    await tester.enterText(find.byType(TextFormField).at(1), 'New comment');
    await tester.enterText(find.byType(TextFormField).at(2), '333');

    await tester.tap(find.text('Add'));
    await tester.pump();

    final captured = verify(mockDbHelper.create(captureAny)).captured;
    expect(captured.single.storeName, 'New Store');
  });

  testWidgets('Can edit a card', (WidgetTester tester) async {
    final card = CardItem(
      id: 1,
      storeName: 'Test Store 1',
      logoAsset: 'assets/images/test1.png',
      comment: 'Test comment 1',
      barcodeData: '111',
      barcodeType: BarcodeType.Code128,
    );

    when(mockDbHelper.readAllCards()).thenAnswer((_) async => [card]);
    when(mockDbHelper.update(any)).thenAnswer((_) async => 1);

    await tester.pumpWidget(MaterialApp(
      home: CardsPage(dbHelper: mockDbHelper),
    ));
    await tester.pump();

    await tester.tap(find.text('Test Store 1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).at(0), 'Updated Store');
    await tester.tap(find.text('Update'));
    await tester.pump();

    final captured = verify(mockDbHelper.update(captureAny)).captured;
    expect(captured.single.storeName, 'Updated Store');
  });

  testWidgets('Can delete a card', (WidgetTester tester) async {
    final card = CardItem(
      id: 1,
      storeName: 'Test Store 1',
      logoAsset: 'assets/images/test1.png',
      comment: 'Test comment 1',
      barcodeData: '111',
      barcodeType: BarcodeType.Code128,
    );

    when(mockDbHelper.readAllCards()).thenAnswer((_) async => [card]);
    when(mockDbHelper.delete(1)).thenAnswer((_) async => 1);

    await tester.pumpWidget(MaterialApp(
      home: CardsPage(dbHelper: mockDbHelper),
    ));
    await tester.pump();

    await tester.longPress(find.text('Test Store 1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pump();

    verify(mockDbHelper.delete(1)).called(1);
  });
}
