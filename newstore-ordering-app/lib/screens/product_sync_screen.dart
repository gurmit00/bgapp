import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/services/sync_service.dart';
import 'package:newstore_ordering_app/utils/theme.dart';
import 'package:newstore_ordering_app/utils/csv_export.dart';

/// Bulk Product Sync screen.
/// Lets the user pick a store → vendor, see all products, and:
///   1. Sync selected products to Shopify (create/update)
///   2. Export selected products to Bombay Grocers Penny Lane POS format
class ProductSyncScreen extends StatefulWidget {
  const ProductSyncScreen({Key? key}) : super(key: key);

  @override
  State<ProductSyncScreen> createState() => _ProductSyncScreenState();
}

class _ProductSyncScreenState extends State<ProductSyncScreen> {
  Store? _selectedStore;
  Vendor? _selectedVendor;
  List<Product> _products = [];
  Set<String> _selectedIds = {};
  bool _selectAll = false;

  // Sync progress
  bool _isSyncing = false;
  int _syncTotal = 0;
  int _syncDone = 0;
  int _syncCreated = 0;
  int _syncUpdated = 0;
  int _syncFailed = 0;
  String _syncCurrentName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().loadStores();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product Sync', style: TextStyle(fontSize: 16)),
            const Text('product_sync_screen.dart', style: TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Store & Vendor picker
          _buildPickerBar(),

          // Select All / Actions bar
          if (_products.isNotEmpty) _buildActionsBar(),

          // Sync progress
          if (_isSyncing) _buildProgressBar(),

          // Product list
          Expanded(
            child: _products.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync_rounded, size: 64, color: AppTheme.textTertiary),
                          const SizedBox(height: 16),
                          Text(
                            'Select a store and vendor to see products',
                            style: TextStyle(fontSize: 14, color: AppTheme.textTertiary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) => _buildProductTile(_products[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerBar() {
    final stores = context.watch<StoreProvider>().stores;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list_rounded, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('Select Products', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Store>(
                    value: _selectedStore,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Store',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.store, size: 18),
                    ),
                    items: stores.map((s) => DropdownMenuItem(value: s, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (store) {
                      setState(() {
                        _selectedStore = store;
                        _selectedVendor = null;
                        _products = [];
                        _selectedIds = {};
                      });
                      if (store != null) {
                        context.read<VendorProvider>().loadVendors(store.id);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Consumer<VendorProvider>(
                    builder: (ctx, vp, _) {
                      return DropdownButtonFormField<Vendor>(
                        value: _selectedVendor,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Vendor',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business, size: 18),
                        ),
                        items: vp.vendors.map((v) => DropdownMenuItem(value: v, child: Text(v.name, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (vendor) {
                          setState(() {
                            _selectedVendor = vendor;
                            _selectedIds = {};
                          });
                          if (_selectedStore != null && vendor != null) {
                            _loadProducts(_selectedStore!, vendor);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadProducts(Store store, Vendor vendor) async {
    await context.read<ProductProvider>().loadProductsByVendor(store.id, vendor.id);
    setState(() {
      _products = context.read<ProductProvider>().products;
    });
  }

  Widget _buildActionsBar() {
    final count = _selectedIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.primaryColor.withOpacity(0.05),
      child: Row(
        children: [
          // Select all checkbox
          Checkbox(
            value: _selectAll,
            onChanged: (val) {
              setState(() {
                _selectAll = val ?? false;
                _selectedIds = _selectAll
                    ? _products.map((p) => p.id).toSet()
                    : {};
              });
            },
          ),
          Text(
            count == 0 ? 'Select all (${_products.length})' : '$count selected',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),

          // Sync to Shopify
          ElevatedButton.icon(
            onPressed: count == 0 || _isSyncing ? null : _bulkSyncToShopify,
            icon: const Icon(Icons.shopping_bag_outlined, size: 16),
            label: const Text('Shopify', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF96BF48),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
          ),
          const SizedBox(width: 8),

          // Export to POS
          OutlinedButton.icon(
            onPressed: count == 0 || _isSyncing ? null : _bulkExportToPOS,
            icon: Icon(Icons.point_of_sale, size: 16, color: AppTheme.primaryColor),
            label: Text('POS Export', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final pct = _syncTotal > 0 ? _syncDone / _syncTotal : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFF0FDF4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Syncing: $_syncCurrentName ($_syncDone/$_syncTotal)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, minHeight: 6),
          ),
          const SizedBox(height: 4),
          Text(
            '✓ Created: $_syncCreated  |  ↻ Updated: $_syncUpdated  |  ✗ Failed: $_syncFailed',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(Product product) {
    final selected = _selectedIds.contains(product.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: Checkbox(
          value: selected,
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedIds.add(product.id);
              } else {
                _selectedIds.remove(product.id);
              }
              _selectAll = _selectedIds.length == _products.length;
            });
          },
        ),
        title: Text(product.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(
          'SKU: ${product.sku.isNotEmpty ? product.sku : "—"}  ·  Store: \$${product.storePrice}  ·  Online: \$${product.onlinePrice}',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        trailing: product.frontImageBase64.isNotEmpty
            ? const Icon(Icons.image, size: 16, color: Colors.green)
            : Icon(Icons.image_not_supported_outlined, size: 16, color: AppTheme.textTertiary),
      ),
    );
  }

  Future<void> _bulkSyncToShopify() async {
    final selected = _products.where((p) => _selectedIds.contains(p.id) && p.sku.isNotEmpty).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products with SKU selected')),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncTotal = selected.length;
      _syncDone = 0;
      _syncCreated = 0;
      _syncUpdated = 0;
      _syncFailed = 0;
    });

    for (final product in selected) {
      setState(() => _syncCurrentName = product.name);

      try {
        final result = await SyncService().syncProductToShopify(
          title: product.name,
          sku: product.sku,
          barcode: product.sku,
          price: product.onlinePrice.toString(), // Online price → Shopify
          vendor: _selectedVendor?.name ?? '',
          description: product.name,
          tags: product.shopifyTags.join(', '),
        );

        if (result != null && result['success'] == true) {
          final action = result['action'] ?? '';
          setState(() {
            if (action == 'created') _syncCreated++;
            else _syncUpdated++;
          });
        } else {
          setState(() => _syncFailed++);
        }
      } catch (e) {
        setState(() => _syncFailed++);
      }

      setState(() => _syncDone++);

      // Small delay to avoid rate-limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _isSyncing = false;
      _syncCurrentName = '';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shopify sync complete: $_syncCreated created, $_syncUpdated updated, $_syncFailed failed'),
          backgroundColor: _syncFailed == 0 ? const Color(0xFF047857) : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _bulkExportToPOS() async {
    final selected = _products.where((p) => _selectedIds.contains(p.id) && p.sku.isNotEmpty).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products with SKU selected')),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final productsData = selected.map((p) => {
        'sku': p.sku,
        'name': p.name,
        'price': p.storePrice.toString(), // Store price → POS
        'cost': p.pcCost.toString(),
        'department': p.posDepartment,
        'departmentName': p.posDepartmentName,
        'vendor': _selectedVendor?.name ?? '',
        'taxCode': p.posTaxCode,
        'reorderLevel': p.reorderRule.minStockPcs.toString(),
        'reorderQty': p.reorderRule.defaultOrderQty.toString(),
      }).toList();

      final csv = await SyncService().generatePosImport(productsData);

      setState(() => _isSyncing = false);

      if (mounted && csv != null) {
        _showPosExportDialog(csv, selected.length);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('POS export failed'), backgroundColor: AppTheme.errorColor),
        );
      }
    } catch (e) {
      setState(() => _isSyncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showPosExportDialog(String csv, int count) {
    showDialog(
      context: context,
      builder: (ctx) => _BulkPosExportDialog(newCodesContent: csv, count: count),
    );
  }
}

/// Bulk POS Export Dialog with Cloud Upload support (reused from product_detail).
class _BulkPosExportDialog extends StatefulWidget {
  final String newCodesContent;
  final int count;

  const _BulkPosExportDialog({required this.newCodesContent, required this.count});

  @override
  State<_BulkPosExportDialog> createState() => _BulkPosExportDialogState();
}

class _BulkPosExportDialogState extends State<_BulkPosExportDialog> {
  bool _isUploading = false;
  bool _uploaded = false;
  String? _downloadUrl;
  bool _showScript = false;

  Future<void> _uploadToCloud() async {
    setState(() => _isUploading = true);

    try {
      final url = await SyncService().uploadNewCodesToCloud(widget.newCodesContent)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        debugPrint('_uploadToCloud: timed out after 30s');
        return null;
      });
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploaded = url != null;
          _downloadUrl = url;
        });

        if (url != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ updateproduct.PLU uploaded to cloud'),
              backgroundColor: Color(0xFF047857),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload failed — check connection'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: const Color(0xFF047857),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.point_of_sale, color: Color(0xFF047857)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Penny Lane POS (${widget.count} products)',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── NewCodes Content ──
              const Text(
                'NewCodes.txt content:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    widget.newCodesContent,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Action Buttons ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(widget.newCodesContent, 'NewCodes.txt'),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadToCloud,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              _uploaded ? Icons.cloud_done : Icons.cloud_upload,
                              size: 16,
                            ),
                      label: Text(
                        _isUploading
                            ? 'Uploading…'
                            : _uploaded
                                ? 'Uploaded ✓'
                                : 'Upload to Cloud',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _uploaded ? const Color(0xFF047857) : const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Upload Success ──
              if (_uploaded && _downloadUrl != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6EE7B7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF047857), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Ready for POS pickup!',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The Windows POS machine will auto-download this file '
                        'on next startup via the batch script.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _copyToClipboard(_downloadUrl!, 'Download URL'),
                        child: Row(
                          children: [
                            const Icon(Icons.link, size: 14, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _downloadUrl!,
                                style: const TextStyle(fontSize: 9, color: Color(0xFF2563EB)),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const Icon(Icons.copy, size: 12, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Windows Script Toggle ──
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setState(() => _showScript = !_showScript),
                  child: Row(
                    children: [
                      Icon(
                        _showScript ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showScript ? 'Hide Windows Script' : 'Show Windows Auto-Download Script',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                if (_showScript) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        SyncService().generateWindowsBatchScript(downloadUrl: _downloadUrl),
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(
                            SyncService().generateWindowsBatchScript(downloadUrl: _downloadUrl),
                            'Batch script',
                          ),
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('Copy .bat', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(
                            SyncService().generatePowerShellScript(downloadUrl: _downloadUrl),
                            'PowerShell script',
                          ),
                          icon: const Icon(Icons.terminal, size: 14),
                          label: const Text('Copy .ps1', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
