import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';
import 'package:newstore_ordering_app/utils/theme.dart';
import 'package:newstore_ordering_app/utils/csv_export.dart';
import 'package:newstore_ordering_app/utils/app_roles.dart';
import 'package:newstore_ordering_app/services/sync_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 2; // Open on Orders tab
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().loadStores();
      context.read<OrderProvider>().loadAllOrders();
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
      case 1: return const _ProductsTab();
      case 2: return const _OrdersTab();
      case 3: return const _SettingsTab();
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
                    icon: Icons.inventory_2_rounded,
                    label: 'Products',
                    selected: _selectedIndex == 1,
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Orders',
                    selected: _selectedIndex == 2,
                    onTap: () {
                      setState(() => _selectedIndex = 2);
                      context.read<OrderProvider>().loadAllOrders();
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    selected: _selectedIndex == 3,
                    onTap: () {
                      setState(() => _selectedIndex = 3);
                      Navigator.pop(context);
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(),
                  ),

                  // Tool items — gated by role
                  if (context.read<AuthProvider>().hasPermission(AppRoles.importData))
                    _DrawerItem(
                      icon: Icons.upload_file_rounded,
                      label: 'Import Data',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushNamed('/import');
                      },
                    ),
                  if (context.read<AuthProvider>().hasPermission(AppRoles.exportData))
                    _DrawerItem(
                      icon: Icons.download_rounded,
                      label: 'Export Products',
                      onTap: () {
                        Navigator.pop(context);
                        _exportCsv(context);
                      },
                    ),
                  if (context.read<AuthProvider>().hasPermission(AppRoles.exportData))
                    _DrawerItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Export Orders',
                      onTap: () {
                        Navigator.pop(context);
                        _exportOrders(context);
                      },
                    ),
                  // ── Online Platforms submenu ─────────────────
                  Builder(builder: (ctx) {
                    final auth = ctx.read<AuthProvider>();
                    final hasUberExport      = auth.hasPermission(AppRoles.exportUberEats);
                    final hasUberMarkup      = auth.hasPermission(AppRoles.uberMarkup);
                    final hasUberSections    = auth.hasPermission(AppRoles.uberSections);
                    final hasInstacartExport = auth.hasPermission(AppRoles.exportInstacart);
                    final hasInstacartMarkup = auth.hasPermission(AppRoles.instacartMarkup);
                    if (!hasUberExport && !hasUberMarkup && !hasUberSections && !hasInstacartExport && !hasInstacartMarkup) {
                      return const SizedBox.shrink();
                    }
                    return Theme(
                      data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: const Icon(Icons.language_rounded, size: 22, color: AppTheme.textSecondary),
                        title: const Text('Online Platforms', style: TextStyle(fontSize: 14)),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                        childrenPadding: const EdgeInsets.only(left: 16),
                        children: [
                          if (hasUberExport)
                            _DrawerItem(
                              icon: Icons.delivery_dining_rounded,
                              label: 'Export UberEats',
                              onTap: () { Navigator.pop(ctx); _exportUberEats(ctx); },
                            ),
                          if (hasUberMarkup)
                            _DrawerItem(
                              icon: Icons.tune_rounded,
                              label: 'Uber Markup',
                              onTap: () { Navigator.pop(ctx); Navigator.of(ctx).pushNamed('/uber-markup'); },
                            ),
                          if (hasUberSections)
                            _DrawerItem(
                              icon: Icons.category_outlined,
                              label: 'Uber Sections',
                              onTap: () { Navigator.pop(ctx); Navigator.of(ctx).pushNamed('/uber-sections'); },
                            ),
                          if (hasInstacartExport)
                            _DrawerItem(
                              icon: Icons.shopping_basket_rounded,
                              label: 'Export Instacart',
                              onTap: () { Navigator.pop(ctx); _exportInstacart(ctx); },
                            ),
                          if (hasInstacartMarkup)
                            _DrawerItem(
                              icon: Icons.tune_rounded,
                              label: 'Instacart Markup',
                              onTap: () { Navigator.pop(ctx); Navigator.of(ctx).pushNamed('/instacart-markup'); },
                            ),
                        ],
                      ),
                    );
                  }),
                  if (context.read<AuthProvider>().hasPermission(AppRoles.manageStores))
                    _DrawerItem(
                      icon: Icons.store_mall_directory_rounded,
                      label: 'Manage Stores',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushNamed('/manage-stores');
                      },
                    ),
                  if (context.read<AuthProvider>().hasPermission(AppRoles.shopifyMissing))
                    _DrawerItem(
                      icon: Icons.storefront_outlined,
                      label: 'Missing from Shopify',
                      onTap: () {
                        Navigator.pop(context);
                        final stores = context.read<StoreProvider>().stores;
                        final store = stores.firstWhere(
                          (s) => s.name.toLowerCase().contains('mississauga'),
                          orElse: () => stores.isNotEmpty ? stores.first : Store(id: '', name: '', address: '', phone: ''),
                        );
                        if (store.id.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('BG Mississauga store not found')),
                          );
                          return;
                        }
                        Navigator.of(context).pushNamed('/shopify-missing', arguments: {'store': store});
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
    // ── Step 1: pick store ───────────────────────────────────
    final stores = context.read<StoreProvider>().stores;
    if (stores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stores found')),
      );
      return;
    }

    Store? selectedStore;
    if (stores.length == 1) {
      selectedStore = stores.first; // skip dialog if only one store
    } else {
      selectedStore = await showDialog<Store>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Export from which store?'),
          children: stores.map((s) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, s),
            child: Text(s.name),
          )).toList(),
        ),
      );
    }
    if (selectedStore == null) return; // cancelled

    // ── Step 2: pick vendor or all ───────────────────────────
    if (!context.mounted) return;
    final firebaseService = FirebaseService();
    final vendors = await firebaseService.getVendors(selectedStore.id);

    if (!context.mounted) return;
    String? selectedVendorId; // null = all vendors
    if (vendors.isNotEmpty) {
      final options = [
        const SimpleDialogOption(child: Text('All Vendors', style: TextStyle(fontWeight: FontWeight.w600))),
        ...vendors.map((v) => SimpleDialogOption(child: Text(v.name))),
      ];
      final picked = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('Which vendor from ${selectedStore!.name}?'),
          children: List.generate(options.length, (i) => GestureDetector(
            onTap: () => Navigator.pop(ctx, i),
            child: options[i],
          )),
        ),
      );
      if (picked == null) return; // cancelled
      if (picked > 0) selectedVendorId = vendors[picked - 1].id; // 0 = all
    }

    // ── Step 3: export ───────────────────────────────────────
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final count = await CsvExport.exportVendorProducts(
        store: selectedStore!,
        vendorId: selectedVendorId,
      );
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

  void _exportUberEats(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final count = await CsvExport.exportUberEats();
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported $count products to UberEats CSV'), backgroundColor: AppTheme.accentColor),
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

  void _exportInstacart(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final count = await CsvExport.exportInstacart();
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported $count products to Instacart CSV'), backgroundColor: AppTheme.accentColor),
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
    // ── Step 1: pick store ───────────────────────────────────
    final stores = context.read<StoreProvider>().stores;
    if (stores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stores found')),
      );
      return;
    }

    Store? selectedStore;
    if (stores.length == 1) {
      selectedStore = stores.first;
    } else {
      selectedStore = await showDialog<Store>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Export orders from which store?'),
          children: stores.map((s) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, s),
            child: Text(s.name),
          )).toList(),
        ),
      );
    }
    if (selectedStore == null) return; // cancelled

    // ── Step 2: pick vendor or all ───────────────────────────
    if (!context.mounted) return;
    final firebaseService = FirebaseService();
    final vendors = await firebaseService.getVendors(selectedStore.id);

    if (!context.mounted) return;
    String? selectedVendorId; // null = all vendors
    if (vendors.isNotEmpty) {
      final options = [
        const SimpleDialogOption(child: Text('All Vendors', style: TextStyle(fontWeight: FontWeight.w600))),
        ...vendors.map((v) => SimpleDialogOption(child: Text(v.name))),
      ];
      final picked = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('Which vendor from ${selectedStore!.name}?'),
          children: List.generate(options.length, (i) => GestureDetector(
            onTap: () => Navigator.pop(ctx, i),
            child: options[i],
          )),
        ),
      );
      if (picked == null) return; // cancelled
      if (picked > 0) selectedVendorId = vendors[picked - 1].id; // 0 = all
    }

    // ── Step 3: export ───────────────────────────────────────
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final count = await CsvExport.exportOrders(
        storeId: selectedStore!.id,
        vendorId: selectedVendorId,
      );
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

