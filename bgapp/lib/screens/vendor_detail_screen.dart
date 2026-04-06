import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/utils/theme.dart';
import 'package:newstore_ordering_app/utils/app_roles.dart';

class VendorDetailScreen extends StatefulWidget {
  final Vendor vendor;
  final Store store;

  const VendorDetailScreen({Key? key, required this.vendor, required this.store}) : super(key: key);

  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProductsByVendor(widget.store.id, widget.vendor.id);
    });
  }

  // ── SKU coverage helpers ──────────────────────────────────
  int _skuCount(List<Product> products) => products.where((p) => p.sku.isNotEmpty).length;

  // ── Scan-to-link: open scanner targeting a specific product ─
  void _scanForProduct(Product product) async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _BarcodeScannerPage(productName: product.name),
      ),
    );
    if (scanned != null && scanned.isNotEmpty && mounted) {
      await _linkSkuToProduct(product, scanned);
    }
  }

  // ── Link scanned SKU to product in Firestore ──────────────
  Future<void> _linkSkuToProduct(Product product, String sku) async {
    final updated = Product(
      id: product.id,
      vendorId: product.vendorId,
      name: product.name,
      sku: sku,
      pcsPerCase: product.pcsPerCase,
      pcsPerLine: product.pcsPerLine,
      storePrice: product.storePrice,
      onlinePrice: product.onlinePrice,
      storeCasePrice: product.storeCasePrice,
      onlineCasePrice: product.onlineCasePrice,
      pcCost: product.pcCost,
      caseCost: product.caseCost,
      posTaxCode: product.posTaxCode,
      shopifyTaxable: product.shopifyTaxable,
      posDepartment: product.posDepartment,
      posDepartmentName: product.posDepartmentName,
      shopifyTags: product.shopifyTags,
      shopifyCollection: product.shopifyCollection,
      categoryConfirmed: product.categoryConfirmed,
      shopifyImageUrl: product.shopifyImageUrl,
      reorderRule: product.reorderRule,
      sortOrder: product.sortOrder,
      createdAt: product.createdAt,
    );

    await context.read<ProductProvider>().updateProduct(
      widget.store.id, widget.vendor.id, updated,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SKU $sku linked to "${product.name}"'),
          backgroundColor: AppTheme.accentColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Manual SKU entry dialog ───────────────────────────────
  void _manualSkuEntry(Product product) {
    final controller = TextEditingController(text: product.sku);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.sku.isEmpty ? 'Enter SKU' : 'Edit SKU'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(product.name, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'SKU / Barcode',
                prefixIcon: Icon(Icons.qr_code, size: 20),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  _linkSkuToProduct(product, v.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final sku = controller.text.trim();
              if (sku.isNotEmpty) {
                Navigator.pop(ctx);
                _linkSkuToProduct(product, sku);
              }
            },
            child: const Text('Save'),
          ),
        ],
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
            Text(widget.vendor.name),
            Text(widget.store.name, style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: 'Edit Vendor',
            onPressed: () => _showEditVendorDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Product',
            onPressed: () => _showAddProductDialog(context, context.read<ProductProvider>()),
          ),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, _) {
          final products = productProvider.products;
          final total = products.length;
          final linked = _skuCount(products);
          final pct = total > 0 ? (linked / total) : 0.0;

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                // ── SKU Coverage Card ──
                if (total > 0)
                  Card(
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
                              Text(
                                'SKU Coverage',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
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
                              Text(
                                '(${(pct * 100).toInt()}%)',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
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
                                linked == total ? AppTheme.accentColor : AppTheme.warningColor,
                              ),
                            ),
                          ),
                          if (linked < total) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${total - linked} products need SKU scanning',
                              style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // ── Products Header ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text(
                        'Products ($total)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 30,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddProductDialog(context, productProvider),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Add', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Products List ──
                Expanded(
                  child: products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 32, color: AppTheme.textTertiary),
                              const SizedBox(height: 8),
                              Text('No products yet', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                          ),
                        )
                      : _buildProductList(context, productProvider),
                ),
              ],
            ),
          );
        },
      ),
      // Create Order FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed(
            '/order-creation',
            arguments: {
              'store': widget.store,
              'vendor': widget.vendor,
            },
          );
        },
        backgroundColor: AppTheme.accentColor,
        icon: const Icon(Icons.receipt_long),
        label: const Text('Create Order'),
      ),
    );
  }

  Widget _buildProductList(BuildContext context, ProductProvider productProvider) {
    // Sort: products without SKU first (need attention), then by name
    final products = List<Product>.from(productProvider.products);
    products.sort((a, b) {
      final aHas = a.sku.isNotEmpty ? 1 : 0;
      final bHas = b.sku.isNotEmpty ? 1 : 0;
      if (aHas != bHas) return aHas - bHas; // no-SKU first
      return a.sortOrder.compareTo(b.sortOrder);
    });

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        final hasSku = p.sku.isNotEmpty;

        return InkWell(
          onTap: hasSku
              ? () {
                  // Go to Product Hub for products with SKU
                  final stores = context.read<StoreProvider>().stores;
                  Navigator.of(context).pushNamed('/product-lookup', arguments: {
                    'sku': p.sku,
                    'allStores': stores,
                  });
                }
              : () => _scanForProduct(p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: hasSku
                  ? (index.isEven ? Colors.white : const Color(0xFFF8FAFC))
                  : const Color(0xFFFFF7ED), // warm orange tint for missing SKU
              border: const Border(bottom: BorderSide(color: AppTheme.dividerColor, width: 0.5)),
            ),
            child: Row(
              children: [
                // Row number
                SizedBox(
                  width: 26,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 6),

                // Product image thumbnail (Shopify image if available, else status icon)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.shopifyImageUrl.isNotEmpty
                        ? Colors.white
                        : (hasSku ? AppTheme.accentColor.withOpacity(0.08) : AppTheme.warningColor.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: p.shopifyImageUrl.isNotEmpty
                          ? AppTheme.dividerColor
                          : (hasSku ? AppTheme.accentColor.withOpacity(0.3) : AppTheme.warningColor.withOpacity(0.3)),
                      width: 1,
                    ),
                  ),
                  child: p.shopifyImageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.network(
                            p.shopifyImageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, size: 18, color: AppTheme.textTertiary),
                            loadingBuilder: (_, child, progress) =>
                                progress == null ? child : const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))),
                          ),
                        )
                      : Icon(
                          hasSku ? Icons.check : Icons.qr_code_scanner,
                          size: 18,
                          color: hasSku ? AppTheme.accentColor : AppTheme.warningColor,
                        ),
                ),
                const SizedBox(width: 10),

                // Product name + SKU
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasSku)
                        Text(
                          p.sku,
                          style: TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontFamily: 'monospace'),
                        )
                      else
                        Text(
                          'Tap to scan SKU',
                          style: TextStyle(fontSize: 11, color: AppTheme.warningColor, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),

                // Action buttons
                if (!hasSku) ...[
                  // Manual entry
                  IconButton(
                    icon: Icon(Icons.keyboard, size: 18, color: AppTheme.textSecondary),
                    tooltip: 'Enter SKU manually',
                    onPressed: () => _manualSkuEntry(p),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  // Scan
                  IconButton(
                    icon: Icon(Icons.qr_code_scanner, size: 18, color: AppTheme.warningColor),
                    tooltip: 'Scan barcode',
                    onPressed: () => _scanForProduct(p),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ] else ...[
                  // Navigate arrow for linked products
                  Icon(Icons.chevron_right, size: 20, color: AppTheme.textTertiary),
                ],

                // Delete — admin only
                if (context.read<AuthProvider>().hasPermission(AppRoles.deleteProduct))
                  IconButton(
                    icon: Icon(Icons.close, size: 14, color: AppTheme.errorColor.withOpacity(0.4)),
                    onPressed: () => _confirmDeleteProduct(context, productProvider, p),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    splashRadius: 16,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditVendorDialog(BuildContext context) {
    final nameController = TextEditingController(text: widget.vendor.name);
    final phoneController = TextEditingController(text: widget.vendor.whatsappPhoneNumber);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Vendor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Vendor Name',
                prefixIcon: Icon(Icons.business, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Phone Number',
                hintText: 'e.g. 14155551234',
                prefixIcon: Icon(Icons.phone, size: 20),
                helperText: 'Include country code, no dashes or spaces',
                helperMaxLines: 2,
              ),
              keyboardType: TextInputType.phone,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;

              final updatedVendor = Vendor(
                id: widget.vendor.id,
                name: newName,
                whatsappPhoneNumber: phoneController.text.trim(),
                createdAt: widget.vendor.createdAt,
              );

              await context.read<VendorProvider>().updateVendor(widget.store.id, updatedVendor);

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vendor updated'), backgroundColor: Colors.green),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, ProductProvider productProvider) {
    final nameController = TextEditingController();
    final skuController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                prefixIcon: Icon(Icons.label, size: 20),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: skuController,
              decoration: const InputDecoration(
                labelText: 'SKU / Barcode (optional)',
                prefixIcon: Icon(Icons.qr_code, size: 20),
                helperText: 'You can scan it later',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final product = Product(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  vendorId: widget.vendor.id,
                  name: nameController.text.trim(),
                  sku: skuController.text.trim(),
                  pcsPerCase: 1,
                  pcsPerLine: 1,
                  reorderRule: ReorderRule(minStockPcs: 0, defaultOrderQty: 0),
                  createdAt: DateTime.now(),
                );
                productProvider.addProduct(widget.store.id, widget.vendor.id, product);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, ProductProvider productProvider, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              productProvider.deleteProduct(widget.store.id, widget.vendor.id, product.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Barcode Scanner Page (scan-to-link) ──────────────────────
class _BarcodeScannerPage extends StatefulWidget {
  final String productName;
  const _BarcodeScannerPage({required this.productName});

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
      setState(() => _hasScanned = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.pop(context, barcode.rawValue!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scan SKU', style: TextStyle(fontSize: 16)),
            Text(widget.productName, style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _controller.toggleTorch(), tooltip: 'Flash'),
          IconButton(icon: const Icon(Icons.cameraswitch), onPressed: () => _controller.switchCamera(), tooltip: 'Switch'),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: _hasScanned ? AppTheme.accentColor : Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Product name banner
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Scanning for: ${widget.productName}',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  _hasScanned ? 'Scanned!' : 'Point at barcode',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
