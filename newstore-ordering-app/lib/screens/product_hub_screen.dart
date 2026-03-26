import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/providers/label_queue_provider.dart';
import 'package:newstore_ordering_app/utils/theme.dart';
import 'package:newstore_ordering_app/utils/design_tokens.dart';
import 'package:newstore_ordering_app/utils/image_picker_web.dart';
import 'package:newstore_ordering_app/providers/plu_provider.dart';
import 'package:newstore_ordering_app/services/sync_service.dart';
import 'package:newstore_ordering_app/utils/image_compress_web.dart';
import 'package:newstore_ordering_app/services/product_hub_engine.dart';
import 'package:url_launcher/url_launcher.dart';

/// Product Hub Screen — unified product management across
/// Firebase, Shopify (apniroots.com), and Penny Lane POS.
///
/// Two modes:
///   STOCK — during stocking/shelf verification
///   ORDER — building vendor orders from product list
class ProductHubScreen extends StatefulWidget {
  final Product product;
  final Store store;
  final Vendor vendor;
  final Order? currentOrder;
  final String mode; // 'stock' or 'order'

  const ProductHubScreen({
    Key? key,
    required this.product,
    required this.store,
    required this.vendor,
    this.currentOrder,
    this.mode = 'stock',
  }) : super(key: key);

  @override
  State<ProductHubScreen> createState() => _ProductHubScreenState();
}