// ─── Products Tab (cross-store, grouped by SKU) ─────────────
class _ProductsTab extends StatefulWidget {
  const _ProductsTab({Key? key}) : super(key: key);

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  final TextEditingController _skuController = TextEditingController();

  @override
  void dispose() {
    _skuController.dispose();
    super.dispose();
  }

  void _goToLookup(String sku) {
    if (sku.trim().isEmpty) return;
    final stores = context.read<StoreProvider>().stores;
    Navigator.of(context).pushNamed(
      '/product-lookup',
      arguments: {'sku': sku.trim(), 'allStores': stores},
    );
  }

  void _scanBarcode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );
    if (scanned != null && scanned.isNotEmpty) {
      _skuController.text = scanned;
      _goToLookup(scanned);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Text('Product Lookup', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          // SKU input + search button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _skuController,
                  decoration: InputDecoration(
                    hintText: 'Type SKU / barcode...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _skuController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _skuController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _goToLookup,
                ),
              ),
              const SizedBox(width: 8),
              // Search button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _skuController.text.trim().isNotEmpty
                      ? () => _goToLookup(_skuController.text)
                      : null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Icon(Icons.search),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Scan button — large and prominent
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: _scanBarcode,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.accentColor.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(Icons.qr_code_scanner, size: 64, color: AppTheme.accentColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Scan Barcode', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Scan or type a SKU to look up across\nall stores + Shopify',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Barcode Scanner (reusable from home) ────────────────────
class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

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
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _controller.toggleTorch(), tooltip: 'Flash'),
          IconButton(icon: const Icon(Icons.cameraswitch), onPressed: () => _controller.switchCamera(), tooltip: 'Switch Camera'),
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
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  _hasScanned ? 'Scanned!' : 'Point at a barcode',
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
    if (!_vendorCache.containsKey(storeId)) {
      final vendors = await _firebaseService.getVendors(storeId);
      _vendorCache[storeId] = {for (var v in vendors) v.id: v};
    }
    return _vendorCache[storeId]?[vendorId];
  }

  // Returns the Monday of the week containing [date]
  DateTime _weekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  String _weekLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    if (weekStart.year == weekEnd.year && weekStart.month == weekEnd.month) {
      return '${DateFormat('MMM d').format(weekStart)}–${DateFormat('d, yyyy').format(weekEnd)}';
    }
    if (weekStart.year == weekEnd.year) {
      return '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d, yyyy').format(weekEnd)}';
    }
    return '${DateFormat('MMM d, yyyy').format(weekStart)} – ${DateFormat('MMM d, yyyy').format(weekEnd)}';
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
                Text('Orders will appear here after creation',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        }

        // Group orders by week (most recent week first)
        final groupedByWeek = <DateTime, List<Order>>{};
        for (final order in orderProvider.orders) {
          final ws = _weekStart(order.createdAt);
          groupedByWeek.putIfAbsent(ws, () => []).add(order);
        }
        final sortedWeeks = groupedByWeek.keys.toList()
          ..sort((a, b) => b.compareTo(a));
        for (final week in sortedWeeks) {
          groupedByWeek[week]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          children: [
            for (final weekStart in sortedWeeks) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
                child: Text(
                  _weekLabel(weekStart),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textTertiary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (final order in groupedByWeek[weekStart]!)
                FutureBuilder<Vendor?>(
                  future: _getVendor(order.storeId, order.vendorId),
                  builder: (context, snapshot) {
                    final vendor = snapshot.data;
                    final vendorName = vendor?.name ?? 'Loading…';
                    final storeName = storeProvider.stores
                            .where((s) => s.id == order.storeId)
                            .map((s) => s.name)
                            .firstOrNull ??
                        'Unknown Store';
                    final dateStr =
                        DateFormat('MMM dd, yyyy · h:mm a').format(order.createdAt);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _OrderCard(
                        storeName: storeName,
                        vendorName: vendorName,
                        dateStr: dateStr,
                        status: order.status,
                        itemCount: order.items.length,
                        canDelete: context
                            .read<AuthProvider>()
                            .hasPermission(AppRoles.deleteOrder),
                        onTap: () {
                          final store = storeProvider.stores
                              .where((s) => s.id == order.storeId)
                              .firstOrNull;
                          if (vendor != null && store != null) {
                            orderProvider.setCurrentOrderForEditing(order);
                            Navigator.of(context).pushNamed(
                              '/order-creation',
                              arguments: {
                                'store': store,
                                'vendor': vendor,
                                'editingOrder': order
                              },
                            );
                          }
                        },
                        onDelete: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Order'),
                              content: const Text(
                                  'Are you sure you want to delete this order?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.errorColor),
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
                      ),
                    );
                  },
                ),
            ],
          ],
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String storeName, vendorName, dateStr, status;
  final int itemCount;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _OrderCard({
    required this.storeName,
    required this.vendorName,
    required this.dateStr,
    required this.status,
    required this.itemCount,
    required this.canDelete,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: _statusColor(), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$vendorName · $storeName',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.calendar_today_rounded, size: 11, color: AppTheme.textTertiary),
              const SizedBox(width: 3),
              Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              Icon(Icons.inventory_2_outlined, size: 11, color: AppTheme.textTertiary),
              const SizedBox(width: 3),
              Text('$itemCount', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, size: 18, color: AppTheme.textTertiary),
                onSelected: (v) {
                  if (v == 'edit') onTap();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: _MenuRow(icon: Icons.edit, label: 'Edit Order')),
                  if (canDelete)
                    const PopupMenuItem(value: 'delete', child: _MenuRow(icon: Icons.delete_outline, label: 'Delete Order')),
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

  void _handleExport(BuildContext context) async {
    // Delegate to the main export flow (store + vendor picker)
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
    if (homeState != null) {
      homeState._exportCsv(context);
      return;
    }

    // Fallback (should not happen)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final stores = await FirebaseService().getStores();
    if (stores.isEmpty) {
      if (context.mounted) Navigator.of(context).pop();
      return;
    }

    try {
      final count = await CsvExport.exportVendorProducts(store: stores.first);
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
    // Delegate to the main export flow (store + vendor picker)
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
    if (homeState != null) {
      homeState._exportOrders(context);
      return;
    }

    // Fallback (should not happen)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export failed: unable to find home state')),
    );
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
              ],
            ),
          ),
          // User Management — admin only
          if (context.read<AuthProvider>().hasPermission(AppRoles.manageUsers)) ...[
            const SizedBox(height: 16),
            _UserManagementCard(),
          ],

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

// ─── User Management Card (admin only) ──────────────────────
class _UserManagementCard extends StatefulWidget {
  @override
  State<_UserManagementCard> createState() => _UserManagementCardState();
}

class _UserManagementCardState extends State<_UserManagementCard> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    _users = await _firebaseService.getAllUsers();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_outline, color: AppTheme.accentColor, size: 22),
                const SizedBox(width: 8),
                const Text('User Management', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _loadUsers,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ))
            else if (_users.isEmpty)
              Text('No users found', style: Theme.of(context).textTheme.bodySmall)
            else
              for (final user in _users) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['email'] ?? '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((user['displayName'] ?? '').isNotEmpty &&
                                user['displayName'] != user['email'])
                              Text(user['displayName'] ?? '',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: AppRoles.assignable.contains(user['role']) ? user['role'] : null,
                        hint: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Pending', style: TextStyle(fontSize: 12, color: AppTheme.warningColor, fontWeight: FontWeight.w600)),
                        ),
                        isDense: true,
                        underline: const SizedBox(),
                        items: AppRoles.assignable.map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(AppRoles.label(r), style: const TextStyle(fontSize: 13)),
                        )).toList(),
                        onChanged: (newRole) async {
                          if (newRole == null) return;
                          final uid = user['uid'] as String? ?? '';
                          if (uid.isEmpty) return;
                          await _firebaseService.setUserRole(uid, newRole);
                          setState(() => user['role'] = newRole);
                        },
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
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
