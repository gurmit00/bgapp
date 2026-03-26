import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';

// Web-only imports handled via universal_html or conditional import
import 'csv_export_web.dart' if (dart.library.io) 'csv_export_stub.dart' as platform;

class CsvExport {
  static final FirebaseService _firebaseService = FirebaseService();

  /// Fetches all stores, vendors and their products, builds CSV, and triggers download.
  /// Returns the number of product rows exported.
  static Future<int> exportVendorProducts() async {
    // 1. Fetch all stores
    final stores = await _firebaseService.getStores();
    if (stores.isEmpty) {
      throw Exception('No stores found to export.');
    }

    // 2. Fetch vendors and products per store
    final List<_ExportRow> rows = [];
    for (final store in stores) {
      final vendors = await _firebaseService.getVendors(store.id);
      if (vendors.isEmpty) continue;
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
    }

    if (rows.isEmpty) {
      throw Exception('No data found to export.');
    }

    // 3. Build CSV string
    final csv = _buildCsv(rows);

    // 4. Trigger download
    final filename = 'vendor_products_${DateTime.now().millisecondsSinceEpoch}.csv';
    platform.downloadCsv(csv, filename);

    return rows.where((r) => r.product != null).length;
  }

  static String _buildCsv(List<_ExportRow> rows) {
    final buffer = StringBuffer();

    // Header row — matches import format: Vendor Name, Product Name, SKU, …, Vendor Phone
    // with Store Name prepended
    buffer.writeln([
      'Store Name',
      'Vendor Name',
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
      'Vendor Phone',
    ].map(_escapeCsv).join(','));

    // Data rows
    for (final row in rows) {
      buffer.writeln([
        row.store?.name ?? '',
        row.vendor.name,
        row.product?.name ?? '',
        row.product?.sku ?? '',
        row.product?.pcsPerCase.toString() ?? '',
        row.product?.pcsPerLine.toString() ?? '',
        row.product?.pcPrice.toStringAsFixed(2) ?? '',
        row.product?.casePrice.toStringAsFixed(2) ?? '',
        row.product?.pcCost.toStringAsFixed(2) ?? '',
        row.product?.caseCost.toStringAsFixed(2) ?? '',
        row.product?.reorderRule.minStockPcs.toString() ?? '',
        row.product?.reorderRule.defaultOrderQty.toString() ?? '',
        row.vendor.whatsappPhoneNumber,
      ].map(_escapeCsv).join(','));
    }

    return buffer.toString();
  }

  /// Escapes a CSV field: wraps in quotes if it contains comma, quote, or newline.
  static String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Fetches all orders, resolves store/vendor names and full product details,
  /// and exports a detailed CSV. Includes all items — even those with only
  /// on-hand qty and no order qty. Returns the total number of rows exported.
  static Future<int> exportOrders() async {
    // 1. Fetch all orders, stores, vendors
    final orders = await _firebaseService.getOrders();
    if (orders.isEmpty) {
      throw Exception('No orders found to export.');
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
            product.name,
            product.sku,
            product.pcsPerCase.toString(),
            product.pcsPerLine.toString(),
            product.pcPrice.toStringAsFixed(2),
            product.casePrice.toStringAsFixed(2),
            product.pcCost.toStringAsFixed(2),
            product.caseCost.toStringAsFixed(2),
            product.reorderRule.minStockPcs.toString(),
            product.reorderRule.defaultOrderQty.toString(),
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
            item.productName,
            product?.sku ?? '',
            product?.pcsPerCase.toString() ?? '',
            product?.pcsPerLine.toString() ?? '',
            product?.pcPrice.toStringAsFixed(2) ?? '',
            product?.casePrice.toStringAsFixed(2) ?? '',
            product?.pcCost.toStringAsFixed(2) ?? '',
            product?.caseCost.toStringAsFixed(2) ?? '',
            product?.reorderRule.minStockPcs.toString() ?? '',
            product?.reorderRule.defaultOrderQty.toString() ?? '',
            item.onHandQtyPcs.toString(),
            item.orderQtyCases.toString(),
          ].map(_escapeCsv).join(','));
          rowCount++;
        }
      }
    }

    // 3. Trigger download
    final filename = 'orders_export_${DateTime.now().millisecondsSinceEpoch}.csv';
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