class _ProductHubScreenState extends State<ProductHubScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ──
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _pcsPerCaseController;
  late TextEditingController _pcsPerLineController;
  late TextEditingController _storePriceController;
  late TextEditingController _onlinePriceController;
  late TextEditingController _storeCasePriceController;
  late TextEditingController _onlineCasePriceController;
  late TextEditingController _pcCostController;
  late TextEditingController _caseCostController;
  late TextEditingController _minStockController;
  late TextEditingController _defaultOrderQtyController;

  // ── Image state ──
  String _frontImageBase64 = '';
  String _backImageBase64 = '';
  bool _isRemovingBgFront = false;
  bool _isRemovingBgBack = false;

  // ── Hub status ──
  ProductHubEngine? _hubEngine;
  ProductHubStatus _hubStatus = ProductHubStatus();
  bool _isHydrating = false;

  // ── Tax ──
  String _posTaxCode = '1';

  // ── Categories ──
  String _posDepartmentName = '';
  List<String> _shopifyTags = [];
  bool _categoryConfirmed = false;

  // ── Fold state ──
  bool _localCapturesExpanded = false;
  bool _notesExpanded = false;

  // ── Sync state ──
  bool _isSyncingShopify = false;
  bool _isExportingPOS = false;
  bool _isSaving = false;

  // remove.bg API key
  static const String _removeBgApiKey = '8g311xjc3aQaxLi58RQZwiHn';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _frontImageBase64 = widget.product.frontImageBase64;
    _backImageBase64 = widget.product.backImageBase64;
    _posTaxCode = widget.product.posTaxCode;
    _posDepartmentName = widget.product.posDepartmentName;
    _shopifyTags = List.from(widget.product.shopifyTags);
    _categoryConfirmed = widget.product.categoryConfirmed;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hubEngine = ProductHubEngine(
        pluProvider: context.read<PLUProvider>(),
      );
      _hubEngine!.loadMasterLists();
      _hydrateProduct();
    });
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.product.name);
    _skuController = TextEditingController(text: widget.product.sku);
    _pcsPerCaseController = TextEditingController(text: widget.product.pcsPerCase.toString());
    _pcsPerLineController = TextEditingController(text: widget.product.pcsPerLine.toString());
    _storePriceController = TextEditingController(text: widget.product.storePrice.toString());
    _onlinePriceController = TextEditingController(text: widget.product.onlinePrice.toString());
    _storeCasePriceController = TextEditingController(text: widget.product.storeCasePrice.toString());
    _onlineCasePriceController = TextEditingController(text: widget.product.onlineCasePrice.toString());
    _pcCostController = TextEditingController(text: widget.product.pcCost.toString());
    _caseCostController = TextEditingController(text: widget.product.caseCost.toString());
    _minStockController = TextEditingController(text: widget.product.reorderRule.minStockPcs.toString());
    _defaultOrderQtyController = TextEditingController(text: widget.product.reorderRule.defaultOrderQty.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _pcsPerCaseController.dispose();
    _pcsPerLineController.dispose();
    _storePriceController.dispose();
    _onlinePriceController.dispose();
    _storeCasePriceController.dispose();
    _onlineCasePriceController.dispose();
    _pcCostController.dispose();
    _caseCostController.dispose();
    _minStockController.dispose();
    _defaultOrderQtyController.dispose();
    super.dispose();
  }

  Future<void> _hydrateProduct() async {
    final sku = _skuController.text.trim();
    if (sku.isEmpty || _hubEngine == null) return;

    setState(() => _isHydrating = true);

    try {
      final status = await _hubEngine!.hydrate(sku);
      if (mounted) {
        setState(() {
          _hubStatus = status;
          _isHydrating = false;

          // Auto-fill from POS if found and fields are empty
          if (status.inPlu && status.pluProduct != null) {
            final plu = status.pluProduct!;
            if (_nameController.text.isEmpty) _nameController.text = plu.desc;
            _posTaxCode = plu.taxCode.isNotEmpty ? plu.taxCode : '1';
            if (_posDepartmentName.isEmpty) _posDepartmentName = plu.deptName;
            // Show POS price in store price if not set
            if (_storePriceController.text == '0' || _storePriceController.text == '0.0') {
              _storePriceController.text = plu.price;
            }
          }

          // Auto-fill online price from Shopify if found
          if (status.inShopify && status.shopifyProduct != null) {
            final shopifyPrice = status.shopifyProduct!['price']?.toString() ?? '';
            if ((_onlinePriceController.text == '0' || _onlinePriceController.text == '0.0') && shopifyPrice.isNotEmpty) {
              _onlinePriceController.text = shopifyPrice;
            }
            // Auto-fill tags from Shopify if we have none locally
            final shopifyTags = List<String>.from(status.shopifyProduct!['tags'] ?? []);
            if (_shopifyTags.isEmpty && shopifyTags.isNotEmpty) {
              _shopifyTags = shopifyTags;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isHydrating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStock = widget.mode == 'stock';

    return Scaffold(
      backgroundColor: DS.scaffoldBg,
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.product.name.isNotEmpty ? widget.product.name : 'New Product',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _modeBadge(isStock),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 22),
            onPressed: _scanBarcode,
            tooltip: 'Scan Barcode',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // ── Vendor / Store subtitle bar ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: DS.spaceLG, vertical: DS.spaceSM),
              color: DS.subtitleBar,
              child: Text(
                '${widget.vendor.name}  ·  ${widget.store.name}',
                style: const TextStyle(fontSize: DS.fontSM, color: DS.textSubtitle, letterSpacing: 0.3),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ═══════════════════════════════════════
                    //  1. SKU ROW — scan + hydrate
                    // ═══════════════════════════════════════
                    _buildSkuRow(),

                    // ═══════════════════════════════════════
                    //  2. HYDRATION STATUS
                    // ═══════════════════════════════════════
                    _buildDetailedStatusSection(),

                    // ═══════════════════════════════════════
                    //  3. CONFLICT ALERTS
                    // ═══════════════════════════════════════
                    if (_hubStatus.hasConflicts) _buildFoldableConflictAlerts(),

                    // ═══════════════════════════════════════
                    //  4. NAME COMPARISON — POS vs Shopify
                    // ═══════════════════════════════════════
                    _buildNameComparison(),

                    // ═══════════════════════════════════════
                    //  5. POS vs SHOPIFY COMPARISON TABLE
                    // ═══════════════════════════════════════
                    _sectionHeader('POS  vs  SHOPIFY  —  Comparison', Icons.compare_arrows),
                    _buildComparisonTable(),

                    // ═══════════════════════════════════════
                    //  6. SHOPIFY IMAGE + LOCAL CAPTURES
                    // ═══════════════════════════════════════
                    _sectionHeader('PRODUCT IMAGES', Icons.camera_alt),
                    _buildShopifyImageRow(),
                    _buildFoldableLocalImageCaptures(),

                    // ═══════════════════════════════════════
                    //  7. FIREBASE EDITABLE FIELDS
                    // ═══════════════════════════════════════
                    _buildFirebaseEditableCard(),

                    const SizedBox(height: 80), // space for bottom bar
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom bar
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SKU ROW — prominent at top with scan button
  // ═══════════════════════════════════════════════════════════

  Widget _buildSkuRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _gridColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DS.spaceMD),
            decoration: BoxDecoration(
              color: DS.skuBg,
              borderRadius: BorderRadius.circular(DS.radiusMD),
            ),
            child: const Icon(Icons.qr_code, size: DS.iconXXL, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SKU / Barcode', style: TextStyle(fontSize: DS.fontS, fontWeight: DS.weightSemi, color: DS.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                SizedBox(
                  height: 36,
                  child: TextFormField(
                    controller: _skuController,
                    style: const TextStyle(fontSize: DS.fontXXL, fontWeight: DS.weightBold, fontFamily: 'monospace', letterSpacing: 1),
                    decoration: const InputDecoration(
                      hintText: 'Scan or type SKU',
                      hintStyle: TextStyle(fontSize: DS.fontL, color: DS.textDisabled),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    onFieldSubmitted: (_) => _hydrateProduct(),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _scanBarcode,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
              ),
              child: Icon(Icons.qr_code_scanner, size: DS.iconScan, color: AppTheme.accentColor),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _hydrateProduct,
            child: Container(
              padding: const EdgeInsets.all(DS.spaceMD),
              decoration: BoxDecoration(
                color: DS.posColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(DS.radiusMD),
                border: Border.all(color: DS.posColor.withOpacity(0.3)),
              ),
              child: _isHydrating
                  ? const SizedBox(width: DS.iconScan, height: DS.iconScan, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search, size: DS.iconScan, color: DS.posColor),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  NAME COMPARISON — POS name vs Shopify name vs Firebase
  // ═══════════════════════════════════════════════════════════

  Widget _buildNameComparison() {
    final posName = _hubStatus.inPlu ? (_hubStatus.pluProduct?.desc ?? '—') : '—';
    final shopifyName = _hubStatus.inShopify ? (_hubStatus.shopifyProduct?['productTitle']?.toString() ?? '—') : '—';
    final firebaseName = _nameController.text.isNotEmpty ? _nameController.text : '—';

    final allSame = posName != '—' && shopifyName != '—' && posName.toLowerCase() == shopifyName.toLowerCase();

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: allSame ? DS.successLight : DS.warningBorder, width: 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: allSame ? DS.successBg : DS.warningBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              children: [
                Icon(allSame ? Icons.check_circle : Icons.info_outline, size: 14,
                    color: allSame ? DS.successColor : DS.warningDark),
                const SizedBox(width: 6),
                Text(
                  allSame ? 'Names match across systems' : 'Product Names',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: allSame ? DS.successColor : DS.warningDeep,
                  ),
                ),
              ],
            ),
          ),
          // POS
          _nameRow('POS (Penny Lane)', posName, DS.posColor, Icons.point_of_sale),
          const Divider(height: 0.5, thickness: 0.5, color: DS.dividerColor),
          // Shopify
          _nameRow('Shopify (apniroots)', shopifyName, DS.shopifyColor, Icons.shopping_bag_outlined),
          const Divider(height: 0.5, thickness: 0.5, color: DS.dividerColor),
          // Firebase
          _nameRow('Firebase (Your Data)', firebaseName, DS.firebaseColor, Icons.cloud),
        ],
      ),
    );
  }

  Widget _nameRow(String system, String name, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.spaceL, vertical: DS.spaceSM),
      child: Row(
        children: [
          Icon(icon, size: DS.iconSM, color: color),
          const SizedBox(width: DS.spaceM),
          SizedBox(
            width: DS.nameColWidth,
            child: Text(system, style: DS.systemLabelStyle(color)),
          ),
          Expanded(
            child: Text(name, style: DS.valueStyle, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  POS vs SHOPIFY COMPARISON TABLE
  // ═══════════════════════════════════════════════════════════

  Widget _buildComparisonTable() {
    final hasPOS = _hubStatus.inPlu && _hubStatus.pluProduct != null;
    final hasShopify = _hubStatus.inShopify && _hubStatus.shopifyProduct != null;

    if (!hasPOS && !hasShopify) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Center(
          child: Text(
            _skuController.text.isEmpty
                ? 'Enter a SKU to see comparison'
                : _isHydrating ? 'Loading…' : 'No data found in POS or Shopify',
            style: TextStyle(fontSize: 12, color: Colors.grey[400], fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final plu = _hubStatus.pluProduct;
    final shopify = _hubStatus.shopifyProduct;

    // Build comparison rows: [label, posValue, shopifyValue, isConflict]
    final rows = <_CompRow>[
      _CompRow('Price', hasPOS ? '\$${plu!.price}' : '—', hasShopify ? '\$${shopify!['price']}' : '—'),
      _CompRow('Department / Tag', hasPOS ? plu!.deptName : '—', hasShopify ? (shopify!['tags'] as List?)?.join(', ') ?? '—' : '—'),
      _CompRow('Tax', hasPOS ? plu!.taxLabel : '—', hasShopify ? ((shopify!['taxable'] as bool? ?? true) ? 'Taxable' : 'Non-Taxable') : '—',
          semanticMatch: hasPOS && hasShopify && plu!.isTaxable == (shopify!['taxable'] as bool? ?? true)),
      _CompRow('Vendor', hasPOS ? plu!.vendName : '—', hasShopify ? (shopify!['vendor']?.toString() ?? '—') : '—'),
      _CompRow('Cost (pc)', hasPOS ? '\$${plu!.cost}' : '—', '—'), // Shopify doesn't store cost
      _CompRow('Items in Box', _pcsPerCaseController.text, '—'),  // Only in Firebase
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _gridColor, width: 0.5)),
      ),
      child: Column(
        children: [
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            child: Row(
              children: [
                _compColHeader('', flex: 2, color: DS.chipSlate),
                _compColHeader('POS', flex: 3, color: DS.posColor, icon: Icons.point_of_sale),
                _compColHeader('SHOPIFY', flex: 3, color: DS.shopifyDark, icon: Icons.shopping_bag_outlined),
              ],
            ),
          ),
          // Data rows
          ...rows.map((r) {
            final isConflict = !r.semanticMatch &&
                r.posValue != '—' && r.shopifyValue != '—' &&
                r.posValue.toLowerCase() != r.shopifyValue.toLowerCase();
            return _compDataRow(r.label, r.posValue, r.shopifyValue, isConflict: isConflict);
          }),
        ],
      ),
    );
  }

  Widget _compColHeader(String label, {required int flex, required Color color, IconData? icon}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DS.spaceM, vertical: DS.sectionHeaderPadV),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: const Border(bottom: BorderSide(color: _gridColor, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: DS.iconXS, color: color),
              const SizedBox(width: DS.spaceXS),
            ],
            Text(label, style: DS.compHeaderStyle(color)),
          ],
        ),
      ),
    );
  }

  Widget _compDataRow(String label, String posVal, String shopifyVal, {bool isConflict = false}) {
    final bgColor = isConflict ? DS.errorBg : DS.cardBg;
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(bottom: BorderSide(color: _gridColor, width: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Label
            Expanded(
              flex: 2,
              child: Container(
                color: _labelBg,
                padding: const EdgeInsets.symmetric(horizontal: DS.spaceMD, vertical: DS.compRowPadV),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    if (isConflict)
                      const Padding(
                        padding: EdgeInsets.only(right: DS.spaceXS),
                        child: Icon(Icons.warning_amber_rounded, size: DS.iconXS, color: DS.conflictColor),
                      ),
                    Expanded(child: Text(label, style: DS.compLabelStyle(isConflict: isConflict))),
                  ],
                ),
              ),
            ),
            Container(width: 0.5, color: _gridColor),
            // POS value
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: DS.spaceMD, vertical: DS.compRowPadV),
                alignment: Alignment.center,
                child: Text(posVal,
                  style: posVal == '—' ? DS.valueMutedStyle : DS.valueStyle,
                  textAlign: TextAlign.center),
              ),
            ),
            Container(width: 0.5, color: _gridColor),
            // Shopify value
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: DS.spaceMD, vertical: DS.compRowPadV),
                alignment: Alignment.center,
                child: Text(shopifyVal,
                  style: shopifyVal == '—' ? DS.valueMutedStyle : DS.valueStyle,
                  textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CONFLICT ALERTS
  // ═══════════════════════════════════════════════════════════

  Widget _buildConflictAlerts() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: _hubStatus.conflicts.map((conflict) {
          final isCrit = conflict.isCritical;
          final color = isCrit ? DS.conflictColor : DS.warningColor;
          final bg = isCrit ? DS.errorBg : DS.warningBg;

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(isCrit ? Icons.error : Icons.info_outline, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conflict.message,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                      ),
                      if (conflict.posValue.isNotEmpty || conflict.shopifyValue.isNotEmpty)
                        Text(
                          'POS: ${conflict.posValue}  ·  Shopify: ${conflict.shopifyValue}',
                          style: TextStyle(fontSize: 9, color: color.withOpacity(0.8)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Foldable conflict alerts — auto-expanded when critical errors exist,
  /// collapsed by default when only info/warnings (notes)
  Widget _buildFoldableConflictAlerts() {
    final hasCritical = _hubStatus.conflicts.any((c) => c.isCritical);

    // If there are critical errors, always show expanded
    if (hasCritical) return _buildConflictAlerts();

    // Otherwise, notes only — make foldable
    final noteCount = _hubStatus.conflicts.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _notesExpanded = !_notesExpanded),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: DS.warningBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: DS.warningColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: DS.warningColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$noteCount note${noteCount > 1 ? 's' : ''} — no errors',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DS.warningColor),
                    ),
                  ),
                  Icon(
                    _notesExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: DS.warningColor,
                  ),
                ],
              ),
            ),
          ),
          if (_notesExpanded) ...[
            const SizedBox(height: 4),
            _buildConflictAlerts(),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  FIREBASE EDITABLE CARD — all editable fields grouped
  // ═══════════════════════════════════════════════════════════

  Widget _buildFirebaseEditableCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DS.firebaseColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ── Card Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: DS.spaceLG, vertical: DS.spaceSM),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [DS.firebaseColor.withOpacity(0.08), DS.firebaseColor.withOpacity(0.03)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
              border: const Border(bottom: BorderSide(color: DS.gridColor, width: 0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.edit_note_rounded, size: DS.iconL, color: DS.firebaseColor),
                SizedBox(width: DS.spaceM),
                Text('YOUR DATA', style: TextStyle(fontSize: DS.fontSM, fontWeight: DS.weightHeavy, color: DS.firebaseColor, letterSpacing: 1)),
                SizedBox(width: DS.spaceM),
                Text('·  editable fields', style: TextStyle(fontSize: DS.fontS, color: DS.textFaint)),
              ],
            ),
          ),

          // ── Product Name ──
          _gridRow('Product Name', child: _gridInput(_nameController, validator: (v) => v?.isEmpty == true ? 'Required' : null)),

          // ── Packaging ──
          _priceSubHeader('PACKAGING', Icons.inventory_2_outlined, DS.chipSlate),
          _gridDoubleRow('Pcs / Case', _pcsPerCaseController, 'Pcs / Line', _pcsPerLineController, isNumber: true),

          // ── Pricing ──
          _buildSplitPricingSection(),

          // ── Tax ──
          _priceSubHeader('TAX', Icons.receipt_long_outlined, DS.subLabel),
          _buildTaxSection(),

          // ── Categories ──
          _priceSubHeader('CATEGORIES', Icons.category_outlined, DS.subLabel),
          _buildCategorySection(),

          // ── Reorder Rules ──
          _priceSubHeader('REORDER', Icons.autorenew_rounded, DS.subLabel),
          _gridDoubleRow('Min Stock (pcs)', _minStockController, 'Default Order (cs)', _defaultOrderQtyController, isNumber: true),

          // ── Quick Actions (Label + Sync) ──
          _buildQuickActionsRow(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  QUICK ACTIONS ROW — label + sync inside the card
  // ═══════════════════════════════════════════════════════════

  Widget _buildQuickActionsRow() {
    final sku = _skuController.text.trim();
    final hasData = sku.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _gridColor, width: 0.5)),
      ),
      child: Row(
        children: [
          // Label request — compact
          if (hasData)
            Expanded(
              child: PopupMenuButton<String>(
                onSelected: (reason) => _addToLabelQueue(reason),
                offset: const Offset(0, -120),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'missing', child: Text('🏷️  Missing label', style: TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 'wrong_price', child: Text('💲  Wrong price', style: TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 'new_product', child: Text('🆕  New product', style: TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 'damaged', child: Text('🔧  Damaged', style: TextStyle(fontSize: 12))),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: DS.outlinedPill(DS.labelColor),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.label_outline, size: DS.iconM, color: DS.labelColor),
                      SizedBox(width: DS.spaceS),
                      Text('Label', style: TextStyle(fontSize: DS.fontSM, fontWeight: DS.weightSemi, color: DS.labelColor)),
                    ],
                  ),
                ),
              ),
            ),
          if (hasData) const SizedBox(width: 6),
          // Shopify sync
          Expanded(
            child: InkWell(
              onTap: (hasData && !_isSyncingShopify) ? _syncToShopify : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: DS.spaceMD, vertical: DS.spaceSM),
                decoration: DS.filledPill(DS.shopifyColor, bgOpacity: hasData ? 0.1 : 0.04, borderOpacity: hasData ? 0.4 : 0.15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSyncingShopify)
                      const SizedBox(width: DS.iconS, height: DS.iconS, child: CircularProgressIndicator(strokeWidth: 2, color: DS.shopifyColor))
                    else
                      Icon(Icons.shopping_bag_outlined, size: DS.iconM, color: Color(hasData ? 0xFF4D7C0F : 0xFFBBBBBB)),
                    const SizedBox(width: DS.spaceS),
                    Text(
                      _isSyncingShopify ? 'Syncing…' : _hubStatus.inShopify ? 'Update Shopify' : 'Shopify',
                      style: DS.actionBtnStyle(Color(hasData ? 0xFF4D7C0F : 0xFFBBBBBB)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // POS Export
          Expanded(
            child: InkWell(
              onTap: (hasData && !_isExportingPOS) ? _exportToPOS : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: DS.spaceMD, vertical: DS.spaceSM),
                decoration: DS.filledPill(DS.posColor, bgOpacity: hasData ? 0.08 : 0.03, borderOpacity: hasData ? 0.3 : 0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isExportingPOS)
                      const SizedBox(width: DS.iconS, height: DS.iconS, child: CircularProgressIndicator(strokeWidth: 2, color: DS.posColor))
                    else
                      Icon(Icons.point_of_sale, size: DS.iconM, color: hasData ? DS.posColor : DS.textDisabled),
                    const SizedBox(width: DS.spaceS),
                    Text(
                      _isExportingPOS ? 'Exporting…' : 'POS',
                      style: DS.actionBtnStyle(hasData ? DS.posColor : DS.textDisabled),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SPLIT PRICING — Store vs Online
  // ═══════════════════════════════════════════════════════════

  Widget _buildSplitPricingSection() {
    return Column(
      children: [
        // ── STORE (→ POS) ──
        _priceSubHeader('STORE  →  POS', Icons.point_of_sale, DS.posColor,
          trailing: (_hubStatus.inPlu && _hubStatus.pluProduct != null)
              ? 'POS: \$${_hubStatus.pluProduct!.price}' : null,
        ),
        _gridDoubleRow('Piece', _storePriceController, 'Case', _storeCasePriceController, prefix: '\$', isDecimal: true),
        // ── ONLINE (→ Shopify) ──
        _priceSubHeader('ONLINE  →  Shopify', Icons.shopping_bag_outlined, DS.successColor,
          trailing: (_hubStatus.inShopify && _hubStatus.shopifyProduct != null)
              ? 'Shopify: \$${_hubStatus.shopifyProduct!['price'] ?? ''}' : null,
        ),
        _gridDoubleRow('Piece', _onlinePriceController, 'Case', _onlineCasePriceController, prefix: '\$', isDecimal: true),
        // ── COST ──
        _priceSubHeader('COST', Icons.account_balance_wallet_outlined, DS.chipSlate),
        _gridDoubleRow('Piece', _pcCostController, 'Case', _caseCostController, prefix: '\$', isDecimal: true),
      ],
    );
  }

  Widget _priceSubHeader(String label, IconData icon, Color color, {String? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.spaceL, vertical: DS.subHeaderPadV),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: const Border(bottom: BorderSide(color: _gridColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: DS.iconS, color: color),
          const SizedBox(width: DS.spaceSM),
          Text(label, style: DS.subHeaderStyle(color)),
          if (trailing != null) ...[
            const Spacer(),
            Text(trailing, style: TextStyle(fontSize: DS.fontS, color: color.withOpacity(0.7))),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TAX SECTION — POS is master
  // ═══════════════════════════════════════════════════════════

  Widget _buildTaxSection() {
    final posHasTax = _hubStatus.inPlu && _hubStatus.pluProduct != null;
    final shopifyHasTax = _hubStatus.inShopify && _hubStatus.shopifyProduct != null;
    final shopifyTaxable = shopifyHasTax ? (_hubStatus.shopifyProduct!['taxable'] as bool? ?? true) : null;
    final posIsTaxable = posHasTax ? POSTaxCode.isTaxable(_hubStatus.pluProduct!.taxCode) : null;
    final isMismatch = posIsTaxable != null && shopifyTaxable != null && posIsTaxable != shopifyTaxable;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _gridColor, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact read-only row for POS + Shopify tax
          if (posHasTax || shopifyHasTax)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isMismatch ? DS.errorLightBg : DS.infoBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isMismatch ? DS.errorLight : DS.infoBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  if (posHasTax) ...[
                    const Icon(Icons.point_of_sale, size: 12, color: DS.posColor),
                    const SizedBox(width: 4),
                    Text(POSTaxCode.label(_hubStatus.pluProduct!.taxCode),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: DS.posColor)),
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: DS.badgeDecoration(DS.posColor),
                      child: const Text('MASTER', style: DS.badgeStyle),
                    ),
                  ],
                  if (posHasTax && shopifyHasTax) ...[
                    Container(width: 1, height: 16, color: DS.gridColor, margin: const EdgeInsets.symmetric(horizontal: 8)),
                  ],
                  if (shopifyHasTax) ...[
                    const Icon(Icons.shopping_bag_outlined, size: 12, color: DS.successColor),
                    const SizedBox(width: 4),
                    Text(shopifyTaxable! ? 'Taxable' : 'Non-tax',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                            color: isMismatch ? DS.conflictColor : DS.successColor)),
                    if (isMismatch) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: DS.badgeDecoration(DS.conflictColor),
                        child: const Text('MISMATCH', style: DS.badgeStyle),
                      ),
                    ] else ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.check_circle, size: 11, color: DS.successColor),
                    ],
                  ],
                ],
              ),
            ),
          // Editable chips
          Row(
            children: [
              const Text('Set Tax:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DS.subLabel)),
              const SizedBox(width: 8),
              ...POSTaxCode.allCodes.map((code) {
                final isSelected = _posTaxCode == code;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(POSTaxCode.label(code),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : DS.textLabel)),
                    selected: isSelected,
                    selectedColor: DS.posColor,
                    backgroundColor: DS.neutralBg,
                    onSelected: (selected) { if (selected) setState(() => _posTaxCode = code); },
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CATEGORY SECTION — POS Dept ↔ Shopify Tags
  // ═══════════════════════════════════════════════════════════

  Widget _buildCategorySection() {
    final posDepts = _hubEngine?.posDepartments ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _gridColor, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── POS Department ──
          Row(
            children: [
              const Icon(Icons.point_of_sale, size: 12, color: DS.posColor),
              const SizedBox(width: 5),
              const Text('POS Dept', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: DS.posColor)),
              if (_hubStatus.inPlu && _hubStatus.pluProduct != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: DS.posInfoBg, borderRadius: BorderRadius.circular(3)),
                  child: Text(_hubStatus.pluProduct!.deptName, style: const TextStyle(fontSize: 9, color: DS.posColor)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 34,
            child: posDepts.isNotEmpty
                ? DropdownButtonFormField<String>(
                    value: _posDepartmentName.isNotEmpty && posDepts.contains(_posDepartmentName)
                        ? _posDepartmentName : null,
                    items: posDepts.map((dept) =>
                      DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 11)))).toList(),
                    onChanged: (val) => setState(() => _posDepartmentName = val ?? ''),
                    decoration: InputDecoration(
                      hintText: 'Select department',
                      hintStyle: const TextStyle(fontSize: 10),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      isDense: true,
                    ),
                    isExpanded: true,
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  )
                : TextFormField(
                    initialValue: _posDepartmentName,
                    onChanged: (val) => _posDepartmentName = val,
                    decoration: InputDecoration(
                      hintText: 'Type department',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
          ),

          const SizedBox(height: 8),

          // ── Shopify Tags ──
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 12, color: DS.successColor),
              const SizedBox(width: 5),
              const Text('Shopify Tags', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: DS.successColor)),
              if (_shopifyTags.isEmpty) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: DS.errorLightBg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text('REQUIRED', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: DS.conflictColor)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ..._shopifyTags.map((tag) => Chip(
                label: Text(tag, style: const TextStyle(fontSize: 9)),
                deleteIcon: const Icon(Icons.close, size: 12),
                onDeleted: () => setState(() => _shopifyTags.remove(tag)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                backgroundColor: DS.shopifyChipBg,
                side: const BorderSide(color: DS.successBorder, width: 0.5),
              )),
              ActionChip(
                avatar: const Icon(Icons.add, size: 12, color: DS.successColor),
                label: const Text('Add', style: TextStyle(fontSize: 9, color: DS.successColor)),
                onPressed: _addShopifyTag,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: DS.successBorder, width: 0.5),
                backgroundColor: Colors.white,
              ),
            ],
          ),

          // Confirm mapping — compact
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              onTap: () => setState(() => _categoryConfirmed = !_categoryConfirmed),
              child: Row(
                children: [
                  SizedBox(
                    width: 20, height: 20,
                    child: Checkbox(
                      value: _categoryConfirmed,
                      onChanged: (val) => setState(() => _categoryConfirmed = val ?? false),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Mapping confirmed', style: TextStyle(fontSize: 10, color: DS.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addShopifyTag() {
    showDialog(
      context: context,
      builder: (ctx) => _ShopifyTagPickerDialog(
        currentTags: _shopifyTags,
        onTagsSelected: (tags) {
          setState(() => _shopifyTags = tags);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  DETAILED STATUS SECTION
  // ═══════════════════════════════════════════════════════════

  Widget _buildDetailedStatusSection() {
    final sku = _skuController.text.trim();
    if (sku.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _gridColor, width: 0.5))),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[400], size: 16),
            const SizedBox(width: 8),
            Text('Add a SKU to check status', style: TextStyle(fontSize: 11, color: Colors.grey[400], fontStyle: FontStyle.italic)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _gridColor, width: 0.5))),
      child: Column(
        children: [
          // PLU row
          _systemStatusRow(
            label: 'POS (Penny Lane)',
            icon: Icons.point_of_sale,
            color: DS.posColor,
            checked: _hubStatus.pluChecked,
            found: _hubStatus.inPlu,
            detail: _hubStatus.inPlu && _hubStatus.pluProduct != null
                ? '${_hubStatus.pluProduct!.desc} · \$${_hubStatus.pluProduct!.price} · Tax: ${_hubStatus.pluProduct!.taxLabel} · Dept: ${_hubStatus.pluProduct!.deptName}'
                : null,
          ),
          const SizedBox(height: 4),
          // Shopify row
          _systemStatusRow(
            label: 'Shopify (apniroots.com)',
            icon: Icons.shopping_bag_outlined,
            color: DS.shopifyColor,
            checked: _hubStatus.shopifyChecked,
            found: _hubStatus.inShopify,
            detail: _hubStatus.inShopify && _hubStatus.shopifyProduct != null
                ? '${_hubStatus.shopifyProduct!['productTitle']} · \$${_hubStatus.shopifyProduct!['price']} · ${(_hubStatus.shopifyProduct!['taxable'] as bool? ?? true) ? 'Taxable' : 'Non-taxable'}'
                : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: _hydrateProduct,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 11, color: Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text('Recheck All', style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _systemStatusRow({
    required String label,
    required IconData icon,
    required Color color,
    required bool checked,
    required bool found,
    String? detail,
  }) {
    if (!checked && _isHydrating) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: DS.spaceMD, vertical: DS.statusRowPadV),
        decoration: BoxDecoration(color: DS.neutralBg, borderRadius: BorderRadius.circular(DS.radiusM)),
        child: Row(
          children: [
            const SizedBox(width: DS.iconS, height: DS.iconS, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: DS.spaceM),
            Text('$label: checking…', style: const TextStyle(fontSize: DS.fontM, color: Colors.grey)),
          ],
        ),
      );
    }

    final statusColor = found ? DS.successColor : DS.conflictColor;
    final bg = found ? DS.successBg : DS.errorBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.spaceMD, vertical: DS.statusRowPadV),
      decoration: BoxDecoration(color: checked ? bg : DS.neutralBg, borderRadius: BorderRadius.circular(DS.radiusM)),
      child: Row(
        children: [
          Icon(found ? Icons.check_circle : Icons.cancel, size: DS.iconM, color: checked ? statusColor : Colors.grey),
          const SizedBox(width: DS.spaceS),
          Icon(icon, size: DS.iconSM, color: checked ? statusColor : Colors.grey),
          const SizedBox(width: DS.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label ${checked ? (found ? "✓" : "✗") : "—"}',
                  style: DS.statusTitleStyle(checked ? statusColor : Colors.grey),
                ),
                if (detail != null)
                  Text(detail, style: DS.statusDetailStyle(statusColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToLabelQueue(String reason) async {
    final sku = _skuController.text.trim();
    final name = _nameController.text.trim();
    final price = double.tryParse(_storePriceController.text) ?? 0;

    try {
      final labelProvider = context.read<LabelQueueProvider>();
      final item = LabelQueueItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sku: sku,
        productName: name,
        reason: reason,
        correctPrice: price,
        storeId: widget.store.id,
        createdAt: DateTime.now(),
      );
      await labelProvider.addToQueue(item);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🏷️ Label request added: $name ($reason)'),
            backgroundColor: DS.labelColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  IMAGES
  // ═══════════════════════════════════════════════════════════

  Widget _buildShopifyImageRow() {
    final shopifyImageUrl = _hubStatus.shopifyImageUrl;
    final publicUrl = _hubStatus.shopifyPublicUrl;

    if (shopifyImageUrl.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: DS.shopifyBg,
        border: Border(bottom: BorderSide(color: _gridColor, width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: publicUrl.isNotEmpty
                ? () => launchUrl(Uri.parse(publicUrl), mode: LaunchMode.externalApplication)
                : null,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: DS.shopifyColor, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.network(
                  shopifyImageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 20, color: Colors.grey)),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: DS.shopifyColor, borderRadius: BorderRadius.circular(3)),
                      child: const Text('apniroots.com', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: DS.posColor, borderRadius: BorderRadius.circular(3)),
                      child: const Text('IMAGE SOURCE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ],
                ),
                if (publicUrl.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse(publicUrl), mode: LaunchMode.externalApplication),
                    child: Row(
                      children: [
                        const Icon(Icons.open_in_new, size: 11, color: DS.shopifyColor),
                        const SizedBox(width: 3),
                        const Expanded(
                          child: Text('View on apniroots.com',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: DS.shopifyColor),
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalImageCaptures() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _gridColor, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactImageCapture(
              label: 'Front (→ Shopify)',
              imageBase64: _frontImageBase64,
              isProcessing: _isRemovingBgFront,
              onCapture: () => _captureImage(isFront: true),
              onRemove: () => setState(() => _frontImageBase64 = ''),
            ),
          ),
          Container(width: 0.5, height: 120, color: _gridColor),
          Expanded(
            child: _buildCompactImageCapture(
              label: 'Back (reference)',
              imageBase64: _backImageBase64,
              isProcessing: _isRemovingBgBack,
              onCapture: () => _captureImage(isFront: false),
              onRemove: () => setState(() => _backImageBase64 = ''),
            ),
          ),
        ],
      ),
    );
  }

  /// Foldable local image captures — collapsed when Shopify has an image
  Widget _buildFoldableLocalImageCaptures() {
    final hasShopifyImage = _hubStatus.shopifyImageUrl.isNotEmpty;
    final hasLocalImages = _frontImageBase64.isNotEmpty || _backImageBase64.isNotEmpty;
    final isExpanded = _localCapturesExpanded || !hasShopifyImage;

    // If no Shopify image, always show captures expanded (no fold header)
    if (!hasShopifyImage) return _buildLocalImageCaptures();

    // Shopify has image — make foldable
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _gridColor, width: 0.5))),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _localCapturesExpanded = !_localCapturesExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    hasLocalImages ? Icons.photo_library : Icons.add_a_photo_outlined,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasLocalImages
                          ? 'Local captures (${_frontImageBase64.isNotEmpty ? "front" : ""}${_frontImageBase64.isNotEmpty && _backImageBase64.isNotEmpty ? " + " : ""}${_backImageBase64.isNotEmpty ? "back" : ""})'
                          : 'Local captures (for upload)',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ),
                  if (!isExpanded && hasLocalImages)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: DS.shopifyColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('has images', style: TextStyle(fontSize: 8, color: DS.shopifyColor)),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildLocalImageCaptures(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BOTTOM BAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _gridColor)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Cancel — text only
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: DS.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
            ),
            const Spacer(),
            // Save — primary action
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProduct,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_isSaving ? 'Saving…' : 'Save Product', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  MODE BADGE
  // ═══════════════════════════════════════════════════════════

  Widget _modeBadge(bool isStock) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isStock ? DS.labelColor : DS.firebaseColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isStock ? 'STOCK' : 'ORDER',
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  GRID HELPERS (same Excel-style as before)
  // ═══════════════════════════════════════════════════════════

  static const _gridColor = DS.gridColor;
  static const _headerBg = DS.headerBg;
  static const _headerText = DS.headerText;
  static const _labelBg = DS.labelBg;
  static const _cellEditBg = DS.cellEditBg;

  Widget _sectionHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: DS.spaceL, vertical: DS.sectionHeaderPadV),
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(bottom: BorderSide(color: _gridColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: DS.iconSM, color: _headerText),
          const SizedBox(width: DS.spaceM),
          Text(title, style: DS.sectionHeaderStyle),
        ],
      ),
    );
  }

  Widget _gridRow(String label, {required Widget child}) {
    return Container(
      constraints: const BoxConstraints(minHeight: DS.gridRowMin),
      decoration: DS.gridBottomBorder,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: DS.labelColWidth, color: _labelBg, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: DS.spaceL),
              child: Text(label, style: const TextStyle(fontSize: DS.fontM, fontWeight: DS.weightSemi, color: DS.textLabel))),
            Container(width: 0.5, color: _gridColor),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _gridDoubleRow(String label1, TextEditingController ctrl1, String label2, TextEditingController ctrl2, {
    bool isNumber = false, bool isDecimal = false, String? prefix,
  }) {
    final keyboardType = isDecimal
        ? const TextInputType.numberWithOptions(decimal: true)
        : isNumber ? TextInputType.number : TextInputType.text;

    return Container(
      constraints: const BoxConstraints(minHeight: DS.gridRowMin),
      decoration: DS.gridBottomBorder,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: DS.dblLabelColWidth, color: _labelBg, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: DS.spaceL),
              child: Text(label1, style: DS.rowLabelStyle)),
            Container(width: 0.5, color: _gridColor),
            Expanded(child: _gridInput(ctrl1, keyboardType: keyboardType, prefix: prefix, textAlign: TextAlign.right)),
            Container(width: 0.5, color: _gridColor),
            Container(width: DS.dblLabelColWidth, color: _labelBg, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: DS.spaceL),
              child: Text(label2, style: DS.rowLabelStyle)),
            Container(width: 0.5, color: _gridColor),
            Expanded(child: _gridInput(ctrl2, keyboardType: keyboardType, prefix: prefix, textAlign: TextAlign.right)),
          ],
        ),
      ),
    );
  }

  Widget _gridInput(TextEditingController controller, {
    TextInputType? keyboardType, String? prefix, TextAlign textAlign = TextAlign.left, String? Function(String?)? validator,
  }) {
    return Container(
      color: _cellEditBg,
      child: TextFormField(
        controller: controller, keyboardType: keyboardType, textAlign: textAlign, validator: validator,
        style: DS.inputStyle,
        decoration: InputDecoration(
          prefixText: prefix,
          prefixStyle: DS.inputPrefixStyle,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: DS.spaceL, vertical: DS.spaceL),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildCompactImageCapture({
    required String label, required String imageBase64, required bool isProcessing,
    required VoidCallback onCapture, required VoidCallback onRemove,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: DS.textLabel, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: isProcessing ? null : onCapture,
          child: Container(
            height: 100,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: DS.surfaceSlate,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: imageBase64.isNotEmpty ? AppTheme.accentColor.withOpacity(0.5) : _gridColor,
                width: imageBase64.isNotEmpty ? 2 : 1,
              ),
            ),
            child: isProcessing
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(height: 4),
                    Text('Removing bg…', style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ]))
                : imageBase64.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Stack(fit: StackFit.expand, children: [
                          CustomPaint(painter: _CheckerboardPainter()),
                          Image.memory(base64Decode(imageBase64), fit: BoxFit.contain),
                          Positioned(top: 2, right: 2,
                            child: GestureDetector(onTap: onRemove,
                              child: Container(padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(color: Colors.red.withOpacity(0.85), shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 12, color: Colors.white)))),
                        ]))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_a_photo_outlined, size: 24, color: DS.textFaint),
                        SizedBox(height: 2),
                        Text('Tap to capture', style: TextStyle(fontSize: 9, color: DS.textFaint)),
                      ]),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════

  Future<void> _syncToShopify() async {
    final sku = _skuController.text.trim();
    final name = _nameController.text.trim();
    if (sku.isEmpty || name.isEmpty) return;

    setState(() => _isSyncingShopify = true);

    try {
      final result = await SyncService().syncProductToShopify(
        title: name,
        sku: sku,
        barcode: sku,
        price: _onlinePriceController.text.trim(), // Online price → Shopify
        vendor: widget.vendor.name,
        description: name,
        tags: _shopifyTags.join(', '),
        taxable: POSTaxCode.isTaxable(_posTaxCode),
        imageBase64: _frontImageBase64.isNotEmpty ? _frontImageBase64 : null,
      );

      if (mounted) {
        setState(() => _isSyncingShopify = false);
        if (result != null && result['success'] == true) {
          final action = result['action'] ?? 'synced';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ ${action == 'created' ? 'Created' : 'Updated'} on Shopify'),
              backgroundColor: DS.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
          _hydrateProduct(); // Refresh status
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Shopify sync failed: ${result?['error'] ?? 'Unknown error'}'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncingShopify = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _exportToPOS() async {
    final sku = _skuController.text.trim();
    final name = _nameController.text.trim();
    if (sku.isEmpty || name.isEmpty) return;

    setState(() => _isExportingPOS = true);

    try {
      final products = [
        {
          'sku': sku,
          'name': name,
          'price': _storePriceController.text.trim(), // Store price → POS
          'cost': _pcCostController.text.trim(),
          'department': _hubEngine?.deptCodeForName(_posDepartmentName) ?? '',
          'departmentName': _posDepartmentName,
          'vendor': widget.vendor.name,
          'taxCode': _posTaxCode,
          'reorderLevel': _minStockController.text.trim(),
          'reorderQty': _defaultOrderQtyController.text.trim(),
        },
      ];

      final csv = await SyncService().generatePosImport(products);

      if (mounted) {
        setState(() => _isExportingPOS = false);
        if (csv != null) {
          _showPosExportDialog(csv);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('POS export failed'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExportingPOS = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showPosExportDialog(String csv) {
    showDialog(
      context: context,
      builder: (ctx) => _PosExportDialog(newCodesContent: csv),
    );
  }

  Future<void> _captureImage({required bool isFront}) async {
    final useCamera = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Capture ${isFront ? "Front" : "Back"} Image', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), subtitle: const Text('Take a photo now'), onTap: () => Navigator.pop(ctx, true)),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Photo Library'), subtitle: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, false)),
          ]),
        ),
      ),
    );

    if (useCamera == null) return;

    try {
      final bytes = await pickImageWeb(useCamera: useCamera);
      if (bytes == null) return;

      // Compress immediately — resize to max 1024px, JPEG quality 75%
      String b64 = await compressImageToBase64(bytes, maxDimension: 1024, quality: 0.75);
      debugPrint('📸 Compressed image: ${(b64.length * 3 / 4 / 1024).round()} KB');

      setState(() {
        if (isFront) _frontImageBase64 = b64; else _backImageBase64 = b64;
      });

      if (_removeBgApiKey.isNotEmpty) {
        setState(() {
          if (isFront) _isRemovingBgFront = true; else _isRemovingBgBack = true;
        });

        final processedB64 = await _removeBackground(bytes);

        // Compress the bg-removed PNG → JPEG to keep it small
        String? compressedResult;
        if (processedB64 != null) {
          compressedResult = await compressBase64Image(processedB64, maxDimension: 1024, quality: 0.80);
          debugPrint('📸 BG-removed compressed: ${(compressedResult.length * 3 / 4 / 1024).round()} KB');
        }

        setState(() {
          if (isFront) {
            _isRemovingBgFront = false;
            if (compressedResult != null) _frontImageBase64 = compressedResult;
          } else {
            _isRemovingBgBack = false;
            if (compressedResult != null) _backImageBase64 = compressedResult;
          }
        });
      }

      // Image is kept locally in memory (base64).
      // It will be sent directly to Shopify when you tap "Create/Update on Shopify".
      if (isFront && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📷 Image captured — tap "Create/Update on Shopify" to upload'),
            backgroundColor: DS.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() { _isRemovingBgFront = false; _isRemovingBgBack = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<String?> _removeBackground(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('https://api.remove.bg/v1.0/removebg'));
      request.headers['X-Api-Key'] = _removeBgApiKey;
      request.fields['size'] = 'auto';
      request.files.add(http.MultipartFile.fromBytes('image_file', imageBytes, filename: 'product.jpg'));

      final streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        final responseBytes = await streamedResponse.stream.toBytes();
        return base64Encode(responseBytes);
      }
      return null;
    } catch (e) {
      debugPrint('remove.bg exception: $e');
      return null;
    }
  }

  void _scanBarcode() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const _BarcodeScannerScreen()),
    );
    if (scannedCode != null && scannedCode.isNotEmpty) {
      setState(() => _skuController.text = scannedCode);
      _hydrateProduct();
    }
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final productProvider = context.read<ProductProvider>();
    final sku = _skuController.text.trim();

    // Images are kept locally — no Firebase Storage upload needed.
    // They will be sent directly to Shopify when syncing.

    final updatedProduct = Product(
      id: widget.product.id,
      vendorId: widget.product.vendorId,
      name: _nameController.text.trim(),
      sku: sku,
      pcsPerCase: int.tryParse(_pcsPerCaseController.text) ?? 1,
      pcsPerLine: int.tryParse(_pcsPerLineController.text) ?? 1,
      storePrice: double.tryParse(_storePriceController.text) ?? 0,
      onlinePrice: double.tryParse(_onlinePriceController.text) ?? 0,
      storeCasePrice: double.tryParse(_storeCasePriceController.text) ?? 0,
      onlineCasePrice: double.tryParse(_onlineCasePriceController.text) ?? 0,
      pcCost: double.tryParse(_pcCostController.text) ?? 0,
      caseCost: double.tryParse(_caseCostController.text) ?? 0,
      posTaxCode: _posTaxCode,
      shopifyTaxable: POSTaxCode.isTaxable(_posTaxCode),
      posDepartment: _hubEngine?.deptCodeForName(_posDepartmentName) ?? '',
      posDepartmentName: _posDepartmentName,
      shopifyTags: _shopifyTags,
      shopifyCollection: widget.product.shopifyCollection,
      categoryConfirmed: _categoryConfirmed,
      shopifyImageUrl: widget.product.shopifyImageUrl,
      frontImageBase64: _frontImageBase64,
      backImageBase64: _backImageBase64,
      reorderRule: ReorderRule(
        minStockPcs: int.tryParse(_minStockController.text) ?? 0,
        defaultOrderQty: int.tryParse(_defaultOrderQtyController.text) ?? 0,
      ),
      sortOrder: widget.product.sortOrder,
      createdAt: widget.product.createdAt,
    );

    try {
      await productProvider.updateProduct(widget.store.id, widget.vendor.id, updatedProduct);

      if (context.mounted) {
        setState(() => _isSaving = false);
        final hasImage = _frontImageBase64.isNotEmpty;
        final msg = hasImage ? 'Product saved ✓ (image ready for Shopify sync)' : 'Product saved successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    }
  }

}

