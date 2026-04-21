import 'package:receipts/secure_storage_service.dart';
import 'package:receipts/src/rust/api/database.dart';
import 'package:receipts/src/rust/api/retailers.dart';
import 'package:receipts/src/rust/api/retailers/biedronka.dart';
import 'package:receipts/src/rust/api/retailers/spolem.dart';
import 'package:receipts/src/rust/api/retailers/lidl.dart';

class RetailerManager {
  static final RetailerManager _instance = RetailerManager._internal();
  factory RetailerManager() => _instance;
  RetailerManager._internal();

  final Map<String, ReceiptProvider> _clients = {};

  Future<bool> loginRetailer(
    String retailer,
    String token,
    DatabaseService db,
  ) async {
    // For Społem
    if (retailer.toLowerCase() == 'spolem') {
      final client = SpolemClient.fromToken(
        token: token,
        lastFetch: await db.getLastFetchDateTime(retailer: retailer),
      );
      try {
        await client.verifyToken();
        _clients[retailer.toLowerCase()] = client;
        await SecureStorageService().write(
          '${retailer.toLowerCase()}_token',
          token,
        );
        return true;
      } catch (e) {
        await SecureStorageService().delete('${retailer.toLowerCase()}_token');
        rethrow;
      }
    } else if (retailer.toLowerCase() == 'biedronka') {
      final client = BiedronkaClient.fromToken(
        refreshToken: token,
        lastFetch: await db.getLastFetchDateTime(retailer: retailer),
      );
      try {
        _clients[retailer.toLowerCase()] = client;
        await SecureStorageService().write(
          '${retailer.toLowerCase()}_token',
          token,
        );
        return true;
      } catch (e) {
        await SecureStorageService().delete('${retailer.toLowerCase()}_token');
        rethrow;
      }
    } else if (retailer.toLowerCase() == 'lidl') {
      final client = LidlClient.fromToken(
        refreshToken: token,
        lastFetch: await db.getLastFetchDateTime(retailer: retailer),
      );
      try {
        _clients[retailer.toLowerCase()] = client;
        await SecureStorageService().write(
          '${retailer.toLowerCase()}_token',
          token,
        );
        return true;
      } catch (e) {
        await SecureStorageService().delete('${retailer.toLowerCase()}_token');
        rethrow;
      }
    }
    return false;
  }

  Future<void> init(DatabaseService db) async {
    // Społem
    final spolemToken = await SecureStorageService().read('spolem_token');
    if (spolemToken != null) {
      await loginRetailer('spolem', spolemToken, db);
    }
    final biedronkaToken = await SecureStorageService().read('biedronka_token');
    if (biedronkaToken != null) {
      await loginRetailer('biedronka', biedronkaToken, db);
    }
    final lidlToken = await SecureStorageService().read('lidl_token');
    if (lidlToken != null) {
      await loginRetailer('lidl', lidlToken, db);
    }
  }

  ReceiptProvider? getClient(String retailer) {
    return _clients[retailer.toLowerCase()];
  }

  bool isLoggedIn(String retailer) {
    return _clients.containsKey(retailer.toLowerCase());
  }

  Future<void> logout(String retailer) async {
    final key = '${retailer.toLowerCase()}_token';
    await SecureStorageService().delete(key);
    _clients.remove(retailer.toLowerCase());
  }
}
