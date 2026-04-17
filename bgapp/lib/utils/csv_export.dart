import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';
import 'package:newstore_ordering_app/services/sync_service.dart';

// Web-only imports handled via universal_html or conditional import
import 'csv_export_web.dart' if (dart.library.io) 'csv_export_stub.dart' as platform;

class CsvExport {
  static final FirebaseService _firebaseService = FirebaseService();

  /// Fetches vendors and products for [store], optionally filtered to [vendorId].
  /// Returns the number of product rows exported.
  static Future<int> exportVendorProducts({
    required Store store,      // which store to export
    String? vendorId,          // null = all vendors
  }) async {
    // Fetch vendors for the selected store (optionally filter to one)
    final allVendors = await _firebaseService.getVendors(store.id);
    final vendors = vendorId != null
        ? allVendors.where((v) => v.id == vendorId).toList()
        : allVendors;

    if (vendors.isEmpty) {
      throw Exception('No vendors found for ${store.name}.');
    }

    // 2. Fetch products per vendor
    final List<_ExportRow> rows = [];
    for (final vendor in vendors) {
      final products = await _firebaseService.getProducts(store.id, vendor.id);
      if (products.isEmpty) {
        rows.add(_ExportRow(store: store, vendor: vendor, product: null));
      } else {
        for (final product in products) {
          rows.add(_ExportRow(store: store, vendor: vendor, product: product));
        }
      }
    }

    if (rows.isEmpty) {
      throw Exception('No data found to export.');
    }

    // 3. Build CSV string
    final csv = _buildCsv(rows);

    // 4. Trigger download
    final vendorSlug = vendorId != null
        ? _slug(vendors.first.name)
        : 'all';
    final filename = '${_timestamp()}_products_${_slug(store.name)}_$vendorSlug.csv';
    platform.downloadCsv(csv, filename);

    return rows.where((r) => r.product != null).length;
  }

  /// Export UberEats CSV — includes Section + Subsection columns from uber_sections settings.
  static Future<int> exportUberEats() => _exportPlatform(
    platformDocId:      'ubereats_margins',
    platformPriceLabel: 'Uber Price',
    filename:           '${_timestamp()}_ubereats.csv',
    includeSections:    true,
  );

  /// Export Instacart CSV — Instacart-specific column format.
  static Future<int> exportInstacart() async {
    final results = await Future.wait([
      SyncService().getShopifyActiveProducts(),
      _firebaseService.getPlatformMargins('instacart_margins'),
    ]);
    final products    = results[0] as List<Map<String, dynamic>>;
    final marginsData = results[1] as Map<String, dynamic>;

    if (products.isEmpty) throw Exception('No active Shopify products found.');

    final defaultMargin = (marginsData['defaultMargin'] as num?)?.toDouble() ?? 20.0;
    final rawTagMargins = (marginsData['tagMargins'] as Map<String, dynamic>?) ?? {};
    final tagMargins    = rawTagMargins.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final buffer = StringBuffer();
    buffer.writeln([
      'aisles',           // shopify tags
      'lookup_code',      // sku
      'item_name',        // product name
      'price',            // shopify price + margin%
      'size',             // weight in grams e.g. "400 g"
      'cost_unit',        // always "each"
      'sale_price',       // blank
      'sale_date_start',  // blank
      'sale_date_end',    // blank
      'product_image',    // shopify image url
      'available',        // always "TRUE"
      'tax',              // "TRUE" or "FALSE"
    ].map(_escapeCsv).join(','));

    for (final p in products) {
      final taxable       = p['taxable'] as bool? ?? false;
      final tags          = p['tags'] as String? ?? '';
      final margin        = _resolveMargin(tags, defaultMargin, tagMargins);
      final basePrice     = double.tryParse(p['price'] as String? ?? '0') ?? 0.0;
      if (basePrice == 0) continue;
      final platformPrice = basePrice * (1 + margin / 100);
      final weightGrams   = p['weightGrams'];
      final sizeStr       = weightGrams != null && (weightGrams as num) > 0
          ? '${weightGrams.toStringAsFixed(0)} g'
          : '876 g';

      buffer.writeln([
        tags,
        p['sku']      ?? '',
        p['title']    ?? '',
        platformPrice.toStringAsFixed(2),
        sizeStr,
        'each',
        '',   // sale_price
        '',   // sale_date_start
        '',   // sale_date_end
        p['imageUrl'] ?? '',
        'TRUE',
        taxable ? 'TRUE' : 'FALSE',
      ].map((v) => _escapeCsv(v.toString())).join(','));
    }

    final csv      = buffer.toString();
    final dateStr  = DateFormat('yyyyMMdd').format(DateTime.now());
    platform.downloadCsv(csv, '${dateStr}_1001_apnirootsMississauga_full.csv');
    platform.downloadCsv(csv, '${dateStr}_1002_apnirootsOakville_full.csv');
    return products.length;
  }

