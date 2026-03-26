import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

class ManageStoresScreen extends StatefulWidget {
  const ManageStoresScreen({Key? key}) : super(key: key);

  @override
  State<ManageStoresScreen> createState() => _ManageStoresScreenState();
}

class _ManageStoresScreenState extends State<ManageStoresScreen> {
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
        title: const Text('Manage Stores'),
        elevation: 0,
      ),
      body: Consumer<StoreProvider>(
        builder: (context, storeProvider, _) {
          if (storeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: storeProvider.stores.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store_outlined, size: 64, color: AppTheme.textTertiary),
                        const SizedBox(height: 16),
                        Text('No stores yet', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddStoreDialog(context, storeProvider),
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Store'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: storeProvider.stores.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final store = storeProvider.stores[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(Icons.store, color: AppTheme.secondaryColor),
                          title: Text(store.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showEditStoreDialog(context, storeProvider, store),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                                onPressed: () => _confirmDelete(context, storeProvider, store),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStoreDialog(context, context.read<StoreProvider>()),
        backgroundColor: AppTheme.secondaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddStoreDialog(BuildContext context, StoreProvider storeProvider) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Store'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Store Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                storeProvider.addStore(nameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditStoreDialog(BuildContext context, StoreProvider storeProvider, Store store) {
    final nameController = TextEditingController(text: store.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Store'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Store Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                final updated = Store(
                  id: store.id,
                  name: nameController.text.trim(),
                  address: store.address,
                  phone: store.phone,
                  createdAt: store.createdAt,
                );
                storeProvider.updateStore(updated);
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, StoreProvider storeProvider, Store store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Store'),
        content: Text('Are you sure you want to delete "${store.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              storeProvider.deleteStore(store.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
