import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/utils/theme.dart';
import 'package:newstore_ordering_app/utils/app_roles.dart';
import 'package:newstore_ordering_app/utils/fuzzy_search.dart';

class VendorDetailScreen extends StatefulWidget {
  final Vendor vendor;
  final Store store;

  const VendorDetailScreen({Key? key, required this.vendor, required this.store}) : super(key: key);

  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Excel-style grid design (matches order_creation_screen)
  static const _gridColor = Color(0xFFD0D5DD);
  static const _headerBg = Color(0xFF374151);
  static const _rowEvenBg = Colors.white;
  static const _rowOddBg = Color(0xFFF8FAFC);
  static const _rowNumberBg = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProductsByVendor(widget.store.id, widget.vendor.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── SKU coverage helpers ──────────────────────────────────
  int _skuCount(List<Product> products) => products.where((p) => p.sku.isNotEmpty).length;

  // ── Scan-to-link ─────────────────────────────────────────
  void _scanForProduct(Product product) async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _BarcodeScannerPage(productName: product.orderListProductName),
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
      orderListProductName: product.orderListProductName,
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
          content: Text('SKU $sku linked to "${product.orderListProductName}"'),
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
            Text(product.orderListProductName, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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

  // ── Header cell helper ────────────────────────────────────
  Widget _headerCell(String text, {double? width, TextAlign align = TextAlign.center}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      alignment: align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
        textAlign: align,
      ),
    );
    return width != null ? SizedBox(width: width, child: child) : child;
  }