  /// Shared export logic for any online platform.
  static Future<int> _exportPlatform({
    required String platformDocId,
    required String platformPriceLabel,
    required String filename,
    bool includeSections = false,
  }) async {
    final futures = <Future>[
      SyncService().getShopifyActiveProducts(),
      _firebaseService.getPlatformMargins(platformDocId),
      if (includeSections) _firebaseService.getUberSections(),
    ];
    final results = await Future.wait(futures);
    final products    = results[0] as List<Map<String, dynamic>>;
    final marginsData = results[1] as Map<String, dynamic>;
    final sectionsData = includeSections ? results[2] as Map<String, dynamic> : <String, dynamic>{};

    if (products.isEmpty) throw Exception('No active Shopify products found.');

    final defaultMargin = (marginsData['defaultMargin'] as num?)?.toDouble() ?? 20.0;
    final rawTagMargins = (marginsData['tagMargins'] as Map<String, dynamic>?) ?? {};
    final tagMargins    = rawTagMargins.map((k, v) => MapEntry(k, (v as num).toDouble()));

    // Build tag → {section, subsection} lookup map
    final tagToSection    = <String, String>{};
    final tagToSubsection = <String, String>{};
    if (includeSections) {
      final rawEntries = (sectionsData['entries'] as List<dynamic>?) ?? [];
      for (final e in rawEntries) {
        final tag = (e['subsection'] as String? ?? '').trim();
        if (tag.isNotEmpty) {
          tagToSection[tag]    = (e['section']    as String? ?? '').trim();
          tagToSubsection[tag] = tag;
        }
      }
    }

    final buffer = StringBuffer();

    // UberEats uses a trimmed column set; Instacart keeps the full set.
    if (includeSections) {
      buffer.writeln([
        'Handle', 'Product Name', 'Section', 'Subsection', 'Price', 'Tax Rate', 'Image URL', 'SKU',
      ].map(_escapeCsv).join(','));
    } else {
      buffer.writeln([
        'Handle', 'Product Name', 'SKU', 'Price', 'Margin %', platformPriceLabel, 'Tax Code', 'Tags', 'Image URL',
      ].map(_escapeCsv).join(','));
    }

    for (final p in products) {
      final taxable       = p['taxable'] as bool? ?? false;
      final tags          = p['tags'] as String? ?? '';
      final margin        = _resolveMargin(tags, defaultMargin, tagMargins);
      final basePrice     = double.tryParse(p['price'] as String? ?? '0') ?? 0.0;
      if (basePrice == 0) continue;
      final platformPrice = basePrice * (1 + margin / 100);

      if (includeSections) {
        String section = '', subsection = '';
        for (final tag in tags.split(',').map((t) => t.trim())) {
          if (tagToSection.containsKey(tag)) {
            section    = tagToSection[tag]!;
            subsection = tagToSubsection[tag]!;
            break;
          }
        }
        buffer.writeln([
          p['handle']  ?? '',
          p['title']   ?? '',
          section,
          subsection,
          platformPrice.toStringAsFixed(2),
          taxable ? '13' : '',
          p['imageUrl'] ?? '',
          p['sku']     ?? '',
        ].map((v) => _escapeCsv(v.toString())).join(','));
      } else {
        buffer.writeln([
          p['handle']  ?? '',
          p['title']   ?? '',
          p['sku']     ?? '',
          basePrice.toStringAsFixed(2),
          margin.toStringAsFixed(1),
          platformPrice.toStringAsFixed(2),
          taxable ? '13' : '',
          tags,
          p['imageUrl'] ?? '',
        ].map((v) => _escapeCsv(v.toString())).join(','));
      }
    }

    platform.downloadCsv(buffer.toString(), filename);
    return products.length;
  }

  /// Returns the margin % for a product based on its tags.
  /// First matching tag wins; falls back to [defaultMargin].
  static double _resolveMargin(
      String tags, double defaultMargin, Map<String, double> tagMargins) {
    if (tagMargins.isEmpty) return defaultMargin;
    for (final tag in tags.split(',').map((t) => t.trim())) {
      final m = tagMargins[tag];
      if (m != null) return m;
    }
    return defaultMargin;
  }

