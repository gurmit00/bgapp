import 'package:flutter/foundation.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/plu_provider.dart';
import 'package:newstore_ordering_app/services/sync_service.dart';

/// Product Hub Engine — parallel lookup across POS + Shopify,
/// conflict detection, and master list management.
///
/// Data Authority:
///   POS (Penny Lane) → TAX (code 1/4), department
///   Shopify           → IMAGES (CDN URL), tags/collections
///   Firebase          → PRICES (store + online), orders, reorder rules
class ProductHubEngine {
  final PLUProvider pluProvider;
  final SyncService _syncService = SyncService();

  // Master lists — loaded once, cached
  List<String> _posDepartments = [];
  List<String> _posDepartmentCodes = [];
  Map<String, String> _deptCodeToName = {};
  Map<String, String> _deptNameToCode = {};
  bool _masterListsLoaded = false;

  ProductHubEngine({required this.pluProvider});

  // ═══════════════════════════════════════════════════════════
  //  HYDRATE — parallel lookup across all systems
  // ═══════════════════════════════════════════════════════════

  /// Look up a SKU in POS + Shopify simultaneously, detect conflicts
  Future<ProductHubStatus> hydrate(String sku) async {
    if (sku.isEmpty) {
      return ProductHubStatus();
    }

    // Parallel lookup
    final results = await Future.wait([
      _lookupPOS(sku),
      _lookupShopify(sku),
    ]);

    final posResult = results[0] as _POSLookupResult;
    final shopifyResult = results[1] as _ShopifyLookupResult;

    // Detect conflicts
    final conflicts = _detectConflicts(
      sku: sku,
      posResult: posResult,
      shopifyResult: shopifyResult,
    );

    return ProductHubStatus(
      pluChecked: true,
      inPlu: posResult.found,
      pluProduct: posResult.product,
      shopifyChecked: true,
      inShopify: shopifyResult.found,
      shopifyProduct: shopifyResult.data,
      conflicts: conflicts,
    );
  }

  /// Lookup just POS
  Future<_POSLookupResult> _lookupPOS(String sku) async {
    try {
      if (!pluProvider.isLoaded) await pluProvider.loadPLU();
      final plu = pluProvider.lookup(sku);
      return _POSLookupResult(found: plu != null, product: plu);
    } catch (e) {
      debugPrint('POS lookup error: $e');
      return _POSLookupResult(found: false);
    }
  }