// ═══════════════════════════════════════════════════════════════
//  BARCODE SCANNER
// ═══════════════════════════════════════════════════════════════

class _BarcodeScannerScreen extends StatefulWidget {
  const _BarcodeScannerScreen();

  @override
  State<_BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<_BarcodeScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _hasScanned = false;
  String? _scannedValue;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
      setState(() { _hasScanned = true; _scannedValue = barcode.rawValue!; });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.pop(context, _scannedValue);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode / QR Code'),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _scannerController.toggleTorch(), tooltip: 'Toggle Flash'),
          IconButton(icon: const Icon(Icons.cameraswitch), onPressed: () => _scannerController.switchCamera(), tooltip: 'Switch Camera'),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _scannerController, onDetect: _onDetect),
          Center(child: Container(width: 280, height: 160, decoration: BoxDecoration(
            border: Border.all(color: _hasScanned ? AppTheme.accentColor : Colors.white, width: 3),
            borderRadius: BorderRadius.circular(16),
          ))),
          Positioned(bottom: 100, left: 0, right: 0,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
              child: Text(_hasScanned ? '✓ Scanned: $_scannedValue' : 'Point camera at barcode or QR code',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ))),
          Positioned(bottom: 30, left: 0, right: 0,
            child: Center(child: TextButton.icon(
              onPressed: () => _showManualEntryDialog(context),
              icon: const Icon(Icons.keyboard, color: Colors.white),
              label: const Text('Enter Manually', style: TextStyle(color: Colors.white, fontSize: 14)),
              style: TextButton.styleFrom(backgroundColor: Colors.black38, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            ))),
        ],
      ),
    );
  }

  void _showManualEntryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter SKU Manually'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'SKU / Barcode', prefixIcon: Icon(Icons.qr_code))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); if (controller.text.isNotEmpty) Navigator.pop(context, controller.text.trim()); },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  POS EXPORT DIALOG
