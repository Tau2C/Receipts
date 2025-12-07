import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shopledger/src/card_item.dart';
import 'package:shopledger/src/rust/api/simple.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const String _dbName = 'shopledger.db';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createCardsTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const barcodeType = 'TEXT NOT NULL';

    await db.execute('''
CREATE TABLE cards (
  id $idType,
  storeName $textType,
  comment $textNullableType,
  barcodeData $textType,
  barcodeType $barcodeType
  )
''');
  }

  Future _createReceiptsTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const realType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE receipts (
  id $idType,
  nip $textNullableType,
  store $textType,
  items $textType,
  total $realType,
  date $textType
  )
''');
  }

  Future _createDB(Database db, int version) async {
    await _createCardsTable(db);
    await _createReceiptsTable(db);
  }

  // Card operations (existing)
  Future<CardItem> create(CardItem card) async {
    final db = await instance.database;
    final id = await db.insert('cards', card.toMap());
    return card.copy(id: id);
  }

  Future<CardItem> readCard(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'cards',
      columns: [
        'id',
        'storeName',
        'comment',
        'barcodeData',
        'barcodeType',
      ],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return CardItem.fromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<CardItem>> readAllCards() async {
    final db = await instance.database;
    const orderBy = 'storeName ASC';
    final result = await db.query('cards', orderBy: orderBy);

    return result.map((json) => CardItem.fromMap(json)).toList();
  }

  Future<int> update(CardItem card) async {
    final db = await instance.database;
    return db.update(
      'cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  // Receipt operations (new)
  Future<Receipt> createReceipt(Receipt receipt) async {
    final db = await instance.database;
    final map = _receiptToMap(receipt);
    await db.insert('receipts', map);
    return receipt;
  }

  Future<List<Receipt>> readAllReceipts() async {
    final db = await instance.database;
    const orderBy = 'date DESC';
    final result = await db.query('receipts', orderBy: orderBy);

    return result.map((json) => _receiptFromMap(json)).toList();
  }

  Map<String, dynamic> _receiptToMap(Receipt receipt) {
    return {
      'nip': receipt.nip,
      'store': _storeToString(receipt.store),
      'items': jsonEncode(
        receipt.items.map((item) => _itemToMap(item)).toList(),
      ),
      'total': receipt.total,
      'date': receipt.date.toIso8601String(),
    };
  }

  Receipt _receiptFromMap(Map<String, dynamic> json) {
    final itemsJson = jsonDecode(json['items'] as String) as List<dynamic>;
    final items = itemsJson
        .map((e) => _itemFromMap(e as Map<String, dynamic>))
        .toList();
    return Receipt(
      nip: json['nip'] as String?,
      store: _storeFromString(json['store'] as String),
      items: items,
      total: json['total'] as double,
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, dynamic> _itemToMap(Item item) {
    return {
      'name': item.name,
      'unitPrice': item.unitPrice,
      'count': item.count,
      'price': item.price,
    };
  }

  Item _itemFromMap(Map<String, dynamic> json) {
    return Item(
      name: json['name'] as String,
      unitPrice: json['unitPrice'] as double,
      count: json['count'] as double,
      price: json['price'] as double,
    );
  }

  String _storeToString(Store store) {
    return store.when(
      biedronka: () => 'Biedronka',
      lidl: () => 'Lidl',
      other: (name) => name,
    );
  }

  Store _storeFromString(String store) {
    switch (store) {
      case 'Biedronka':
        return Store.biedronka();
      case 'Lidl':
        return Store.lidl();
      default:
        return Store.other(store);
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }

  Future deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  Future<void> resetTable(String table) async {
    final db = await instance.database;
    await db.execute('DROP TABLE IF EXISTS $table');
    if (table == 'cards') {
      await _createCardsTable(db);
    } else if (table == 'receipts') {
      await _createReceiptsTable(db);
    }
  }
}
