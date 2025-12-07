import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shopledger/src/card_item.dart';

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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const barcodeType = 'TEXT NOT NULL';

    await db.execute('''
CREATE TABLE cards ( 
  id $idType, 
  storeName $textType,
  logoAsset $textType,
  comment $textType,
  barcodeData $textType,
  barcodeType $barcodeType
  )
''');
  }

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
        'logoAsset',
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
}
