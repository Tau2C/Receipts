import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shopledger/src/database_helper.dart';
import 'package:shopledger/src/card_item.dart';
import 'package:barcode_widget/barcode_widget.dart';

void main() {
  // Initialize FFI
  sqfliteFfiInit();

  // Use an in-memory database for testing
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;

  setUpAll(() {
    dbHelper = DatabaseHelper.instance;
  });

  tearDownAll(() async {
    await dbHelper.close();
  });

  // Clear the database before each test
  setUp(() async {
    await dbHelper.database.then((db) => db.delete('cards'));
  });

  test('Create and read a card', () async {
    final card = CardItem(
      storeName: 'Test Store',
      logoAsset: 'assets/images/test.png',
      comment: 'Test comment',
      barcodeData: '1234567890',
      barcodeType: BarcodeType.Code128,
    );

    final createdCard = await dbHelper.create(card);
    expect(createdCard.id, isNotNull);

    final readCard = await dbHelper.readCard(createdCard.id!);
    expect(readCard.storeName, card.storeName);
    expect(readCard.comment, card.comment);
  });

  test('Read all cards', () async {
    final card1 = CardItem(
      storeName: 'Test Store 1',
      logoAsset: 'assets/images/test1.png',
      comment: 'Test comment 1',
      barcodeData: '111',
      barcodeType: BarcodeType.Code128,
    );
    final card2 = CardItem(
      storeName: 'Test Store 2',
      logoAsset: 'assets/images/test2.png',
      comment: 'Test comment 2',
      barcodeData: '222',
      barcodeType: BarcodeType.QrCode,
    );

    await dbHelper.create(card1);
    await dbHelper.create(card2);

    final cards = await dbHelper.readAllCards();
    expect(cards.length, 2);
  });

  test('Update a card', () async {
    final card = CardItem(
      storeName: 'Test Store',
      logoAsset: 'assets/images/test.png',
      comment: 'Test comment',
      barcodeData: '1234567890',
      barcodeType: BarcodeType.Code128,
    );

    final createdCard = await dbHelper.create(card);
    final updatedCard = createdCard.copy(storeName: 'Updated Store');

    final result = await dbHelper.update(updatedCard);
    expect(result, 1);

    final readCard = await dbHelper.readCard(createdCard.id!);
    expect(readCard.storeName, 'Updated Store');
  });

  test('Delete a card', () async {
    final card = CardItem(
      storeName: 'Test Store',
      logoAsset: 'assets/images/test.png',
      comment: 'Test comment',
      barcodeData: '1234567890',
      barcodeType: BarcodeType.Code128,
    );

    final createdCard = await dbHelper.create(card);
    final result = await dbHelper.delete(createdCard.id!);
    expect(result, 1);

    expect(
      () async => await dbHelper.readCard(createdCard.id!),
      throwsA(isA<Exception>()),
    );
  });
}
