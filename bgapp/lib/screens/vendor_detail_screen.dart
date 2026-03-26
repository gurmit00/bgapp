import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.vendor.name),
            const Text('vendor_detail_screen.dart', style: TextStyle(fontSize: 10, color: Colors.white38)),
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
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                // Vendor Info Strip
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.business_rounded, color: AppTheme.accentColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.vendor.name, style: Theme.of(context).textTheme.titleMedium),
                              if (widget.vendor.whatsappPhoneNumber.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(Icons.phone, size: 13, color: AppTheme.textTertiary),
                                    const SizedBox(width: 4),
                                    Text(widget.vendor.whatsappPhoneNumber, style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                )
                              else
                                GestureDetector(
                                  onTap: () => _showEditVendorDialog(context),
                                  child: Row(
                                    children: [
                                      Icon(Icons.phone_missed, size: 13, color: AppTheme.warningColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        'No WhatsApp phone – tap to add',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.warningColor,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.store != null)
                          Chip(
                            label: Text(widget.store.name, style: const TextStyle(fontSize: 11)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Products Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text(
                        'Products (${productProvider.products.length})',
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

                // Spreadsheet-style Products Table
                Expanded(
                  child: productProvider.products.isEmpty
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
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // extra space so FAB doesn't cover last item
      itemCount: productProvider.products.length,
      itemBuilder: (context, index) {
        final p = productProvider.products[index];
        return InkWell(
          onTap: () => Navigator.of(context).pushNamed('/product', arguments: {
            'product': p, 'store': widget.store, 'vendor': widget.vendor,
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
              border: const Border(bottom: BorderSide(color: AppTheme.dividerColor, width: 0.5)),
            ),
            child: Row(
              children: [
                // Row number
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                // Product name
                Expanded(
                  child: Text(
                    p.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Delete button
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: AppTheme.errorColor.withOpacity(0.5)),
                  onPressed: () => _confirmDeleteProduct(context, productProvider, p),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  splashRadius: 18,
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
              autofocus: false,
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
                  const SnackBar(
                    content: Text('Vendor updated'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Pop and re-navigate to refresh the screen with updated vendor
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
                labelText: 'SKU / Barcode',
                prefixIcon: Icon(Icons.qr_code, size: 20),
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
                  storePrice: 0,
                  onlinePrice: 0,
                  storeCasePrice: 0,
                  onlineCasePrice: 0,
                  pcCost: 0,
                  caseCost: 0,
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

// End of file
