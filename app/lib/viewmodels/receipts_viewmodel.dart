import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/receipt.dart';
import '../services/pds_service.dart';

class ReceiptsViewModel extends ChangeNotifier {
  final PdsReceiptService _service;
  StreamSubscription<String>? _changeSubscription;

  ReceiptsViewModel({PdsReceiptService? service})
      : _service = service ?? PdsReceiptService();

  List<Receipt> _receipts = [];
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isPdsInstalled = true;
  String? _errorMessage;

  List<Receipt> get receipts => List.unmodifiable(_receipts);
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get isPdsInstalled => _isPdsInstalled;
  String? get errorMessage => _errorMessage;

  double get totalSpend =>
      _receipts.fold(0.0, (sum, r) => sum + r.total);

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
