import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/utils/csv_export_web.dart'
    if (dart.library.io) 'package:newstore_ordering_app/utils/csv_export_stub.dart'
    as platform;

class PLUProvider extends ChangeNotifier {
  static const String _defaultKey = '_default';

  /// storeId → { pluNum → PLUProduct }
  final Map<String, Map<String, PLUProduct>> _storePluMaps = {};

  /// Products the user has scanned / saved for PLU_new.csv
  final List<PLUProduct> _savedProducts = [];

  /// Loading state per store
  final Set<String> _loadingStores = {};
  final Set<String> _loadedStores = {};

  String? _error;

  List<PLUProduct> get savedProducts => List.unmodifiable(_savedProducts);
  bool get isLoaded => _loadedStores.contains(_defaultKey);
  bool get isLoading => _loadingStores.isNotEmpty;
  String? get error => _error;

  bool isLoadedForStore(String storeId) => _loadedStores.contains(storeId);
  bool isLoadingForStore(String storeId) => _loadingStores.contains(storeId);

  /// The default PLU map (bundled asset) for backward compat
  Map<String, PLUProduct> get pluMap =>
      _storePluMaps[_defaultKey] ?? {};

  /// Get the PLU map for a specific store
  Map<String, PLUProduct> pluMapForStore(String storeId) =>
      _storePluMaps[storeId] ?? _storePluMaps[_defaultKey] ?? {};

  /// Load PLU.csv from bundled assets (default/fallback)
  Future<void> loadPLU() async {
    if (_loadedStores.contains(_defaultKey) || _loadingStores.contains(_defaultKey)) return;
    _loadingStores.add(_defaultKey);
    _error = null;
    notifyListeners();

    try {
      final rawCsv = await rootBundle.loadString('assets/PLU.csv');
      final map = _parseCsvToMap(rawCsv);
      if (map == null) return;
      _storePluMaps[_defaultKey] = map;
      _loadedStores.add(_defaultKey);
    } catch (e) {
      _error = 'Failed to load PLU.csv: $e';
    } finally {
      _loadingStores.remove(_defaultKey);
      notifyListeners();
    }
  }

  /// Load a store-specific PLU CSV from Firebase Storage download URL
  Future<void> loadPLUForStore(String storeId, String downloadUrl) async {
    if (_loadedStores.contains(storeId) || _loadingStores.contains(storeId)) return;
    if (downloadUrl.isEmpty) return;
    _loadingStores.add(storeId);
    _error = null;
    notifyListeners();

    try {
      // Resolve gs:// URLs to HTTP download URLs via Firebase Storage SDK
      String httpUrl = downloadUrl;
      if (downloadUrl.startsWith('gs://')) {
        httpUrl = await FirebaseStorage.instance
            .refFromURL(downloadUrl)
            .getDownloadURL();
      }
      final response = await http.get(Uri.parse(httpUrl));
      if (response.statusCode != 200) {
        _error = 'Failed to download PLU for store: HTTP ${response.statusCode}';
        return;
      }
      final rawCsv = utf8.decode(response.bodyBytes);
      final map = _parseCsvToMap(rawCsv);
      if (map == null) return;
      _storePluMaps[storeId] = map;
      _loadedStores.add(storeId);
    } catch (e) {
      _error = 'Failed to load PLU for store: $e';
    } finally {
      _loadingStores.remove(storeId);
      notifyListeners();
    }
  }

  /// Reload a store's PLU (e.g. after new upload)
  Future<void> reloadPLUForStore(String storeId, String downloadUrl) async {
    _loadedStores.remove(storeId);
    _storePluMaps.remove(storeId);
    await loadPLUForStore(storeId, downloadUrl);
  }

  /// Parse CSV text into a PLU map
  Map<String, PLUProduct>? _parseCsvToMap(String rawCsv) {
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(rawCsv);

    if (rows.isEmpty) {
      _error = 'PLU CSV is empty';
      return null;
    }

    final headers = rows.first.map((h) => h.toString().trim()).toList();
    final pluIdx = headers.indexOf('PLU_NUM');
    final descIdx = headers.indexOf('DESC');
    final deptNameIdx = headers.indexOf('DEPTNAME');
    final deptIdx = headers.indexOf('DEPT');
    final priceIdx = headers.indexOf('PRICE');
    final costIdx = headers.indexOf('COST');
    final taxCodeIdx = headers.indexOf('TAX_CODE');
    final vendNameIdx = headers.indexOf('VENDNAME');

    if (pluIdx == -1) {
      _error = 'PLU_NUM column not found in CSV';
      return null;
    }

    final map = <String, PLUProduct>{};
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      String get(int idx) =>
          idx >= 0 && idx < row.length ? row[idx].toString().trim() : '';

      final pluNum = get(pluIdx);
      if (pluNum.isEmpty) continue;

      map[pluNum] = PLUProduct(
        pluNum: pluNum,
        desc: get(descIdx),
        deptName: get(deptNameIdx),
        deptCode: get(deptIdx),
        price: get(priceIdx),
        cost: get(costIdx),
        taxCode: get(taxCodeIdx),
        vendName: get(vendNameIdx),
      );
    }
    return map;
  }

  /// Lookup a PLU_NUM — tries store-specific first, falls back to default.
  /// Handles leading-zero mismatch: tries exact, then zero-padded, then stripped.
  PLUProduct? lookup(String pluNum, {String? storeId}) {
    final trimmed = pluNum.trim();
    final map = (storeId != null && _storePluMaps.containsKey(storeId))
        ? _storePluMaps[storeId]!
        : _storePluMaps[_defaultKey] ?? {};

    // Exact match
    if (map.containsKey(trimmed)) return map[trimmed];

    // Try with leading zero (68656001390 → 068656001390)
    final padded = '0$trimmed';
    if (map.containsKey(padded)) return map[padded];

    // Try stripping leading zero (068656001390 → 68656001390)
    if (trimmed.startsWith('0')) {
      final stripped = trimmed.substring(1);
      if (map.containsKey(stripped)) return map[stripped];
    }

    return null;
  }

  /// Add a (possibly edited) product to the save list
  void addToSaved(PLUProduct product) {
    _savedProducts.removeWhere((p) => p.pluNum == product.pluNum);
    _savedProducts.add(product);
    notifyListeners();
  }

  /// Remove a product from saved list
  void removeFromSaved(String pluNum) {
    _savedProducts.removeWhere((p) => p.pluNum == pluNum);
    notifyListeners();
  }

  /// Clear entire saved list
  void clearSaved() {
    _savedProducts.clear();
    notifyListeners();
  }

  /// Build the PLU_new.csv content and trigger download
  Future<int> exportPLUNew() async {
    if (_savedProducts.isEmpty) {
      throw Exception('No scanned products to export.');
    }

    final buffer = StringBuffer();
    buffer.writeln(PLUProduct.csvHeader());
    for (final p in _savedProducts) {
      buffer.writeln(p.toCsvRow());
    }

    final filename = 'PLU_new.csv';
    platform.downloadCsv(buffer.toString(), filename);
    return _savedProducts.length;
  }
}
