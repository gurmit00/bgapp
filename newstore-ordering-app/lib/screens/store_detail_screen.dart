import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

class StoreDetailScreen extends StatefulWidget {
  final Store store;

  const StoreDetailScreen({Key? key, required this.store}) : super(key: key);

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadVendors(widget.store.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.store.name),
            const Text('store_detail_screen.dart', style: TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
        elevation: 0,
      ),
      body: Consumer<VendorProvider>(
        builder: (context, vendorProvider, _) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
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
                const SizedBox(height: 16),
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
                                child: Icon(Icons.people_outline, size: 36, color: AppTheme.secondaryColor),
                              ),
                              const SizedBox(height: 16),
                              Text('No vendors yet', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              Text('Add your first vendor to get started', style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => _showAddVendorDialog(context, vendorProvider),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Vendor'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: vendorProvider.vendors.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final vendor = vendorProvider.vendors[index];
                            return Card(
                              child: InkWell(
                                onTap: () {
                                  vendorProvider.selectVendor(vendor);
                                  Navigator.of(context).pushNamed(
                                    '/vendor',
                                    arguments: {
                                      'vendor': vendor,
                                      'store': widget.store,
                                    },
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
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
                                            Text(vendor.name, style: Theme.of(context).textTheme.titleMedium),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(Icons.phone, size: 13, color: AppTheme.textTertiary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  vendor.whatsappPhoneNumber.isEmpty
                                                      ? 'No phone'
                                                      : vendor.whatsappPhoneNumber,
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.textTertiary),
                                        onPressed: () => _confirmDeleteVendor(context, vendorProvider, vendor),
                                        tooltip: 'Delete',
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary, size: 22),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
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
