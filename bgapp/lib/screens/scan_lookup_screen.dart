import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/plu_provider.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

class ScanLookupScreen extends StatefulWidget {
  const ScanLookupScreen({Key? key}) : super(key: key);

  @override
  State<ScanLookupScreen> createState() => _ScanLookupScreenState();
}

class _ScanLookupScreenState extends State<ScanLookupScreen> {
  final _manualController = TextEditingController();
  bool _showScanner = false;

  @override
  void initState() {
    super.initState();
    // Ensure PLU data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PLUProvider>().loadPLU();
    });
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(String code) {
    setState(() => _showScanner = false);
    _lookupAndNavigate(code);
  }

  void _lookupAndNavigate(String code) {
    final pluProvider = context.read<PLUProvider>();
    final product = pluProvider.lookup(code);

    if (product != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PLUDetailScreen(product: product.copy()),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PLU "$code" not found in product list'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scan / Lookup PLU'),
            Text(
              'scan_lookup_screen.dart',
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4)),
            ),
          ],
        ),
        actions: [
          // Badge showing saved count
          Consumer<PLUProvider>(
            builder: (context, plu, _) {
              final count = plu.savedProducts.length;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.save_alt_rounded),
                    tooltip: 'View saved products',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const _SavedProductsScreen()),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<PLUProvider>(
        builder: (context, pluProvider, _) {
          if (pluProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading product database…'),
                ],
              ),
            );
          }

          if (pluProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                  const SizedBox(height: 12),
                  Text(pluProvider.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => pluProvider.loadPLU(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Scanner area
              if (_showScanner)
                SizedBox(
                  height: 300,
                  child: _BarcodeScannerWidget(
                    onDetected: _onBarcodeDetected,
                    onClose: () => setState(() => _showScanner = false),
                  ),
                ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info card
                      Card(
                        color: AppTheme.secondaryColor.withOpacity(0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.secondaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${pluProvider.pluMap.length} products loaded from PLU.csv',
                                  style: TextStyle(
                                    color: AppTheme.secondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Scan button
                      if (!_showScanner)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                            label: const Text('Scan Barcode'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => setState(() => _showScanner = true),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Manual entry
                      Text(
                        'Or enter PLU number manually',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualController,
                              keyboardType: TextInputType.text,
                              decoration: const InputDecoration(
                                hintText: 'Enter PLU number…',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onSubmitted: (_) => _onManualLookup(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _onManualLookup,
                            child: const Text('Lookup'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Recently saved
                      if (pluProvider.savedProducts.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Saved Products (${pluProvider.savedProducts.length})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.save_alt_rounded, size: 18),
                              label: const Text('View All'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const _SavedProductsScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...pluProvider.savedProducts.reversed.take(5).map(
                          (p) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.accentColor.withOpacity(0.1),
                                child: Text(
                                  p.pluNum.length > 3 ? p.pluNum.substring(0, 3) : p.pluNum,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentColor,
                                  ),
                                ),
                              ),
                              title: Text(p.desc, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('${p.deptName} · \$${p.price}'),
                              trailing: Icon(Icons.check_circle, color: AppTheme.accentColor, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onManualLookup() {
    final code = _manualController.text.trim();
    if (code.isEmpty) return;
    _manualController.clear();
    _lookupAndNavigate(code);
  }
}

// ─── Barcode Scanner Widget ─────────────────────────────────
class _BarcodeScannerWidget extends StatefulWidget {
  final void Function(String code) onDetected;
  final VoidCallback onClose;

  const _BarcodeScannerWidget({required this.onDetected, required this.onClose});

  @override
  State<_BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<_BarcodeScannerWidget> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            if (_hasScanned) return;
            final barcode = capture.barcodes.firstOrNull;
            if (barcode != null && barcode.rawValue != null) {
              _hasScanned = true;
              _controller.stop();
              widget.onDetected(barcode.rawValue!);
            }
          },
        ),
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                _controller.stop();
                widget.onClose();
              },
            ),
          ),
        ),
        const Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'Point camera at barcode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── PLU Detail / Edit Screen ───────────────────────────────
class _PLUDetailScreen extends StatefulWidget {
  final PLUProduct product;
  const _PLUDetailScreen({required this.product});

  @override
  State<_PLUDetailScreen> createState() => _PLUDetailScreenState();
}

class _PLUDetailScreenState extends State<_PLUDetailScreen> {
  late TextEditingController _descCtl;
  late TextEditingController _deptNameCtl;
  late TextEditingController _priceCtl;
  late TextEditingController _costCtl;
  late TextEditingController _taxCodeCtl;
  late TextEditingController _vendNameCtl;

  @override
  void initState() {
    super.initState();
    _descCtl = TextEditingController(text: widget.product.desc);
    _deptNameCtl = TextEditingController(text: widget.product.deptName);
    _priceCtl = TextEditingController(text: widget.product.price);
    _costCtl = TextEditingController(text: widget.product.cost);
    _taxCodeCtl = TextEditingController(text: widget.product.taxCode);
    _vendNameCtl = TextEditingController(text: widget.product.vendName);
  }

  @override
  void dispose() {
    _descCtl.dispose();
    _deptNameCtl.dispose();
    _priceCtl.dispose();
    _costCtl.dispose();
    _taxCodeCtl.dispose();
    _vendNameCtl.dispose();
    super.dispose();
  }

  void _save() {
    final product = widget.product;
    product.desc = _descCtl.text;
    product.deptName = _deptNameCtl.text;
    product.price = _priceCtl.text;
    product.cost = _costCtl.text;
    product.taxCode = _taxCodeCtl.text;
    product.vendName = _vendNameCtl.text;

    context.read<PLUProvider>().addToSaved(product);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PLU ${product.pluNum} saved'),
        backgroundColor: AppTheme.accentColor,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PLU ${widget.product.pluNum}'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PLU Number header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code_2_rounded, size: 40, color: AppTheme.secondaryColor),
                  const SizedBox(height: 8),
                  Text(
                    'PLU: ${widget.product.pluNum}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Product Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            _buildField('Description', _descCtl, Icons.description_outlined),
            _buildField('Department', _deptNameCtl, Icons.category_outlined),
            _buildField('Price', _priceCtl, Icons.attach_money, keyboardType: TextInputType.number),
            _buildField('Cost', _costCtl, Icons.money_off_outlined, keyboardType: TextInputType.number),
            _buildField('Tax Code', _taxCodeCtl, Icons.receipt_outlined),
            _buildField('Vendor', _vendNameCtl, Icons.business_outlined),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save to PLU_new'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
        ),
      ),
    );
  }
}

// ─── Saved Products List + Export Screen ─────────────────────
class _SavedProductsScreen extends StatelessWidget {
  const _SavedProductsScreen({Key? key}) : super(key: key);

  void _handleExport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final count = await context.read<PLUProvider>().exportPLUNew();
      if (context.mounted) Navigator.of(context).pop(); // dismiss spinner
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported $count products to PLU_new.csv'),
            backgroundColor: AppTheme.accentColor,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Products'),
        actions: [
          Consumer<PLUProvider>(
            builder: (context, plu, _) {
              if (plu.savedProducts.isEmpty) return const SizedBox.shrink();
              return TextButton.icon(
                icon: const Icon(Icons.delete_sweep, color: Colors.white70),
                label: const Text('Clear', style: TextStyle(color: Colors.white70)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear All'),
                      content: const Text('Remove all saved products?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    context.read<PLUProvider>().clearSaved();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<PLUProvider>(
        builder: (context, pluProvider, _) {
          if (pluProvider.savedProducts.isEmpty) {
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
                    child: Icon(Icons.inventory_2_outlined, size: 40, color: AppTheme.secondaryColor),
                  ),
                  const SizedBox(height: 20),
                  Text('No products saved yet', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('Scan or lookup a PLU to get started', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  itemCount: pluProvider.savedProducts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = pluProvider.savedProducts[index];
                    return Dismissible(
                      key: ValueKey(p.pluNum),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.delete_outline, color: AppTheme.errorColor),
                      ),
                      onDismissed: (_) => pluProvider.removeFromSaved(p.pluNum),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'PLU ${p.pluNum}',
                                      style: TextStyle(
                                        color: AppTheme.secondaryColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '\$${p.price}',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(p.desc, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _InfoChip(Icons.category_outlined, p.deptName),
                                  const SizedBox(width: 8),
                                  _InfoChip(Icons.business_outlined, p.vendName),
                                  const SizedBox(width: 8),
                                  _InfoChip(Icons.receipt_outlined, 'Tax: ${p.taxCode}'),
                                ],
                              ),
                              if (p.cost.isNotEmpty && p.cost != '0') ...[
                                const SizedBox(height: 4),
                                Text('Cost: \$${p.cost}', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Export bar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border(top: BorderSide(color: AppTheme.borderColor)),
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download_rounded),
                      label: Text('Export ${pluProvider.savedProducts.length} products to PLU_new.csv'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _handleExport(context),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textTertiary),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}
