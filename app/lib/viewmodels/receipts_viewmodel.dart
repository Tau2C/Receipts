import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/receipt.dart';
import '../services/pds_service.dart';
import '../services/rust_analytics_service.dart';
import '../src/rust/api.dart' as rust_api;

class ReceiptsViewModel extends ChangeNotifier {
  final PdsReceiptService _service;
  final RustAnalyticsService _analyticsService;
  StreamSubscription<String>? _changeSubscription;

  ReceiptsViewModel({
    PdsReceiptService? service,
    RustAnalyticsService? analyticsService,
  })  : _service = service ?? PdsReceiptService(),
        _analyticsService = analyticsService ?? const RustAnalyticsService();

  List<Receipt> _receipts = [];
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isAuthorized = false;
  bool _isPdsInstalled = true;
  String? _errorMessage;

  List<Receipt> get receipts => List.unmodifiable(_receipts);
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get isAuthorized => _isAuthorized;
  bool get isPdsInstalled => _isPdsInstalled;
  String? get errorMessage => _errorMessage;

  double get totalSpend => _receipts.fold(0.0, (sum, r) => sum + r.total);

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isPdsInstalled = await _service.isPdsInstalled();
      if (!_isPdsInstalled) {
        _errorMessage = 'Usługa PDS Core nie jest zainstalowana w systemie.';
        _isConnected = false;
        return;
      }

      _isConnected = await _service.initialize();
      if (_isConnected) {
        await loadReceipts();
        _subscribeToChanges();
      } else {
        _errorMessage = 'Nie udało się połączyć z usługą PDS Core.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> authorize() async {
    _isLoading = true;
    notifyListeners();
    try {
      final authResult = await _service.requestAuthorization(
        clientName: 'Receipts App',
        permissions: ['read', 'write'],
      );

      final authorized = authResult != null &&
          (authResult.isAuthorized == true ||
              (authResult is Map && authResult['isAuthorized'] == true));

      _isAuthorized = authorized;
      if (_isAuthorized) {
        _errorMessage = null;
        await loadReceipts();
      } else {
        _errorMessage = 'Brak autoryzacji w PDS Core.';
      }
      return _isAuthorized;
    } catch (e) {
      _errorMessage = 'Błąd autoryzacji: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> installPds(String apkUriOrUrl) async {
    return _service.installPdsApk(apkUriOrUrl);
  }

  Future<void> loadReceipts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _receipts = await _service.fetchReceipts();
      _receipts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load receipts: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addReceipt(Receipt receipt, List<ReceiptItem> items) async {
    try {
      await _service.saveReceipt(receipt, items);
      _receipts.insert(0, receipt);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to save receipt: $e';
      notifyListeners();
    }
  }

  Future<List<ReceiptItem>> loadReceiptItems(String receiptId) {
    return _service.fetchReceiptItems(receiptId);
  }

  Future<List<rust_api.BridgeNormalizedItem>> normalizeItems(
    List<ReceiptItem> items,
  ) {
    return _analyticsService.normalizeReceiptItems(items);
  }

  Future<List<rust_api.BridgeCategorySpend>> calculateCategorySpend(
    List<ReceiptItem> items,
  ) {
    return _analyticsService.calculateCategorySpend(items);
  }

  void _subscribeToChanges() {
    _changeSubscription?.cancel();
    _changeSubscription = _service.watchReceiptChanges().listen((_) {
      loadReceipts();
    });
  }

  @override
  void dispose() {
    _changeSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