  static String _buildCsv(List<_ExportRow> rows) {
    final buffer = StringBuffer();

    // Header row — matches import format: Vendor Name, Product Name, SKU, …, Vendor Phone
    // with Store Name prepended
    buffer.writeln([
      'Vendor Name',     // col 0  — import skips header when col 0 starts with "vendor"
      'Product Name',    // col 1
      'SKU',             // col 2
      'Pcs Per Case',    // col 3
      'Pcs Per Line',    // col 4
      'Pc Price',        // col 5
      'Case Price',      // col 6
      'Pc Cost',         // col 7
      'Case Cost',       // col 8
      'Min Stock',       // col 9
      'Default Order',   // col 10
      'On Hand (Pcs)',   // col 11 — import ignores this
      'Order Qty (Cs)',  // col 12 — import ignores this
      'Vendor Phone',    // col 13 — import reads phone here
    ].map(_escapeCsv).join(','));

    // Data rows
    for (final row in rows) {
      buffer.writeln([
        row.vendor.name,                                           // col 0
        row.product?.name ?? '',                                   // col 1
        row.product?.sku ?? '',                                    // col 2
        row.product?.pcsPerCase.toString() ?? '',                  // col 3
        row.product?.pcsPerLine.toString() ?? '',                  // col 4
        row.product?.pcPrice.toStringAsFixed(2) ?? '',             // col 5
        row.product?.casePrice.toStringAsFixed(2) ?? '',           // col 6
        row.product?.pcCost.toStringAsFixed(2) ?? '',              // col 7
        row.product?.caseCost.toStringAsFixed(2) ?? '',            // col 8
        row.product?.reorderRule.maxStockPcs.toString() ?? '',     // col 9 — max stock pcs
        '',                                                        // col 10 — reserved
        '',                                                        // col 11 — On Hand blank on export
        '',                                                        // col 12 — Order Qty blank on export
        row.vendor.whatsappPhoneNumber,                            // col 13
      ].map(_escapeCsv).join(','));
    }

    return buffer.toString();
  }

  /// Returns YYMMDDHHMM timestamp string.
  static String _timestamp() => DateFormat('yyMMddHHmm').format(DateTime.now());

