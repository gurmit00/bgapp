import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';
import 'package:newstore_ordering_app/utils/theme.dart';
import 'package:newstore_ordering_app/utils/csv_export.dart';
import 'package:newstore_ordering_app/services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NewStore'),
            Text(
              'home_screen.dart',
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4)),
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(context),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return const _StoresTab();
      case 1: return const _OrdersTab();
      case 2: return const _SettingsTab();
      default: return const _StoresTab();
    }
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drawer header
            DrawerHeader(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront_rounded, size: 32, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'NewStore Ordering',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage stores, vendors & orders',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable content area
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Navigation items
                  _DrawerItem(
                    icon: Icons.store_rounded,
                    label: 'Stores',
                    selected: _selectedIndex == 0,
                    onTap: () {
                      setState(() => _selectedIndex = 0);
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Orders',
                    selected: _selectedIndex == 1,
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                      context.read<OrderProvider>().loadAllOrders();
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    selected: _selectedIndex == 2,
                    onTap: () {
                      setState(() => _selectedIndex = 2);
                      Navigator.pop(context);
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(),
                  ),

                  // Tool items
                  _DrawerItem(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scan / Lookup PLU',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/scan-lookup');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.document_scanner_rounded,
                    label: 'Collect SKUs',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/sku-collect');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.upload_file_rounded,
                    label: 'Import Data',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/import');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.download_rounded,
                    label: 'Export Products',
                    onTap: () {
                      Navigator.pop(context);
                      _exportCsv(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Export Orders',
                    onTap: () {
                      Navigator.pop(context);
                      _exportOrders(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.store_mall_directory_rounded,
                    label: 'Manage Stores',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/manage-stores');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.sync_rounded,
                    label: 'Product Sync',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/product-sync');
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(),
                  ),

                  // Sign Out
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    color: AppTheme.errorColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.read<AuthProvider>().signOut();
                      Navigator.of(context).pushReplacementNamed('/');
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportCsv(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final count = await CsvExport.exportVendorProducts();
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported $count products to CSV'), backgroundColor: AppTheme.accentColor),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _exportOrders(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final count = await CsvExport.exportOrders();
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported $count order rows to CSV'), backgroundColor: AppTheme.accentColor),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}

// ─── Menu Row Helper ────────────────────────────────────────
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

// ─── Drawer Item Widget ─────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? (selected ? AppTheme.primaryColor : AppTheme.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: itemColor, size: 22),
        title: Text(
          label,
          style: TextStyle(
            color: itemColor,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        selected: selected,
        selectedTileColor: AppTheme.primaryColor.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        onTap: onTap,
      ),
    );
  }
}

// ─── Stores Tab ─────────────────────────────────────────────
class _StoresTab extends StatelessWidget {
  const _StoresTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<StoreProvider>(
      builder: (context, storeProvider, _) {
        if (storeProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Stores', style: Theme.of(context).textTheme.headlineMedium),
                  Text(
                    '${storeProvider.stores.length} stores',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: storeProvider.stores.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.separated(
                        itemCount: storeProvider.stores.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final store = storeProvider.stores[index];
                          return _StoreCard(
                            name: store.name,
                            onTap: () {
                              storeProvider.selectStore(store);
                              Navigator.of(context).pushNamed('/store', arguments: store);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.store_rounded, size: 40, color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 20),
          Text('No stores yet', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Add your first store to get started', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _StoreCard({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.store_rounded, color: AppTheme.secondaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text('Tap to manage vendors & orders', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Orders Tab ─────────────────────────────────────────────
class _OrdersTab extends StatefulWidget {
  const _OrdersTab({Key? key}) : super(key: key);

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  final FirebaseService _firebaseService = FirebaseService();
  // Cache: storeId -> { vendorId -> Vendor }
  final Map<String, Map<String, Vendor>> _vendorCache = {};

  Future<Vendor?> _getVendor(String storeId, String vendorId) async {
    if (_vendorCache.containsKey(storeId) && _vendorCache[storeId]!.containsKey(vendorId)) {
      return _vendorCache[storeId]![vendorId];
    }
    // Load all vendors for this store and cache them
    if (!_vendorCache.containsKey(storeId)) {
      final vendors = await _firebaseService.getVendors(storeId);
      _vendorCache[storeId] = {for (var v in vendors) v.id: v};
    }
    return _vendorCache[storeId]?[vendorId];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrderProvider, StoreProvider>(
      builder: (context, orderProvider, storeProvider, _) {
        if (orderProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (orderProvider.orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.receipt_long_rounded, size: 40, color: AppTheme.accentColor),
                ),
                const SizedBox(height: 20),
                Text('No orders yet', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Orders will appear here after creation', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          itemCount: orderProvider.orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final order = orderProvider.orders[index];
            final storeName = storeProvider.stores
                .where((s) => s.id == order.storeId)
                .map((s) => s.name)
                .firstOrNull ?? 'Unknown Store';
            final dateStr = DateFormat('MMM dd, yyyy · h:mm a').format(order.createdAt);

            return FutureBuilder<Vendor?>(
              future: _getVendor(order.storeId, order.vendorId),
              builder: (context, snapshot) {
                final vendor = snapshot.data;
                final vendorName = vendor?.name ?? 'Loading…';

                return _OrderCard(
                  storeName: storeName,
                  vendorName: vendorName,
                  dateStr: dateStr,
                  status: order.status,
                  itemCount: order.items.length,
                  onTap: () {
                    final store = storeProvider.stores
                        .where((s) => s.id == order.storeId).firstOrNull;
                    if (vendor != null && store != null) {
                      orderProvider.setCurrentOrderForEditing(order);
                      Navigator.of(context).pushNamed(
                        '/order-creation',
                        arguments: {'store': store, 'vendor': vendor, 'editingOrder': order},
                      );
                    }
                  },
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Order'),
                        content: const Text('Are you sure you want to delete this order?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      orderProvider.deleteOrder(order.id);
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String storeName, vendorName, dateStr, status;
  final int itemCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _OrderCard({
    required this.storeName,
    required this.vendorName,
    required this.dateStr,
    required this.status,
    required this.itemCount,
    required this.onTap,
    required this.onDelete,
  });

  Color _statusColor() {
    switch (status) {
      case 'submitted': return AppTheme.accentColor;
      case 'completed': return AppTheme.secondaryColor;
      default: return AppTheme.warningColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeName, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(vendorName, style: TextStyle(color: AppTheme.secondaryColor, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: _statusColor(), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert, size: 20, color: AppTheme.textTertiary),
                    onSelected: (v) {
                      if (v == 'edit') onTap();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: _MenuRow(icon: Icons.edit, label: 'Edit Order')),
                      const PopupMenuItem(value: 'delete', child: _MenuRow(icon: Icons.delete_outline, label: 'Delete Order')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.textTertiary),
                  const SizedBox(width: 6),
                  Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  Icon(Icons.inventory_2_outlined, size: 13, color: AppTheme.textTertiary),
                  const SizedBox(width: 6),
                  Text('$itemCount items', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Settings Tab ───────────────────────────────────────────
class _SettingsTab extends StatefulWidget {
  const _SettingsTab({Key? key}) : super(key: key);

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _storeDomainController = TextEditingController();
  final _accessTokenController = TextEditingController();
  final _posDataPathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final svc = SyncService();
    _storeDomainController.text = svc.storeDomain;
    _accessTokenController.text = svc.accessToken;
    _posDataPathController.text = svc.posDataPath;
  }

  @override
  void dispose() {
    _storeDomainController.dispose();
    _accessTokenController.dispose();
    _posDataPathController.dispose();
    super.dispose();
  }

  void _handleExport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final count = await CsvExport.exportVendorProducts();
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported $count products to CSV'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _handleExportOrders(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final count = await CsvExport.exportOrders();
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported $count order rows to CSV'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveShopifyConfig() async {
    try {
      await SyncService().saveConfig(
        storeDomain: _storeDomainController.text.trim(),
        accessToken: _accessTokenController.text.trim(),
        posDataPath: _posDataPathController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shopify settings saved'), backgroundColor: Colors.green),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.store_rounded,
                  label: 'Manage Stores',
                  onTap: () => Navigator.of(context).pushNamed('/manage-stores'),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan / Lookup PLU',
                  onTap: () => Navigator.of(context).pushNamed('/scan-lookup'),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.upload_file_rounded,
                  label: 'Import Data',
                  onTap: () => Navigator.of(context).pushNamed('/import'),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.download_rounded,
                  label: 'Export Products (CSV)',
                  onTap: () => _handleExport(context),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'Export Orders (CSV)',
                  onTap: () => _handleExportOrders(context),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  label: 'About',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Shopify Configuration Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shopping_bag, color: const Color(0xFF96BF48), size: 22),
                      const SizedBox(width: 8),
                      const Text('Shopify Integration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (SyncService().isConfigured)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Connected', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF047857))),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Not configured', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _storeDomainController,
                    decoration: const InputDecoration(
                      labelText: 'Store Domain',
                      hintText: 'apniroots.com',
                      prefixIcon: Icon(Icons.language, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(),
                      helperText: 'Public storefront domain (no API key needed)',
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveShopifyConfig,
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save Shopify Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF96BF48),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // POS Configuration Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.point_of_sale, color: Color(0xFF047857), size: 22),
                      const SizedBox(width: 8),
                      const Text('Penny Lane POS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _posDataPathController,
                    decoration: const InputDecoration(
                      labelText: 'POS Data Directory (Windows)',
                      hintText: r'C:\PENNYLANE\DATA',
                      prefixIcon: Icon(Icons.folder, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(),
                      helperText: 'Path on Windows POS machine for NewCodes.txt',
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Upload NewCodes.txt via Product Sync or Product Detail screens. '
                    'The Windows batch script auto-downloads it into this path.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveShopifyConfig,
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save POS Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: _SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              color: AppTheme.errorColor,
              onTap: () {
                context.read<AuthProvider>().signOut();
                Navigator.of(context).pushReplacementNamed('/');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary, size: 20),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ─── Status Chip (kept for backward compat) ─────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'submitted': color = AppTheme.accentColor; break;
      case 'completed': color = AppTheme.secondaryColor; break;
      default: color = AppTheme.warningColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }
}