  // ── Vertical grid divider ─────────────────────────────────
  Widget _verticalDivider({Color? color}) {
    return Container(width: 0.5, color: color ?? _gridColor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
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

          // Sort: no-SKU first, then by sortOrder
          final sorted = List<Product>.from(products);
          sorted.sort((a, b) {
            final aHas = a.sku.isNotEmpty ? 1 : 0;
            final bHas = b.sku.isNotEmpty ? 1 : 0;
            if (aHas != bHas) return aHas - bHas;
            return a.sortOrder.compareTo(b.sortOrder);
          });

          final indexed = sorted.asMap().entries.toList();
          final filtered = _searchQuery.trim().isEmpty
              ? indexed
              : indexed.where((e) {
                  final haystack = e.value.orderListProductName.isNotEmpty
                      ? e.value.orderListProductName
                      : e.value.name;
                  return smartMatch(_searchQuery, haystack);
                }).toList();

          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Column(
              children: [
                // ── Spreadsheet Container ──
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _gridColor, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        // ── Header Row ──
                        Container(
                          decoration: const BoxDecoration(
                            color: _headerBg,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                          child: Row(
                            children: [
                              _headerCell('#', width: 32),
                              _verticalDivider(color: Colors.white24),
                              SizedBox(width: 52, child: _headerCell('')),
                              _verticalDivider(color: Colors.white24),
                              Expanded(child: _headerCell('PRODUCT / SKU', align: TextAlign.left)),
                            ],
                          ),
                        ),

                        // ── Search Bar ──
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            border: Border(bottom: BorderSide(color: _gridColor, width: 0.5)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search products…',
                              hintStyle: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              suffixIcon: _searchQuery.trim().isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: _gridColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: _gridColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: AppTheme.accentColor),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),

                        // ── Product Rows ──
                        Expanded(
                          child: products.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 32, color: AppTheme.textTertiary),
                                      const SizedBox(height: 8),
                                      Text('No products yet',
                                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                )
                              : filtered.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No products match "$_searchQuery"',
                                        style: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.only(bottom: 80),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, listIndex) {
                                        final originalIndex = filtered[listIndex].key;
                                        final p = filtered[listIndex].value;
                                        final hasSku = p.sku.isNotEmpty;
                                        final isEven = originalIndex % 2 == 0;

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: hasSku
                                                ? (isEven ? _rowEvenBg : _rowOddBg)
                                                : const Color(0xFFFFF7ED),
                                            border: const Border(
                                                bottom: BorderSide(color: _gridColor, width: 0.5)),
                                          ),
                                          constraints: const BoxConstraints(minHeight: 56),
                                          child: InkWell(
                                            onTap: hasSku
                                                ? () {
                                                    Navigator.of(context)
                                                        .pushNamed('/product', arguments: {
                                                      'product': p,
                                                      'store': widget.store,
                                                      'vendor': widget.vendor,
                                                    });
                                                  }
                                                : () => _scanForProduct(p),
                                            child: IntrinsicHeight(
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  // Row number
                                                  Container(
                                                    width: 32,
                                                    color: _rowNumberBg,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      '${originalIndex + 1}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme.textTertiary,
                                                      ),
                                                    ),
                                                  ),
                                                  _verticalDivider(),

                                                  // Product image
                                                  Container(
                                                    width: 52,
                                                    color: isEven ? _rowEvenBg : _rowOddBg,
                                                    alignment: Alignment.center,
                                                    child: Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: p.shopifyImageUrl.isNotEmpty
                                                            ? Colors.white
                                                            : (hasSku
                                                                ? AppTheme.accentColor.withOpacity(0.08)
                                                                : AppTheme.warningColor.withOpacity(0.08)),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(
                                                          color: p.shopifyImageUrl.isNotEmpty
                                                              ? AppTheme.dividerColor
                                                              : (hasSku
                                                                  ? AppTheme.accentColor.withOpacity(0.3)
                                                                  : AppTheme.warningColor.withOpacity(0.3)),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: p.shopifyImageUrl.isNotEmpty
                                                          ? ClipRRect(
                                                              borderRadius: BorderRadius.circular(5),
                                                              child: Image.network(
                                                                p.shopifyImageUrl,
                                                                fit: BoxFit.contain,
                                                                errorBuilder: (_, __, ___) => Icon(
                                                                    Icons.image_not_supported,
                                                                    size: 16,
                                                                    color: AppTheme.textTertiary),
                                                                loadingBuilder: (_, child, progress) =>
                                                                    progress == null
                                                                        ? child
                                                                        : const Center(
                                                                            child: SizedBox(
                                                                                width: 12,
                                                                                height: 12,
                                                                                child:
                                                                                    CircularProgressIndicator(
                                                                                        strokeWidth: 1.5))),
                                                              ),
                                                            )
                                                          : Icon(
                                                              hasSku ? Icons.check : Icons.qr_code_scanner,
                                                              size: 16,
                                                              color: hasSku
                                                                  ? AppTheme.accentColor
                                                                  : AppTheme.warningColor,
                                                            ),
                                                    ),
                                                  ),
                                                  _verticalDivider(),

                                                  // Product info + actions
                                                  Expanded(
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 10, vertical: 8),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment.start,
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment.center,
                                                              children: [
                                                                Text(
                                                                  p.name,
                                                                  style: const TextStyle(
                                                                    fontSize: 15,
                                                                    fontWeight: FontWeight.w700,
                                                                    color: AppTheme.textPrimary,
                                                                    height: 1.25,
                                                                  ),
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                const SizedBox(height: 3),
                                                                if (hasSku)
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                        horizontal: 5, vertical: 1),
                                                                    decoration: BoxDecoration(
                                                                      color: const Color(0xFFE0E7FF),
                                                                      borderRadius:
                                                                          BorderRadius.circular(3),
                                                                    ),
                                                                    child: Text(
                                                                      p.sku,
                                                                      style: const TextStyle(
                                                                        fontSize: 10,
                                                                        fontWeight: FontWeight.w600,
                                                                        color: Color(0xFF4338CA),
                                                                        letterSpacing: 0.3,
                                                                      ),
                                                                    ),
                                                                  )
                                                                else
                                                                  Text(
                                                                    'Tap to scan SKU',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      color: AppTheme.warningColor,
                                                                      fontStyle: FontStyle.italic,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),

                                                          // Action buttons
                                                          if (!hasSku) ...[
                                                            IconButton(
                                                              icon: Icon(Icons.keyboard,
                                                                  size: 18,
                                                                  color: AppTheme.textSecondary),
                                                              tooltip: 'Enter SKU manually',
                                                              onPressed: () => _manualSkuEntry(p),
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(
                                                                  minWidth: 32, minHeight: 32),
                                                            ),
                                                            IconButton(
                                                              icon: Icon(Icons.qr_code_scanner,
                                                                  size: 18,
                                                                  color: AppTheme.warningColor),
                                                              tooltip: 'Scan barcode',
                                                              onPressed: () => _scanForProduct(p),
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(
                                                                  minWidth: 32, minHeight: 32),
                                                            ),
                                                          ] else ...[
                                                            Icon(Icons.chevron_right,
                                                                size: 20, color: AppTheme.textTertiary),
                                                          ],

                                                          // Delete — admin only
                                                          if (context
                                                              .read<AuthProvider>()
                                                              .hasPermission(AppRoles.deleteProduct))
                                                            IconButton(
                                                              icon: Icon(Icons.close,
                                                                  size: 14,
                                                                  color: AppTheme.errorColor
                                                                      .withOpacity(0.4)),
                                                              onPressed: () => _confirmDeleteProduct(
                                                                  context, productProvider, p),
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(
                                                                  minWidth: 28, minHeight: 28),
                                                              splashRadius: 16,
                                                            ),
                                                        ],
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
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius:
                                const BorderRadius.vertical(bottom: Radius.circular(3)),
                            border: Border(top: BorderSide(color: _gridColor, width: 1)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              const SizedBox(width: 32),
                              Expanded(
                                child: Text(
                                  _searchQuery.isEmpty
                                      ? '$total products · $linked with SKU'
                                      : '${filtered.length} of $total · $linked with SKU',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
                  reorderRule: ReorderRule(),
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

  void _confirmDeleteProduct(
      BuildContext context, ProductProvider productProvider, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.orderListProductName}"?'),
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
          IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _controller.toggleTorch(),
              tooltip: 'Flash'),
          IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: () => _controller.switchCamera(),
              tooltip: 'Switch'),
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
                border: Border.all(
                    color: _hasScanned ? AppTheme.accentColor : Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration:
                  BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Scanning for: ${widget.productName}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
                decoration: BoxDecoration(
                    color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  _hasScanned ? 'Scanned!' : 'Point at barcode',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
