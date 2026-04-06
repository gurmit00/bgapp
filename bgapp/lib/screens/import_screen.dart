import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dataController = TextEditingController();
  bool _isProcessing = false;
  List<Map<String, dynamic>> _previewData = [];
  String _importStatus = '';
  Store? _selectedStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().loadStores();
    });
  }

  @override
  void dispose() {
    _dataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Import Data'),
            const Text('import_screen.dart', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Card(
                color: AppTheme.secondaryColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Import Vendors & Products',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select a store, then paste CSV or tab-separated data with the following columns:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildFormatInfo(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Store Selector
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.store, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Select Store',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Consumer<StoreProvider>(
                        builder: (context, storeProvider, _) {
                          final stores = storeProvider.stores;
                          if (stores.isEmpty) {
                            return const Text('No stores found. Add a store first.');
                          }
                          return DropdownButtonFormField<Store>(
                            value: _selectedStore,
                            decoration: const InputDecoration(
                              labelText: 'Import products into…',
                              prefixIcon: Icon(Icons.store_mall_directory),
                              border: OutlineInputBorder(),
                            ),
                            items: stores
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.name),
                                    ))
                                .toList(),
                            onChanged: (store) {
                              setState(() => _selectedStore = store);
                            },
                            validator: (v) =>
                                v == null ? 'Please select a store' : null,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Data Input
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.content_paste, color: AppTheme.secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Paste Data',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dataController,
                        maxLines: 10,
                        decoration: InputDecoration(
                          hintText: 'Vendor Name\tProduct Name\tSKU\tPcs/Case\tPcs/Line\tPc Price\tCase Price\tPc Cost\tCase Cost\tMin Stock\tDefault Order\tVendor Phone',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (v) => v?.isEmpty == true ? 'Please paste data to import' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _previewImport,
                              icon: const Icon(Icons.preview),
                              label: const Text('Preview'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _clearData,
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Preview Section
              if (_previewData.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.table_chart, color: AppTheme.accentColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Preview (${_previewData.length} rows)',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Chip(
                              label: Text('${_getUniqueVendors()} vendors'),
                              backgroundColor: AppTheme.accentColor.withOpacity(0.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            itemCount: _previewData.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final row = _previewData[index];
                              final isDuplicate = row['isDuplicate'] == true;
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isDuplicate
                                      ? AppTheme.warningColor.withOpacity(0.2)
                                      : AppTheme.secondaryColor.withOpacity(0.2),
                                  child: isDuplicate
                                      ? Icon(Icons.content_copy, size: 14, color: AppTheme.warningColor)
                                      : Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                                ),
                                title: Text(
                                  row['productName'] ?? 'Unknown Product',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isDuplicate ? AppTheme.warningColor : null,
                                  ),
                                ),
                                subtitle: Text(
                                  isDuplicate
                                      ? '${row['vendorName']} • EXISTS – will be updated'
                                      : '${row['vendorName']} • SKU: ${row['sku'] ?? 'N/A'}',
                                  style: TextStyle(
                                    color: isDuplicate ? AppTheme.warningColor : AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isDuplicate
                                    ? Chip(
                                        label: const Text('UPDATE', style: TextStyle(fontSize: 10, color: Colors.white)),
                                        backgroundColor: AppTheme.warningColor,
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      )
                                    : Text(
                                        '\$${row['casePrice'] ?? '0'}/cs',
                                        style: TextStyle(color: AppTheme.accentColor),
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Status Message
              if (_importStatus.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _importStatus.contains('Error') 
                        ? Colors.red.withOpacity(0.1) 
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _importStatus.contains('Error') ? Colors.red : Colors.green,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _importStatus.contains('Error') ? Icons.error : Icons.check_circle,
                        color: _importStatus.contains('Error') ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_importStatus)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Import Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing || _previewData.isEmpty ? null : _importData,
                  icon: _isProcessing 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.upload),
                  label: Text(_isProcessing ? 'Importing...' : 'Import Data'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Required Columns:',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 4),
          _buildColumnRow('Vendor Name', 'Required - Name of the vendor'),
          _buildColumnRow('Product Name', 'Required - Name of the product'),
          const SizedBox(height: 8),
          Text(
            'Optional Columns:',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          _buildColumnRow('SKU/Barcode', 'Product identifier'),
          _buildColumnRow('Pcs per Case', 'Pieces per case (default: 1)'),
          _buildColumnRow('Pcs per Line', 'Pieces per line (default: 1)'),
          _buildColumnRow('Pc Price', 'Price per piece (default: 0)'),
          _buildColumnRow('Case Price', 'Price per case (default: 0)'),
          _buildColumnRow('Pc Cost', 'Cost per piece (default: 0)'),
          _buildColumnRow('Case Cost', 'Cost per case (default: 0)'),
          _buildColumnRow('Min Stock', 'Minimum stock in pieces (default: 0)'),
          _buildColumnRow('Default Order', 'Default order qty in cases (default: 0)'),
          _buildColumnRow('Vendor Phone', 'WhatsApp phone number (optional)'),
        ],
      ),
    );
  }

  Widget _buildColumnRow(String name, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(description, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  int _getUniqueVendors() {
    final vendors = _previewData.map((r) => r['vendorName']).toSet();
    return vendors.length;
  }

  void _clearData() {
    setState(() {
      _dataController.clear();
      _previewData.clear();
      _importStatus = '';
    });
  }

  // Expected fixed column order (0-indexed):
  // 0  Vendor
  // 1  Product Name
  // 2  SKU
  // 3  Pcs Per Case
  // 4  Pcs Per Line
  // 5  Pc Price
  // 6  Case Price
  // 7  Pc Cost
  // 8  Case Cost
  // 9  Min Stock
  // 10 Default Order
  // 11 On Hand (Pcs)   — ignored on import
  // 12 Order Qty (Cases) — ignored on import
  // 13 Vendor Phone

  /// Splits a CSV/TSV line respecting double-quoted fields.
  List<String> _splitLine(String line) {
    if (line.contains('\t')) return line.split('\t').map((c) => c.trim()).toList();
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString().trim());
    return result;
  }

  String _col(List<String> cols, int i) =>
      i < cols.length ? cols[i].trim() : '';

  void _previewImport() async {
    if (_selectedStore == null) {
      setState(() { _importStatus = 'Error: Please select a store first'; });
      return;
    }
    if (_dataController.text.isEmpty) {
      setState(() { _importStatus = 'Error: Please paste data to preview'; });
      return;
    }

    try {
      final lines = _dataController.text.trim().split('\n');
      final List<Map<String, dynamic>> parsedData = [];

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final cols = _splitLine(line);

        // Skip header row — first column is "Vendor" (case-insensitive)
        if (i == 0 && _col(cols, 0).toLowerCase() == 'vendor') continue;

        final vendorName = _col(cols, 0);
        final productName = _col(cols, 1);
        if (vendorName.isEmpty || productName.isEmpty) continue;

        parsedData.add({
          'vendorName':   vendorName,
          'productName':  productName,
          'sku':          _col(cols, 2),
          'pcsPerCase':   int.tryParse(_col(cols, 3)) ?? 1,
          'pcsPerLine':   int.tryParse(_col(cols, 4)) ?? 1,
          'pcPrice':      double.tryParse(_col(cols, 5)) ?? 0.0,
          'casePrice':    double.tryParse(_col(cols, 6)) ?? 0.0,
          'pcCost':       double.tryParse(_col(cols, 7)) ?? 0.0,
          'caseCost':     double.tryParse(_col(cols, 8)) ?? 0.0,
          'minStock':     int.tryParse(_col(cols, 9)) ?? 0,
          'defaultOrder': int.tryParse(_col(cols, 10)) ?? 0,
          // cols 11 (On Hand) and 12 (Order Qty) are skipped — order data only
          'vendorPhone':  _col(cols, 13),
          'sortOrder':    parsedData.length,
          'isDuplicate':  false,
        });
      }

      // ── Duplicate check ──
      int duplicateCount = 0;
      if (parsedData.isNotEmpty) {
        final firebaseService = FirebaseService();
        final vendorProvider = context.read<VendorProvider>();
        await vendorProvider.loadVendors(_selectedStore!.id);
        final existingVendors = vendorProvider.vendors;

        final vendorNames = parsedData.map((r) => (r['vendorName'] as String).toLowerCase()).toSet();

        for (final vName in vendorNames) {
          final existingVendor = existingVendors
              .where((v) => v.name.toLowerCase() == vName)
              .firstOrNull;
          if (existingVendor == null) continue;

          final existingProducts = await firebaseService.getProducts(_selectedStore!.id, existingVendor.id);

          for (var row in parsedData) {
            if ((row['vendorName'] as String).toLowerCase() != vName) continue;
            final isDup = existingProducts.any((p) =>
                p.name.toLowerCase() == (row['productName'] as String).toLowerCase());
            if (isDup) {
              row['isDuplicate'] = true;
              duplicateCount++;
            }
          }
        }
      }

      final dupMsg = duplicateCount > 0
          ? ' ($duplicateCount existing product(s) will be updated)'
          : '';

      setState(() {
        _previewData = parsedData;
        _importStatus = parsedData.isEmpty
            ? 'Error: No valid data found. Check format.'
            : 'Preview ready: ${parsedData.length} products from ${_getUniqueVendors()} vendors into ${_selectedStore!.name}$dupMsg';
      });
    } catch (e) {
      setState(() { _importStatus = 'Error parsing data: $e'; });
    }
  }

  Future<void> _importData() async {
    if (_selectedStore == null) {
      setState(() {
        _importStatus = 'Error: Please select a store first';
      });
      return;
    }
    if (_previewData.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _importStatus = 'Importing into ${_selectedStore!.name}...';
    });

    try {
      final firebaseService = FirebaseService();
      final vendorProvider = context.read<VendorProvider>();
      final storeId = _selectedStore!.id;

      // Load current vendors for this store
      await vendorProvider.loadVendors(storeId);

      // Group products by vendor — use lowercase trimmed key to prevent duplicates
      // from whitespace or case differences; preserve original casing in the row data.
      final Map<String, List<Map<String, dynamic>>> vendorProducts = {};
      for (var row in _previewData) {
        final key = (row['vendorName'] as String).trim().toLowerCase();
        row['vendorName'] = (row['vendorName'] as String).trim(); // normalise in-place
        vendorProducts.putIfAbsent(key, () => []);
        vendorProducts[key]!.add(row);
      }

      int vendorsCreated = 0;
      int productsCreated = 0;
      int productsUpdated = 0;
      List<String> updatedNames = [];

      // Process each vendor
      for (var entry in vendorProducts.entries) {
        // key is lowercase — use original casing from the first row
        final products = entry.value;
        final vendorName = products.first['vendorName'] as String;

        // Check if vendor already exists in this store
        var existingVendor = vendorProvider.vendors
            .where((v) => v.name.toLowerCase() == vendorName.toLowerCase())
            .firstOrNull;

        // Grab the first non-empty vendor phone from any row in this vendor group
        final vendorPhone = products
            .map((r) => (r['vendorPhone'] as String? ?? '').trim())
            .firstWhere((p) => p.isNotEmpty, orElse: () => '');

        String vendorId;
        if (existingVendor != null) {
          vendorId = existingVendor.id;

          // Update vendor phone if it was empty and the import provides one
          if (existingVendor.whatsappPhoneNumber.isEmpty && vendorPhone.isNotEmpty) {
            final updatedVendor = Vendor(
              id: existingVendor.id,
              name: existingVendor.name,
              whatsappPhoneNumber: vendorPhone,
              createdAt: existingVendor.createdAt,
            );
            await vendorProvider.updateVendor(storeId, updatedVendor);
          }
        } else {
          // Create new vendor under this store
          await vendorProvider.addVendor(storeId, vendorName, vendorPhone);
          vendorsCreated++;
          
          // Get the newly created vendor's ID
          final newVendor = vendorProvider.vendors
              .where((v) => v.name == vendorName)
              .firstOrNull;
          vendorId = newVendor?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
        }

        // Fetch existing products for this vendor in this store
        final existingProducts = await firebaseService.getProducts(storeId, vendorId);

        // Create or update products for this vendor
        for (var productData in products) {
          final productName = (productData['productName'] as String).trim();
          final productSku = (productData['sku'] as String? ?? '').trim();
          final productSortOrder = productData['sortOrder'] as int? ?? 0;

          // Check if product already exists by name (exact match, same vendor)
          final existingProduct = existingProducts.where((existing) {
            return existing.name.toLowerCase() == productName.toLowerCase();
          }).firstOrNull;

          if (existingProduct != null) {
            // Update the existing product with imported data
            final updated = Product(
              id: existingProduct.id,
              vendorId: vendorId,
              name: productName,
              sku: productSku.isNotEmpty ? productSku : existingProduct.sku,
              pcsPerCase: productData['pcsPerCase'] as int? ?? 1,
              pcsPerLine: productData['pcsPerLine'] as int? ?? 1,
              storePrice: (productData['pcPrice'] as num?)?.toDouble() ?? 0.0,
              onlinePrice: (productData['pcPrice'] as num?)?.toDouble() ?? 0.0,
              storeCasePrice: (productData['casePrice'] as num?)?.toDouble() ?? 0.0,
              onlineCasePrice: (productData['casePrice'] as num?)?.toDouble() ?? 0.0,
              pcCost: (productData['pcCost'] as num?)?.toDouble() ?? 0.0,
              caseCost: (productData['caseCost'] as num?)?.toDouble() ?? 0.0,
              reorderRule: ReorderRule(
                minStockPcs: productData['minStock'] as int? ?? 0,
                defaultOrderQty: productData['defaultOrder'] as int? ?? 0,
              ),
              sortOrder: productSortOrder,
              frontImageBase64: existingProduct.frontImageBase64,
              backImageBase64: existingProduct.backImageBase64,
              createdAt: existingProduct.createdAt,
            );
            await firebaseService.updateProduct(storeId, vendorId, updated);
            productsUpdated++;
            updatedNames.add(productName);
            continue;
          }

          final product = Product(
            id: '${vendorId}_${DateTime.now().millisecondsSinceEpoch}_${productsCreated}',
            vendorId: vendorId,
            name: productName,
            sku: productSku,
            pcsPerCase: productData['pcsPerCase'] as int? ?? 1,
            pcsPerLine: productData['pcsPerLine'] as int? ?? 1,
            storePrice: (productData['pcPrice'] as num?)?.toDouble() ?? 0.0,
            onlinePrice: (productData['pcPrice'] as num?)?.toDouble() ?? 0.0,
            storeCasePrice: (productData['casePrice'] as num?)?.toDouble() ?? 0.0,
            onlineCasePrice: (productData['casePrice'] as num?)?.toDouble() ?? 0.0,
            pcCost: (productData['pcCost'] as num?)?.toDouble() ?? 0.0,
            caseCost: (productData['caseCost'] as num?)?.toDouble() ?? 0.0,
            reorderRule: ReorderRule(
              minStockPcs: productData['minStock'] as int? ?? 0,
              defaultOrderQty: productData['defaultOrder'] as int? ?? 0,
            ),
            sortOrder: productSortOrder,
            createdAt: DateTime.now(),
          );

          await firebaseService.addProduct(storeId, vendorId, product);
          productsCreated++;
        }
      }

      final updatedMsg = productsUpdated > 0
          ? ' Updated $productsUpdated existing product(s): ${updatedNames.take(5).join(", ")}${updatedNames.length > 5 ? "…" : ""}'
          : '';

      setState(() {
        _isProcessing = false;
        _importStatus = 'Success! Imported into ${_selectedStore!.name}: $vendorsCreated new vendors, $productsCreated new products.$updatedMsg';
        _previewData.clear();
        _dataController.clear();
      });

      if (mounted) {
        final snackMsg = productsUpdated > 0
            ? 'Imported $productsCreated new, updated $productsUpdated existing'
            : 'Imported $vendorsCreated vendors and $productsCreated products';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackMsg),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _importStatus = 'Error during import: $e';
      });
    }
  }
}
