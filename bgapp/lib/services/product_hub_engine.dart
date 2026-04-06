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
  //  MULTI-STORE HYDRATE — lookup across N stores + Shopify
  // ═══════════════════════════════════════════════════════════

  /// Look up a SKU across multiple stores' PLU data + Shopify.
  Future<MultiStoreHubStatus> hydrateMultiStore(
      String sku, List<Store> stores) async {
    if (sku.isEmpty) return MultiStoreHubStatus.empty();

    // Build futures: one PLU lookup per store + one Shopify lookup
    final storeFutures = stores.map((store) => _lookupPOSForStore(sku, store));
    final shopifyFuture = _lookupShopify(sku);

    final results = await Future.wait([
      Future.wait(storeFutures.toList()),
      shopifyFuture,
    ]);

    final storeResults = results[0] as List<StorePLUResult>;
    final shopifyResult = results[1] as _ShopifyLookupResult;

    final storeResultMap = {for (var r in storeResults) r.storeId: r};

    final conflicts = _detectMultiStoreConflicts(
      sku: sku,
      storeResults: storeResultMap,
      shopifyResult: shopifyResult,
    );

    return MultiStoreHubStatus(
      storeResults: storeResultMap,
      shopifyChecked: true,
      inShopify: shopifyResult.found,
      shopifyProduct: shopifyResult.data,
      conflicts: conflicts,
    );
  }

  /// Lookup POS for a specific store
  Future<StorePLUResult> _lookupPOSForStore(String sku, Store store) async {
    try {
      if (store.hasPlu) {
        await pluProvider.loadPLUForStore(store.id, store.pluCsvUrl);
        final plu = pluProvider.lookup(sku, storeId: store.id);
        return StorePLUResult(
          storeId: store.id,
          storeName: store.name,
          checked: true,
          found: plu != null,
          pluProduct: plu,
        );
      } else {
        // Fall back to default bundled PLU
        if (!pluProvider.isLoaded) await pluProvider.loadPLU();
        final plu = pluProvider.lookup(sku);
        return StorePLUResult(
          storeId: store.id,
          storeName: store.name,
          checked: true,
          found: plu != null,
          pluProduct: plu,
        );
      }
    } catch (e) {
      debugPrint('POS lookup error for store ${store.name}: $e');
      return StorePLUResult(
        storeId: store.id,
        storeName: store.name,
        checked: true,
        found: false,
      );
    }
  }

  /// Detect conflicts across multiple stores + Shopify
  List<ProductConflict> _detectMultiStoreConflicts({
    required String sku,
    required Map<String, StorePLUResult> storeResults,
    required _ShopifyLookupResult shopifyResult,
  }) {
    final conflicts = <ProductConflict>[];
    final foundStores = storeResults.values.where((r) => r.found).toList();

    // Cross-store price differences
    if (foundStores.length > 1) {
      final prices = foundStores
          .map((r) => MapEntry(r.storeName, double.tryParse(r.pluProduct?.price ?? '') ?? 0))
          .where((e) => e.value > 0)
          .toList();
      if (prices.length > 1) {
        final allSame = prices.every((p) => p.value == prices.first.value);
        if (!allSame) {
          final details = prices.map((p) => '${p.key}: \$${p.value.toStringAsFixed(2)}').join(', ');
          conflicts.add(ProductConflict(
            field: 'price',
            severity: 'warning',
            message: 'Price differs across stores: $details',
          ));
        }
      }

      // Cross-store tax differences
      final taxCodes = foundStores
          .map((r) => MapEntry(r.storeName, r.pluProduct?.taxCode ?? ''))
          .where((e) => e.value.isNotEmpty)
          .toList();
      if (taxCodes.length > 1) {
        final allSame = taxCodes.every((t) => t.value == taxCodes.first.value);
        if (!allSame) {
          conflicts.add(ProductConflict(
            field: 'tax',
            severity: 'critical',
            message: 'Tax code differs across stores',
          ));
        }
      }
    }

    // Store vs Shopify conflicts (use first found store as reference)
    if (foundStores.isNotEmpty && shopifyResult.found) {
      final plu = foundStores.first.pluProduct!;
      final shopify = shopifyResult.data!;

      // Tax mismatch
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
      }

      // Name mismatch
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
    }

    return conflicts;
  }

  // ═══════════════════════════════════════════════════════════
  //  CONFLICT DETECTION (single-store, backward compat)
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