// ═══════════════════════════════════════════════════════════════

class _PosExportDialog extends StatefulWidget {
  final String newCodesContent;
  const _PosExportDialog({required this.newCodesContent});

  @override
  State<_PosExportDialog> createState() => _PosExportDialogState();
}

class _PosExportDialogState extends State<_PosExportDialog> {
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
        setState(() { _isUploading = false; _uploaded = url != null; _downloadUrl = url; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(url != null ? '✓ updateproduct.PLU uploaded to cloud' : 'Upload failed — check connection'),
            backgroundColor: url != null ? DS.successColor : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('_uploadToCloud error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied'), backgroundColor: DS.successColor, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.point_of_sale, color: DS.successColor),
        SizedBox(width: 8),
        Expanded(child: Text('Penny Lane POS Import', style: TextStyle(fontSize: 15))),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NewCodes.txt content:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: DS.surfaceSlate, borderRadius: BorderRadius.circular(8), border: Border.all(color: DS.borderLight)),
              child: SingleChildScrollView(child: SelectableText(widget.newCodesContent, style: const TextStyle(fontSize: 10, fontFamily: 'monospace'))),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _copyToClipboard(widget.newCodesContent, 'NewCodes.txt'),
                icon: const Icon(Icons.copy, size: 16), label: const Text('Copy', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              )),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadToCloud,
                icon: _isUploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_uploaded ? Icons.cloud_done : Icons.cloud_upload, size: 16),
                label: Text(_isUploading ? 'Uploading…' : _uploaded ? 'Uploaded ✓' : 'Upload to Cloud', style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _uploaded ? DS.successColor : DS.accentBlue,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
            ]),
            if (_uploaded && _downloadUrl != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: DS.shopifyChipBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: DS.successBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.check_circle, color: DS.successColor, size: 18),
                    SizedBox(width: 6),
                    Text('Ready for POS pickup!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DS.successColor)),
                  ]),
                  const SizedBox(height: 8),
                  const Text('File uploaded to Firebase Storage. Windows POS will auto-download on next startup.',
                    style: TextStyle(fontSize: 11, color: DS.successDeep)),
                ]),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => _showScript = !_showScript),
                child: Row(children: [
                  Icon(_showScript ? Icons.expand_less : Icons.expand_more, size: 18, color: AppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Text(_showScript ? 'Hide Windows Script' : 'Show Windows Script',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ]),
              ),
              if (_showScript) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: DS.darkCodeBg, borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(child: SelectableText(
                    SyncService().generateWindowsBatchScript(downloadUrl: _downloadUrl),
                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: DS.textSubtitle),
                  )),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(SyncService().generateWindowsBatchScript(downloadUrl: _downloadUrl), 'Batch script'),
                    icon: const Icon(Icons.copy, size: 14), label: const Text('Copy .bat', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(SyncService().generatePowerShellScript(downloadUrl: _downloadUrl), 'PowerShell script'),
                    icon: const Icon(Icons.terminal, size: 14), label: const Text('Copy .ps1', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                  )),
                ]),
              ],
            ],
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHOPIFY TAG PICKER DIALOG
// ═══════════════════════════════════════════════════════════════

