import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/utils/csv_export_web.dart'
    if (dart.library.io) 'package:newstore_ordering_app/utils/csv_export_stub.dart'
    as platform;

class PLUProvider extends ChangeNotifier {
  /// All products loaded from PLU.csv keyed by PLU_NUM
  final Map<String, PLUProduct> _pluMap = {};

  /// Products the user has scanned / saved for PLU_new.csv
  final List<PLUProduct> _savedProducts = [];

  bool _isLoaded = false;
  bool _isLoading = false;
  String? _error;

  Map<String, PLUProduct> get pluMap => _pluMap;
  List<PLUProduct> get savedProducts => List.unmodifiable(_savedProducts);
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load PLU.csv from bundled assets
  Future<void> loadPLU() async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rawCsv = await rootBundle.loadString('assets/PLU.csv');
      final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(rawCsv);

      if (rows.isEmpty) {
        _error = 'PLU.csv is empty';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // First row is the header
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
        _isLoading = false;
        notifyListeners();
        return;
      }

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        String _get(int idx) =>
            idx >= 0 && idx < row.length ? row[idx].toString().trim() : '';

        final pluNum = _get(pluIdx);
        if (pluNum.isEmpty) continue;

        _pluMap[pluNum] = PLUProduct(
          pluNum: pluNum,
          desc: _get(descIdx),
          deptName: _get(deptNameIdx),
          deptCode: _get(deptIdx),
          price: _get(priceIdx),
          cost: _get(costIdx),
          taxCode: _get(taxCodeIdx),
          vendName: _get(vendNameIdx),
        );
      }

      _isLoaded = true;
    } catch (e) {
      _error = 'Failed to load PLU.csv: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lookup a PLU_NUM — returns null if not found
  PLUProduct? lookup(String pluNum) {
    return _pluMap[pluNum.trim()];
  }

  /// Add a (possibly edited) product to the save list
  void addToSaved(PLUProduct product) {
    // Avoid duplicates by PLU_NUM – replace if exists
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
