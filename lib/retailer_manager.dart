import 'package:receipts/secure_storage_service.dart';
import 'package:receipts/src/rust/api/database.dart';
import 'package:receipts/src/rust/api/retailers/spolem.dart';

class RetailerManager {
  static final RetailerManager _instance = RetailerManager._internal();
  factory RetailerManager() => _instance;
  RetailerManager._internal();

  final Map<String, SpolemClient> _clients = {};

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
    }
    // Handle other retailers later
    return false;
  }

  Future<void> init(DatabaseService db) async {
    // Społem
    final spolemToken = await SecureStorageService().read('spolem_token');
    if (spolemToken != null) {
      await loginRetailer('spolem', spolemToken, db);
    }
    // Other retailers
  }

  SpolemClient? getClient(String retailer) {
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