  /// Lowercases a name and replaces non-alphanumeric chars with dashes.
  static String _slug(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+$'), '');

  /// Escapes a CSV field: wraps in quotes if it contains comma, quote, or newline.
  static String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Fetches orders for the given [storeId] (and optionally [vendorId]),
  /// resolves store/vendor names and full product details, and exports a
  /// detailed CSV. Includes all items — even those with only on-hand qty
  /// and no order qty. Returns the total number of rows exported.
  static Future<int> exportOrders({
    required String storeId,   // filter to this store
    String? vendorId,          // null = all vendors in that store
  }) async {
    // 1. Fetch orders filtered by storeId (and optionally vendorId)
    final allOrders = await _firebaseService.getOrders();
    final orders = allOrders.where((o) {
      if (o.storeId != storeId) return false;
      if (vendorId != null && o.vendorId != vendorId) return false;
      return true;
    }).toList();

    if (orders.isEmpty) {
      throw Exception('No orders found for the selected store/vendor.');
    }

    final stores = await _firebaseService.getStores();
    final vendors = <String, List<Vendor>>{}; // storeId -> vendors

    // Build lookup maps
    final storeMap = {for (var s in stores) s.id: s.name};
    final vendorMap = <String, String>{}; // vendorId -> name (keyed by storeId_vendorId)
    final vendorPhoneMap = <String, String>{};

    // Pre-fetch vendors and products per store for every vendor that appears in orders
    final storeIds = orders.map((o) => o.storeId).toSet();
    final Map<String, Product> productMap = {}; // storeId_productId → Product
    final Map<String, List<Product>> productsByStoreVendor = {}; // storeId_vendorId → products
    final Map<String, Vendor> vendorLookup = {}; // storeId_vendorId → Vendor

    for (final storeId in storeIds) {
      final storeVendors = await _firebaseService.getVendors(storeId);
      for (final vendor in storeVendors) {
        final key = '${storeId}_${vendor.id}';
        vendorLookup[key] = vendor;
        vendorMap[key] = vendor.name;
        vendorPhoneMap[key] = vendor.whatsappPhoneNumber;

        final products = await _firebaseService.getProducts(storeId, vendor.id);
        products.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        productsByStoreVendor[key] = products;
        for (final p in products) {
          productMap['${storeId}_${p.id}'] = p;
        }
      }
    }

    // 2. Build CSV
    final buffer = StringBuffer();

    // Header
    buffer.writeln([
      'Order #',
      'Order Date',
      'Status',
      'Store',
      'Vendor',
      'Vendor Phone',
      'Order List Name',
      'Product Name',
      'SKU',
      'Pcs Per Case',
      'Pcs Per Line',
      'Pc Price',
      'Case Price',
      'Pc Cost',
      'Case Cost',
      'Min Stock',
      'Default Order',
      'On Hand (Pcs)',
      'Order Qty (Cases)',
    ].map(_escapeCsv).join(','));

    int rowCount = 0;

    // Data rows — one row per product for each order
    // Includes ALL vendor products, not just those with order items
    for (final order in orders) {
      final orderNum = order.id.length > 6
          ? order.id.substring(order.id.length - 6)
          : order.id;
      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(order.orderDate);
      final storeName = storeMap[order.storeId] ?? 'Unknown Store';
      final svKey = '${order.storeId}_${order.vendorId}';
      final vendorName = vendorMap[svKey] ?? 'Unknown Vendor';
      final vendorPhone = vendorPhoneMap[svKey] ?? '';

      // Build a lookup from productId → OrderItem for this order
      final itemByProductId = <String, OrderItem>{};
      for (final item in order.items) {
        itemByProductId[item.productId] = item;
      }

      // Get all products for this vendor in this store
      final vendorProducts = productsByStoreVendor[svKey] ?? [];

      if (vendorProducts.isEmpty && order.items.isEmpty) {
        // No products at all — export a placeholder row
        buffer.writeln([
          orderNum, dateStr, order.status, storeName, vendorName, vendorPhone,
          '', '', '', '', '', '', '', '', '', '', '', '',
        ].map(_escapeCsv).join(','));
        rowCount++;
      } else {
        final exportedProductIds = <String>{};

        for (final product in vendorProducts) {
          final item = itemByProductId[product.id];
          exportedProductIds.add(product.id);

          buffer.writeln([
            orderNum,
            dateStr,
            order.status,
            storeName,
            vendorName,
            vendorPhone,
            product.orderListProductName.isNotEmpty ? product.orderListProductName : product.name,
            product.name,
            product.sku,
            product.pcsPerCase.toString(),
            product.pcsPerLine.toString(),
            product.pcPrice.toStringAsFixed(2),
            product.casePrice.toStringAsFixed(2),
            product.pcCost.toStringAsFixed(2),
            product.caseCost.toStringAsFixed(2),
            product.reorderRule.maxStockPcs.toString(),
            '',
            item?.onHandQtyPcs.toString() ?? '',
            item?.orderQtyCases.toString() ?? '',
          ].map(_escapeCsv).join(','));
          rowCount++;
        }

        // Second: output any order items whose product no longer exists
        for (final item in order.items) {
          if (exportedProductIds.contains(item.productId)) continue;
          final product = productMap['${order.storeId}_${item.productId}'];

          buffer.writeln([
            orderNum,
            dateStr,
            order.status,
            storeName,
            vendorName,
            vendorPhone,
            item.productName, // already the orderListProductName
            item.productName,
            product?.sku ?? '',
            product?.pcsPerCase.toString() ?? '',
            product?.pcsPerLine.toString() ?? '',
            product?.pcPrice.toStringAsFixed(2) ?? '',
            product?.casePrice.toStringAsFixed(2) ?? '',
            product?.pcCost.toStringAsFixed(2) ?? '',
            product?.caseCost.toStringAsFixed(2) ?? '',
            product?.reorderRule.maxStockPcs.toString() ?? '',
            '',
            item.onHandQtyPcs.toString(),
            item.orderQtyCases.toString(),
          ].map(_escapeCsv).join(','));
          rowCount++;
        }
      }
    }

    // 3. Trigger download
    final storeName = storeMap[storeId] ?? storeId;
    final vendorSlug = vendorId != null
        ? _slug(vendorLookup['${storeId}_$vendorId']?.name ?? vendorId)
        : 'all';
    final filename = '${_timestamp()}_orders_${_slug(storeName)}_$vendorSlug.csv';
    platform.downloadCsv(buffer.toString(), filename);

    return rowCount;
  }
}

class _ExportRow {
  final Store? store;
  final Vendor vendor;
  final Product? product;
  _ExportRow({this.store, required this.vendor, this.product});
}
