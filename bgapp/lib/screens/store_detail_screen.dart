import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/providers/plu_provider.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';
import 'package:newstore_ordering_app/utils/theme.dart';
import 'package:newstore_ordering_app/utils/app_roles.dart';

class StoreDetailScreen extends StatefulWidget {
  final Store store;

  const StoreDetailScreen({Key? key, required this.store}) : super(key: key);

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  bool _isUploadingPlu = false;
  late Store _currentStore;

  @override
  void initState() {
    super.initState();
    _currentStore = widget.store;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadVendors(widget.store.id);
    });
  }

  Future<void> _pickAndUploadPLU() async {
    final completer = Completer<Uint8List?>();
    final input = html.FileUploadInputElement()..accept = '.csv';
    input.click();

    input.onChange.listen((event) {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        return;
      }
      final reader = html.FileReader();
      reader.readAsArrayBuffer(files[0]);
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is Uint8List) {
          completer.complete(result);
        } else if (result is List<int>) {
          completer.complete(Uint8List.fromList(result));
        } else {
          completer.complete(null);
        }
      });
      reader.onError.listen((_) => completer.complete(null));
    });

    final bytes = await completer.future;
    if (bytes == null) return;

    setState(() => _isUploadingPlu = true);
    try {
      final firebaseService = FirebaseService();
      final url = await firebaseService.uploadStorePLU(
        _currentStore.id, bytes, 'PLU.csv',
      );
      await firebaseService.updateStorePluUrl(_currentStore.id, url);
      // Reload PLU data for this store
      if (mounted) {
        context.read<PLUProvider>().reloadPLUForStore(_currentStore.id, url);
      }
      // Update local store state
      setState(() {
        _currentStore = Store(
          id: _currentStore.id,
          name: _currentStore.name,
          address: _currentStore.address,
          phone: _currentStore.phone,
          pluCsvUrl: url,
          pluUploadedAt: DateTime.now(),
          createdAt: _currentStore.createdAt,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PLU file uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPlu = false);
    }
  }

  Widget _buildPluUploadCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _currentStore.hasPlu
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _currentStore.hasPlu ? Icons.check_circle : Icons.upload_file,
                color: _currentStore.hasPlu ? Colors.green : Colors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PLU File', style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    _currentStore.hasPlu && _currentStore.pluUploadedAt != null
                        ? 'Uploaded ${DateFormat.yMMMd().format(_currentStore.pluUploadedAt!)}'
                        : 'No PLU file uploaded',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _isUploadingPlu
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton(
                    onPressed: _pickAndUploadPLU,
                    child: Text(_currentStore.hasPlu ? 'Replace' : 'Upload'),
                  ),
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
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                _buildPluUploadCard(),
                const SizedBox(height: 16),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.business_rounded, color: AppTheme.accentColor, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          vendor.name,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (vendor.whatsappPhoneNumber.isNotEmpty) ...[
                                        Icon(Icons.phone, size: 11, color: AppTheme.textTertiary),
                                        const SizedBox(width: 3),
                                        Text(vendor.whatsappPhoneNumber, style: Theme.of(context).textTheme.bodySmall),
                                        const SizedBox(width: 4),
                                      ],
                                      if (context.read<AuthProvider>().hasPermission(AppRoles.deleteVendor))
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          icon: Icon(Icons.delete_outline, size: 16, color: AppTheme.textTertiary),
                                          onPressed: () => _confirmDeleteVendor(context, vendorProvider, vendor),
                                        ),
                                      Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary, size: 18),
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
