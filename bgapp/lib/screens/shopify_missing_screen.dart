import 'package:flutter/material.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';
import 'package:newstore_ordering_app/services/sync_service.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

/// Shows products that have a SKU in Firebase but are NOT found in Shopify.
/// Uses one bulk /all-skus call instead of one call per product.
class ShopifyMissingScreen extends StatefulWidget {
  final Store store;

  const ShopifyMissingScreen({Key? key, required this.store}) : super(key: key);

  @override
  State<ShopifyMissingScreen> createState() => _ShopifyMissingScreenState();
}

class _ShopifyMissingScreenState extends State<ShopifyMissingScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final SyncService _syncService = SyncService();

  bool _loading = true;
  String? _error;
  int _totalChecked = 0;

  // vendor → products confirmed missing from Shopify
  final Map<Vendor, List<Product>> _missingByVendor = {};

  @override
  void initState() {
    super.initState();
    _loadMissing();
  }

  Future<void> _loadMissing() async {
    setState(() {
      _loading = true;
      _error = null;
      _totalChecked = 0;
      _missingByVendor.clear();
    });

    try {
      // Step 1: fetch all Shopify SKUs/barcodes in one call
      final shopifySkus = await _syncService.fetchAllShopifySkus();

      // Step 2: load all Firebase products for this store
      final vendors = await _firebaseService.getVendors(widget.store.id);
      int checked = 0;
      final Map<Vendor, List<Product>> result = {};

      for (final vendor in vendors) {
        final products = await _firebaseService.getProducts(widget.store.id, vendor.id);
        for (final p in products) {
          if (p.sku.isEmpty) continue;
          checked++;
          // Not in Shopify if neither its SKU nor barcode appears in the bulk set
          final inShopify = shopifySkus.contains(p.sku);
          if (!inShopify) {
            result.putIfAbsent(vendor, () => []).add(p);
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalChecked = checked;
          _missingByVendor.addAll(result);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  int get _totalMissing =>
      _missingByVendor.values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Missing from Shopify'),
            Text(widget.store.name,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Re-check',
              onPressed: _loadMissing,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 16),
            Text('Fetching Shopify catalogue…',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadMissing, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_missingByVendor.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.check_circle_outline, size: 40, color: Colors.green),
            ),
            const SizedBox(height: 16),
            Text('All products are in Shopify',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Checked $_totalChecked products',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppTheme.warningColor.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            '$_totalMissing of $_totalChecked products not in Shopify',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.warningColor,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              for (final entry in _missingByVendor.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
                  child: Text(
                    entry.key.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textTertiary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                for (final product in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _ProductRow(
                      product: product,
                      vendor: entry.key,
                      store: widget.store,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final Vendor vendor;
  final Store store;

  const _ProductRow({
    required this.product,
    required this.vendor,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = product.orderListProductName.isNotEmpty
        ? product.orderListProductName
        : product.name;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pushNamed(
            '/product',
            arguments: {
              'product': product,
              'store': store,
              'vendor': vendor,
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.storefront_outlined, size: 16, color: AppTheme.warningColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                product.sku,
                style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