  /// Lookup just Shopify
  Future<_ShopifyLookupResult> _lookupShopify(String sku) async {
    try {
      final result = await _syncService.findProductBySku(sku);
      return _ShopifyLookupResult(found: result != null, data: result);
    } catch (e) {
      debugPrint('Shopify lookup error: $e');
      return _ShopifyLookupResult(found: false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  CONFLICT DETECTION
  // ═══════════════════════════════════════════════════════════

  List<ProductConflict> _detectConflicts({
    required String sku,
    required _POSLookupResult posResult,
    required _ShopifyLookupResult shopifyResult,
  }) {
    final conflicts = <ProductConflict>[];

    // Only detect conflicts if product exists in both systems
    if (!posResult.found || !shopifyResult.found) return conflicts;

    final plu = posResult.product!;
    final shopify = shopifyResult.data!;

    // ── Tax mismatch (CRITICAL — POS is master) ──
    final posIsTaxable = POSTaxCode.isTaxable(plu.taxCode);
    final shopifyTaxable = shopify['taxable'] as bool? ?? true;
    if (posIsTaxable != shopifyTaxable) {
      conflicts.add(ProductConflict(
        field: 'tax',
        severity: 'critical',
        posValue: POSTaxCode.label(plu.taxCode),
        shopifyValue: shopifyTaxable ? 'Taxable' : 'Non-taxable',
        message: 'TAX MISMATCH: POS says ${POSTaxCode.label(plu.taxCode)}, Shopify says ${shopifyTaxable ? "Taxable" : "Non-taxable"}',
      ));
    } else {
      conflicts.add(ProductConflict(
        field: 'tax',
        severity: 'info',
        posValue: POSTaxCode.label(plu.taxCode),
        shopifyValue: shopifyTaxable ? 'Taxable' : 'Non-taxable',
        message: 'Tax aligned: both ${posIsTaxable ? "Taxable" : "Non-taxable"} ✓',
      ));
    }

    // ── Price difference (intentional but flag for awareness) ──
    final posPrice = double.tryParse(plu.price) ?? 0;
    final shopifyPrice = double.tryParse(shopify['price']?.toString() ?? '0') ?? 0;
    if (posPrice != shopifyPrice && posPrice > 0 && shopifyPrice > 0) {
      conflicts.add(ProductConflict(
        field: 'price',
        severity: 'info',
        posValue: '\$${posPrice.toStringAsFixed(2)}',
        shopifyValue: '\$${shopifyPrice.toStringAsFixed(2)}',
        message: 'Different prices: Store \$${posPrice.toStringAsFixed(2)} vs Online \$${shopifyPrice.toStringAsFixed(2)}',
      ));
    }

    // ── Name mismatch ──
    final posName = plu.desc.trim().toUpperCase();
    final shopifyName = (shopify['productTitle']?.toString() ?? '').trim().toUpperCase();
    if (posName.isNotEmpty && shopifyName.isNotEmpty && posName != shopifyName) {
      conflicts.add(ProductConflict(
        field: 'name',
        severity: 'warning',
        posValue: plu.desc,
        shopifyValue: shopify['productTitle']?.toString() ?? '',
        message: 'Name mismatch between POS and Shopify',
      ));
    }

    return conflicts;
  }

  // ═══════════════════════════════════════════════════════════
  //  MASTER LISTS — POS departments from PLU.csv
  // ═══════════════════════════════════════════════════════════

  /// Load master lists of all POS departments from PLU.csv
  Future<void> loadMasterLists() async {
    if (_masterListsLoaded) return;

    if (!pluProvider.isLoaded) await pluProvider.loadPLU();

    final deptSet = <String>{};
    final deptCodeSet = <String>{};

    for (final plu in pluProvider.pluMap.values) {
      if (plu.deptName.isNotEmpty) {
        deptSet.add(plu.deptName);
        if (plu.deptCode.isNotEmpty) {
          deptCodeSet.add(plu.deptCode);
          _deptCodeToName[plu.deptCode] = plu.deptName;
          _deptNameToCode[plu.deptName] = plu.deptCode;
        }
      }
    }

    _posDepartments = deptSet.toList()..sort();
    _posDepartmentCodes = deptCodeSet.toList()..sort();
    _masterListsLoaded = true;
  }

  /// All unique POS department names from PLU.csv
  List<String> get posDepartments => _posDepartments;

  /// All unique POS department codes
  List<String> get posDepartmentCodes => _posDepartmentCodes;

  /// Lookup department name from code
  String? deptNameForCode(String code) => _deptCodeToName[code];

  /// Lookup department code from name
  String? deptCodeForName(String name) => _deptNameToCode[name];

  // ═══════════════════════════════════════════════════════════
  //  LABEL QUEUE HELPERS
  // ═══════════════════════════════════════════════════════════

  /// Create a label queue item for a product
  LabelQueueItem createLabelRequest({
    required String sku,
    required String productName,
    required String reason,
    required double correctPrice,
    required String storeId,
  }) {
    return LabelQueueItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sku: sku,
      productName: productName,
      reason: reason,
      correctPrice: correctPrice,
      storeId: storeId,
      createdAt: DateTime.now(),
    );
  }
}

// ── Internal result types ──

class _POSLookupResult {
  final bool found;
  final PLUProduct? product;
  _POSLookupResult({required this.found, this.product});
}

class _ShopifyLookupResult {
  final bool found;
  final Map<String, dynamic>? data;
  _ShopifyLookupResult({required this.found, this.data});
}
