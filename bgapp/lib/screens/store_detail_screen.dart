import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';
import 'package:newstore_ordering_app/utils/theme.dart';
import 'package:newstore_ordering_app/utils/app_roles.dart';
import 'package:newstore_ordering_app/utils/fuzzy_search.dart';

class StoreDetailScreen extends StatefulWidget {
  final Store store;

  const StoreDetailScreen({Key? key, required this.store}) : super(key: key);

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

// Simple holder for a product + its vendor
class _ProductResult {
  final Product product;
  final Vendor vendor;
  const _ProductResult(this.product, this.vendor);
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  late Store _currentStore;

  // Cross-vendor product search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<_ProductResult> _allProducts = [];
  bool _productsLoaded = false;
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    _currentStore = widget.store;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadVendors(widget.store.id);
      _ensureProductsLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ensureProductsLoaded() async {
    if (_productsLoaded || _loadingProducts) return;
    setState(() => _loadingProducts = true);
    try {
      final firebaseService = FirebaseService();
      // Fetch vendors directly so this works even before VendorProvider has loaded
      final vendors = await firebaseService.getVendors(widget.store.id);
      final results = <_ProductResult>[];
      for (final vendor in vendors) {
        final products = await firebaseService.getProducts(widget.store.id, vendor.id);
        for (final p in products) {
          results.add(_ProductResult(p, vendor));
        }
      }
      if (mounted) {
        setState(() {
          _allProducts = results;
          _productsLoaded = true;
          _loadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Widget _sheetCell(String text, {double? width, bool left = false}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      alignment: left ? Alignment.centerLeft : Alignment.center,
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.6)),
    );
    return width != null ? SizedBox(width: width, child: child) : child;
  }

  Widget _sheetDivider({Color? color}) =>
      Container(width: 0.5, color: color ?? const Color(0xFFD0D5DD));

  Widget _buildSkuCoverageCard() {
    final total = _allProducts.length;
    final linked = _allProducts.where((r) => r.product.sku.isNotEmpty).length;
    final pct = total > 0 ? linked / total : 0.0;

    if (_loadingProducts && !_productsLoaded) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('Loading SKU coverage…',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (!_productsLoaded) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  linked == total ? Icons.check_circle : Icons.qr_code_scanner,
                  size: 20,
                  color: linked == total ? AppTheme.accentColor : AppTheme.warningColor,
                ),
                const SizedBox(width: 8),
                const Text('SKU Coverage (all vendors)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '$linked / $total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: linked == total ? AppTheme.accentColor : AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text('(${(pct * 100).toInt()}%)',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppTheme.borderColor,
                valueColor: AlwaysStoppedAnimation(
                    linked == total ? AppTheme.accentColor : AppTheme.warningColor),
              ),
            ),
            if (linked < total) ...[
              const SizedBox(height: 6),
              Text('${total - linked} products need SKU scanning',
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentStore.name),
            const Text('store_detail_screen.dart', style: TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
        elevation: 0,
      ),
      body: Consumer<VendorProvider>(
        builder: (context, vendorProvider, _) {
          // Filtered search results
          final searchResults = _searchQuery.trim().isEmpty
              ? <_ProductResult>[]
              : _allProducts
                  .where((r) {
                    final haystack = r.product.orderListProductName.isNotEmpty
                        ? r.product.orderListProductName
                        : r.product.name;
                    return smartMatch(_searchQuery, haystack);
                  })
                  .toList();

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                // ── Cross-vendor product search ──
                TextField(
                  controller: _searchController,
                  onChanged: (v) async {
                    setState(() => _searchQuery = v);
                    if (v.trim().isNotEmpty) await _ensureProductsLoaded();
                  },
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search products across all vendors…',
                    prefixIcon: _loadingProducts
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.trim().isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.accentColor),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Search results OR vendor list ──
                if (_searchQuery.trim().isNotEmpty) ...[
                  Expanded(
                    child: searchResults.isEmpty && !_loadingProducts
                        ? Center(
                            child: Text('No products match "$_searchQuery"',
                                style: TextStyle(fontSize: 13, color: AppTheme.textTertiary)),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFD0D5DD), width: 1.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              children: [
                                // ── Header ──
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF374151),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                                  ),
                                  child: Row(
                                    children: [
                                      _sheetCell('#', width: 28),
                                      _sheetDivider(color: Colors.white24),
                                      Expanded(child: _sheetCell('PRODUCT / VENDOR', left: true)),
                                      _sheetDivider(color: Colors.white24),
                                      _sheetCell('STORE', width: 62),
                                      _sheetDivider(color: Colors.white24),
                                      _sheetCell('SHOPIFY', width: 62),
                                    ],
                                  ),
                                ),
                                // ── Rows ──
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: searchResults.length,
                                    itemBuilder: (context, index) {
                                      final r = searchResults[index];
                                      final p = r.product;
                                      final isEven = index % 2 == 0;
                                      final rowBg = isEven ? Colors.white : const Color(0xFFF8FAFC);
                                      return InkWell(
                                        onTap: () {
                                          Navigator.of(context).pushNamed('/product', arguments: {
                                            'product': p,
                                            'store': widget.store,
                                            'vendor': r.vendor,
                                          });
                                        },
                                        child: Container(
                                          constraints: const BoxConstraints(minHeight: 48),
                                          decoration: BoxDecoration(
                                            color: rowBg,
                                            border: const Border(
                                                bottom: BorderSide(color: Color(0xFFD0D5DD), width: 0.5)),
                                          ),
                                          child: IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                // Row number
                                                Container(
                                                  width: 28,
                                                  color: const Color(0xFFF1F5F9),
                                                  alignment: Alignment.center,
                                                  child: Text('${index + 1}',
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppTheme.textTertiary)),
                                                ),
                                                _sheetDivider(),
                                                // Product name + vendor
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 6),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          p.orderListProductName.isNotEmpty
                                                              ? p.orderListProductName
                                                              : p.name,
                                                          style: const TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppTheme.textPrimary,
                                                              height: 1.2),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(r.vendor.name,
                                                            style: const TextStyle(
                                                                fontSize: 10,
                                                                color: AppTheme.textTertiary),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                _sheetDivider(),
                                                // Store price
                                                Container(
                                                  width: 62,
                                                  color: p.storePrice > 0
                                                      ? const Color(0xFFF0FDF4)
                                                      : rowBg,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    p.storePrice > 0
                                                        ? '\$${p.storePrice.toStringAsFixed(2)}'
                                                        : '—',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: p.storePrice > 0
                                                          ? const Color(0xFF065F46)
                                                          : AppTheme.textTertiary,
                                                    ),
                                                  ),
                                                ),
                                                _sheetDivider(),
                                                // Shopify price
                                                Container(
                                                  width: 62,
                                                  color: p.onlinePrice > 0
                                                      ? const Color(0xFFEFF6FF)
                                                      : rowBg,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    p.onlinePrice > 0
                                                        ? '\$${p.onlinePrice.toStringAsFixed(2)}'
                                                        : '—',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: p.onlinePrice > 0
                                                          ? const Color(0xFF1E40AF)
                                                          : AppTheme.textTertiary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // ── Footer ──
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE5E7EB),
                                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                                    border: Border(top: BorderSide(color: Color(0xFFD0D5DD))),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Text(
                                    '${searchResults.length} result${searchResults.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ] else ...[
                  // Normal vendor list
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('All Vendors', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 2),
                          Text(
                            '${vendorProvider.vendors.length} vendors available',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddVendorDialog(context, vendorProvider),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Vendor'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: vendorProvider.vendors.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(Icons.people_outline,
                                      size: 36, color: AppTheme.secondaryColor),
                                ),
                                const SizedBox(height: 16),
                                Text('No vendors yet',
                                    style: Theme.of(context).textTheme.headlineSmall),
                                const SizedBox(height: 8),
                                Text('Add your first vendor to get started',
                                    style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _showAddVendorDialog(context, vendorProvider),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add First Vendor'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: vendorProvider.vendors.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final vendor = vendorProvider.vendors[index];
                              return Card(
                                child: InkWell(
                                  onTap: () {
                                    vendorProvider.selectVendor(vendor);
                                    Navigator.of(context).pushNamed('/vendor', arguments: {
                                      'vendor': vendor,
                                      'store': widget.store,
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.business_rounded,
                                            color: AppTheme.accentColor, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            vendor.name,
                                            style: const TextStyle(
                                                fontSize: 13, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (vendor.whatsappPhoneNumber.isNotEmpty) ...[
                                          Icon(Icons.phone,
                                              size: 11, color: AppTheme.textTertiary),
                                          const SizedBox(width: 3),
                                          Text(vendor.whatsappPhoneNumber,
                                              style: Theme.of(context).textTheme.bodySmall),
                                          const SizedBox(width: 4),
                                        ],
                                        if (context
                                            .read<AuthProvider>()
                                            .hasPermission(AppRoles.deleteVendor))
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                minWidth: 28, minHeight: 28),
                                            icon: Icon(Icons.delete_outline,
                                                size: 16, color: AppTheme.textTertiary),
                                            onPressed: () => _confirmDeleteVendor(
                                                context, vendorProvider, vendor),
                                          ),
                                        Icon(Icons.chevron_right_rounded,
                                            color: AppTheme.textTertiary, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],

                // ── SKU Coverage at bottom ──
                if (_productsLoaded || _loadingProducts) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSkuCoverageCard(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddVendorDialog(BuildContext context, VendorProvider vendorProvider) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Vendor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Vendor Name',
                hintText: 'e.g. Apna Taste Distribution',
                prefixIcon: Icon(Icons.business, size: 20),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Phone',
                hintText: 'e.g. +1 416 555 0123',
                prefixIcon: Icon(Icons.phone, size: 20),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                vendorProvider.addVendor(
                  widget.store.id,
                  nameController.text,
                  phoneController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteVendor(BuildContext context, VendorProvider vendorProvider, Vendor vendor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text('Are you sure you want to delete "${vendor.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              vendorProvider.deleteVendor(widget.store.id, vendor.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