class _ShopifyTagPickerDialog extends StatefulWidget {
  final List<String> currentTags;
  final ValueChanged<List<String>> onTagsSelected;

  const _ShopifyTagPickerDialog({
    required this.currentTags,
    required this.onTagsSelected,
  });

  @override
  State<_ShopifyTagPickerDialog> createState() => _ShopifyTagPickerDialogState();
}

class _ShopifyTagPickerDialogState extends State<_ShopifyTagPickerDialog> {
  late Set<String> _selected;
  String _search = '';
  final _searchController = TextEditingController();
  String? _expandedCategory;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.currentTags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ShopifyMasterTags.tagsByCategory;
    final lowerSearch = _search.toLowerCase();

    return Dialog(
      backgroundColor: DS.tagPickerBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DS.tagPickerBorder, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sell, color: DS.shopifyColor, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Shopify Tags', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _selected.isEmpty ? DS.warningColor.withOpacity(0.2) : DS.successColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_selected.length} selected',
                          style: TextStyle(
                            color: _selected.isEmpty ? DS.warningColor : DS.successLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // ── Search ──
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: DS.tagPickerSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DS.tagPickerBorder),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search tags...',
                        hintStyle: TextStyle(color: DS.textMuted, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: DS.textMuted, size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                ],
              ),
            ),

            // ── Selected Tags (chips) ────────────────────
            if (_selected.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: const BoxDecoration(
                  color: DS.tagPickerSurface,
                  border: Border(bottom: BorderSide(color: DS.tagPickerBorder, width: 0.5)),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selected.map((tag) => Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 11, color: Colors.white)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    deleteIconColor: Colors.grey,
                    onDeleted: () => setState(() => _selected.remove(tag)),
                    backgroundColor: DS.tagPickerBorder,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ),

            // ── Top Tags (quick-select) ──────────────────
            if (_search.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⭐ Most Used', style: TextStyle(color: DS.textFaint, fontSize: 10, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ShopifyMasterTags.topTags.map((tag) {
                        final isOn = _selected.contains(tag);
                        return GestureDetector(
                          onTap: () => setState(() => isOn ? _selected.remove(tag) : _selected.add(tag)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOn ? DS.successColor : DS.tagPickerChipOff,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isOn ? DS.successLight : DS.tagPickerBorder),
                            ),
                            child: Text(tag, style: TextStyle(fontSize: 11, color: isOn ? Colors.white : DS.textFaint)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            const Divider(height: 1, color: DS.tagPickerBorder),

            // ── Category list ────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: _search.isNotEmpty
                    ? _buildSearchResults(lowerSearch)
                    : categories.entries.map((entry) => _buildCategoryTile(entry.key, entry.value)).toList(),
              ),
            ),

            // ── Footer ──────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: DS.tagPickerBorder, width: 1)),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    child: const Text('Clear All', style: TextStyle(color: DS.textFaint, fontSize: 12)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: DS.textFaint, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.onTagsSelected(_selected.toList()..sort());
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DS.shopifyColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Done (${_selected.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search results (flat list) ──

  List<Widget> _buildSearchResults(String query) {
    final matches = ShopifyMasterTags.allTags.where((t) => t.toLowerCase().contains(query)).toList();
    if (matches.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No matching tags', style: TextStyle(color: DS.textMuted, fontSize: 12))),
        ),
      ];
    }
    return matches.map((tag) {
      final isOn = _selected.contains(tag);
      return ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(tag, style: TextStyle(color: isOn ? DS.successLight : Colors.white, fontSize: 13)),
        trailing: Icon(
          isOn ? Icons.check_circle : Icons.circle_outlined,
          color: isOn ? DS.successLight : DS.textLabel,
          size: 20,
        ),
        onTap: () => setState(() => isOn ? _selected.remove(tag) : _selected.add(tag)),
      );
    }).toList();
  }

  // ── Category accordion tile ──

  Widget _buildCategoryTile(String category, List<String> tags) {
    final isExpanded = _expandedCategory == category;
    final selectedInCat = tags.where((t) => _selected.contains(t)).length;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expandedCategory = isExpanded ? null : category),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: DS.textMuted, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(color: DS.tagPickerTextDim, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${tags.length} tags',
                  style: const TextStyle(color: DS.textMuted, fontSize: 10),
                ),
                if (selectedInCat > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: DS.successColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$selectedInCat', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((tag) {
                final isOn = _selected.contains(tag);
                return GestureDetector(
                  onTap: () => setState(() => isOn ? _selected.remove(tag) : _selected.add(tag)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOn ? DS.successColor : DS.tagPickerChipOff,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isOn ? DS.successLight : DS.tagPickerBorder),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        color: isOn ? Colors.white : DS.tagPickerTextDim,
                        fontWeight: isOn ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        const Divider(height: 0.5, color: DS.tagPickerBorder, indent: 16, endIndent: 16),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  COMPARISON ROW DATA HELPER
// ═══════════════════════════════════════════════════════════════

class _CompRow {
  final String label;
  final String posValue;
  final String shopifyValue;
  /// When true, skip naive string comparison — values are semantically equal.
  final bool semanticMatch;
  _CompRow(this.label, this.posValue, this.shopifyValue, {this.semanticMatch = false});
}

// ═══════════════════════════════════════════════════════════════
//  CHECKERBOARD PAINTER
// ═══════════════════════════════════════════════════════════════

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 10.0;
    final lightPaint = Paint()..color = const Color(0xFFFFFFFF);
    final darkPaint = Paint()..color = const Color(0xFFE0E0E0);
    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isEven = ((x / cellSize).floor() + (y / cellSize).floor()) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, cellSize, cellSize), isEven ? lightPaint : darkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
