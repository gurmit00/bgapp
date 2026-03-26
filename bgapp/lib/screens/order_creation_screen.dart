import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/utils/theme.dart';
import 'package:intl/intl.dart';

class OrderCreationScreen extends StatefulWidget {
  final Store store;
  final Vendor vendor;
  final Order? editingOrder;

  const OrderCreationScreen({
    Key? key,
    required this.store,
    required this.vendor,
    this.editingOrder,
  }) : super(key: key);

  @override
  State<OrderCreationScreen> createState() => _OrderCreationScreenState();
}

class _OrderCreationScreenState extends State<OrderCreationScreen> {
  final Map<String, TextEditingController> _onHandControllers = {};
  final Map<String, TextEditingController> _orderQtyControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProductsByVendor(widget.store.id, widget.vendor.id);
      if (widget.editingOrder != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _populateFieldsFromOrder();
        });
      }
    });
  }

  void _populateFieldsFromOrder() {
    if (widget.editingOrder == null) return;
    final products = context.read<ProductProvider>().products;
    for (var item in widget.editingOrder!.items) {
      final product = products.where((p) => p.id == item.productId).firstOrNull;
      if (product != null) {
        _getOnHandController(product).text = item.onHandQtyPcs > 0 ? item.onHandQtyPcs.toString() : '';
        _getOrderQtyController(product).text = item.orderQtyCases > 0 ? item.orderQtyCases.toString() : '';
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _onHandControllers.values.forEach((c) => c.dispose());
    _orderQtyControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  TextEditingController _getOnHandController(Product p) =>
      _onHandControllers.putIfAbsent(p.id, () => TextEditingController());

  TextEditingController _getOrderQtyController(Product p) =>
      _orderQtyControllers.putIfAbsent(p.id, () => TextEditingController());

  void _applyReorderRule(Product p) {
    final onHand = int.tryParse(_getOnHandController(p).text) ?? 0;
    if (p.reorderRule.minStockPcs > 0 && onHand < p.reorderRule.minStockPcs) {
      _getOrderQtyController(p).text = p.reorderRule.defaultOrderQty.toString();
    } else {
      _getOrderQtyController(p).text = '0';
    }
    setState(() {});
  }

  int get _counted {
    return _onHandControllers.values.where((c) => c.text.isNotEmpty).length;
  }

  // Excel-style grid border
  static const _gridColor = Color(0xFFD0D5DD); // Medium gray grid lines
  static const _headerBg = Color(0xFF374151);   // Dark header like Excel
  static const _headerText = Color(0xFFFFFFFF);
  static const _rowEvenBg = Colors.white;
  static const _rowOddBg = Color(0xFFF8FAFC);   // Very light blue-gray
  static const _rowNumberBg = Color(0xFFF1F5F9); // Light gray for row numbers
  static const _cellEditBg = Color(0xFFFFFBEB);  // Light yellow for editable cells
  static const _cellFilledBg = Color(0xFFECFDF5); // Light green when filled

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB), // Gray background like Excel window
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editingOrder != null ? 'Edit Order' : 'Create Order',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '${widget.vendor.name} · ${widget.store.name}',
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
        actions: [
          // Progress chip
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Consumer<ProductProvider>(
              builder: (context, p, _) {
                final total = p.products.length;
                return Text(
                  '$_counted/$total',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            onPressed: () => _showQuickAddProductDialog(context),
            tooltip: 'Add Product',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, _) {
          final products = productProvider.products;

          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textTertiary),
                  const SizedBox(height: 12),
                  Text('No products for this vendor', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _gridColor, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                // ─── Spreadsheet Header Row ───
                Container(
                  decoration: const BoxDecoration(
                    color: _headerBg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                  child: Row(
                    children: [
                      // Row number column header
                      _headerCell('#', width: 32, align: TextAlign.center),
                      _verticalDivider(color: Colors.white24),
                      // Product name + SKU + reorder (merged column)
                      Expanded(child: _headerCell('PRODUCT / SKU', align: TextAlign.left)),
                      _verticalDivider(color: Colors.white24),
                      // On Hand column
                      _headerCell('ON HAND', width: 76, align: TextAlign.center),
                      _verticalDivider(color: Colors.white24),
                      // Order column
                      _headerCell('ORDER', width: 76, align: TextAlign.center),
                    ],
                  ),
                ),

                // ─── Spreadsheet Data Rows ───
                Expanded(
                  child: ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final onHandCtrl = _getOnHandController(product);
                      final orderCtrl = _getOrderQtyController(product);
                      final isEven = index % 2 == 0;
                      final hasOnHand = onHandCtrl.text.isNotEmpty;
                      final hasOrder = orderCtrl.text.isNotEmpty && orderCtrl.text != '0';

                      return Container(
                        decoration: BoxDecoration(
                          color: isEven ? _rowEvenBg : _rowOddBg,
                          border: Border(bottom: BorderSide(color: _gridColor, width: 0.5)),
                        ),
                        constraints: const BoxConstraints(minHeight: 56),
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
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              ),
                              _verticalDivider(),

                              // ─── Product info cell: Name (bold) + SKU + Reorder ───
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    await Navigator.of(context).pushNamed(
                                      '/product',
                                      arguments: {
                                        'product': product,
                                        'store': widget.store,
                                        'vendor': widget.vendor,
                                      },
                                    );
                                    if (mounted) {
                                      context.read<ProductProvider>().loadProductsByVendor(widget.store.id, widget.vendor.id);
                                    }
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Product name — large, bold, prominent
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                            height: 1.25,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        // Second line: SKU + Reorder info
                                        Row(
                                          children: [
                                            // SKU badge
                                            if (product.sku.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                margin: const EdgeInsets.only(right: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE0E7FF), // Light indigo
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: Text(
                                                  product.sku,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF4338CA), // Indigo 700
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ),
                                            // Reorder rule — always show
                                            if (product.reorderRule.minStockPcs > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFD1FAE5), // Emerald 100
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: Text(
                                                  'Min ${product.reorderRule.minStockPcs}  ▸  ${product.reorderRule.defaultOrderQty} cs',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF047857), // Emerald 700
                                                  ),
                                                ),
                                              )
                                            else
                                              Text(
                                                'No reorder rule',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppTheme.textTertiary,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              _verticalDivider(),

                              // On Hand input cell
                              Container(
                                width: 76,
                                color: hasOnHand ? _cellFilledBg : _cellEditBg,
                                child: TextField(
                                  controller: onHandCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: hasOnHand ? AppTheme.textPrimary : AppTheme.textTertiary,
                                    fontFamily: 'monospace',
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                    hintText: '—',
                                    hintStyle: TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textTertiary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  onChanged: (_) {
                                    _applyReorderRule(product);
                                  },
                                ),
                              ),
                              _verticalDivider(),

                              // Order qty input cell
                              Container(
                                width: 76,
                                color: hasOrder ? const Color(0xFFDBEAFE) : _cellEditBg, // Light blue when filled
                                child: TextField(
                                  controller: orderCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: hasOrder ? AppTheme.secondaryColor : AppTheme.textTertiary,
                                    fontFamily: 'monospace',
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                    hintText: '—',
                                    hintStyle: TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textTertiary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ─── Footer summary row ───
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                    border: Border(top: BorderSide(color: _gridColor, width: 1)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 32), // row number width
                      Expanded(
                        child: Text(
                          '${products.length} products · $_counted counted',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                      ),
                      // Sum of order cases
                      Text(
                        'Total: ${_totalOrderCases(products)} cs',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.secondaryColor),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),

      // Bottom bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _gridColor)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveOrder(context, 'draft'),
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Draft'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _saveOrder(context, 'submitted'),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Submit Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helper: header cell ───
  Widget _headerCell(String text, {double? width, TextAlign align = TextAlign.center}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      alignment: align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _headerText,
          letterSpacing: 0.8,
        ),
        textAlign: align,
      ),
    );
    return width != null ? SizedBox(width: width, child: child) : child;
  }

  // ─── Helper: vertical grid divider ───
  Widget _verticalDivider({Color? color}) {
    return Container(width: 0.5, color: color ?? _gridColor);
  }

  // ─── Helper: total order cases ───
  int _totalOrderCases(List<Product> products) {
    int total = 0;
    for (final p in products) {
      total += int.tryParse(_getOrderQtyController(p).text) ?? 0;
    }
    return total;
  }

  void _showQuickAddProductDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick Add Product'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(Icons.label, size: 20)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final product = Product(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  vendorId: widget.vendor.id,
                  name: nameCtrl.text.trim(),
                  sku: '',
                  pcsPerCase: 1, pcsPerLine: 1,
                  storePrice: 0, onlinePrice: 0, storeCasePrice: 0, onlineCasePrice: 0, pcCost: 0, caseCost: 0,
                  reorderRule: ReorderRule(minStockPcs: 0, defaultOrderQty: 0),
                  createdAt: DateTime.now(),
                );
                context.read<ProductProvider>().addProduct(widget.store.id, widget.vendor.id, product);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOrder(BuildContext context, String status) async {
    final productProvider = context.read<ProductProvider>();
    final orderProvider = context.read<OrderProvider>();

    final items = <OrderItem>[];
    for (var product in productProvider.products) {
      final onHand = int.tryParse(_getOnHandController(product).text) ?? 0;
      final orderQty = int.tryParse(_getOrderQtyController(product).text) ?? 0;
      if (onHand > 0 || orderQty > 0) {
        items.add(OrderItem(
          id: '${product.id}_${DateTime.now().millisecondsSinceEpoch}',
          productId: product.id,
          productName: product.name,
          onHandQtyPcs: onHand,
          orderQtyCases: orderQty,
          createdAt: DateTime.now(),
        ));
      }
    }

    if (items.isEmpty && status == 'submitted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to submit. Enter on-hand quantities first.')),
      );
      return;
    }

    final order = Order(
      id: widget.editingOrder?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      storeId: widget.store.id,
      vendorId: widget.vendor.id,
      items: items,
      status: status,
      orderDate: DateTime.now(),
      createdAt: widget.editingOrder?.createdAt ?? DateTime.now(),
    );

    if (widget.editingOrder != null) {
      await orderProvider.updateOrder(order);
    } else {
      await orderProvider.addOrder(order);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'draft' ? 'Draft saved' : 'Order submitted'),
          backgroundColor: AppTheme.accentColor,
        ),
      );

      // Send WhatsApp message when order is submitted
      if (status == 'submitted') {
        await _sendWhatsAppOrder(context, order, items);
      }

      if (context.mounted) Navigator.pop(context);
    }
  }

  /// Build a professional WhatsApp order message and open wa.me
  Future<void> _sendWhatsAppOrder(
    BuildContext context,
    Order order,
    List<OrderItem> items,
  ) async {
    final phone = widget.vendor.whatsappPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No WhatsApp number set for this vendor. Update vendor details to enable WhatsApp orders.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(order.orderDate);
    final timeStr = DateFormat('h:mm a').format(order.orderDate);

    // Only include items with orderQtyCases > 0
    final orderItems = items.where((i) => i.orderQtyCases > 0).toList();

    if (orderItems.isEmpty) return;

    // Calculate total cases
    int totalCases = 0;
    for (final item in orderItems) {
      totalCases += item.orderQtyCases;
    }

    final buffer = StringBuffer();

    // Header
    buffer.writeln('📋 *ORDER — ${widget.store.name}*');
    buffer.writeln('🚚 ${widget.vendor.name} · $dateStr $timeStr');
    buffer.writeln('#${order.id.substring(order.id.length > 6 ? order.id.length - 6 : 0)}');
    buffer.writeln('');

    // Item list — one compact line each
    for (int i = 0; i < orderItems.length; i++) {
      final item = orderItems[i];
      final caseLabel = item.orderQtyCases == 1 ? 'case' : 'cases';

      buffer.writeln('${i + 1}. ${item.productName} — ${item.orderQtyCases} $caseLabel');
    }

    // Footer
    buffer.writeln('');
    buffer.writeln('*${orderItems.length} items · $totalCases cases*');

    final message = buffer.toString();
    final encodedMessage = Uri.encodeComponent(message);
    final waUrl = Uri.parse('https://wa.me/$phone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open WhatsApp. Please ensure it is installed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
