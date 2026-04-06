// Models for the NewStore Ordering App
// Updated with Product Hub architecture:
//   - Split pricing (store vs online)
//   - POS tax codes (1=taxable, 4=non-taxable)
//   - Category mapping (POS dept ↔ Shopify tags)
//   - Label Queue system

/// Represents a product row from PLU.csv with the key fields
class PLUProduct {
  String pluNum;
  String desc;
  String deptName;
  String deptCode;
  String price;
  String cost;
  String taxCode;
  String vendName;

  PLUProduct({
    required this.pluNum,
    required this.desc,
    required this.deptName,
    this.deptCode = '',
    required this.price,
    required this.cost,
    required this.taxCode,
    required this.vendName,
  });

  /// Create from a CSV row map (header → value)
  factory PLUProduct.fromCsvRow(Map<String, String> row) {
    return PLUProduct(
      pluNum: (row['PLU_NUM'] ?? '').trim(),
      desc: (row['DESC'] ?? '').trim(),
      deptName: (row['DEPTNAME'] ?? '').trim(),
      deptCode: (row['DEPT'] ?? '').trim(),
      price: (row['PRICE'] ?? '').trim(),
      cost: (row['COST'] ?? '').trim(),
      taxCode: (row['TAX_CODE'] ?? '').trim(),
      vendName: (row['VENDNAME'] ?? '').trim(),
    );
  }

  /// Is this product taxable? POS code 1 = taxable, 4 = non-taxable
  bool get isTaxable => taxCode == '1';

  /// Human-readable tax status
  String get taxLabel => isTaxable ? 'Taxable (1)' : 'Non-Taxable (4)';

  /// CSV header for PLU_new.csv
  static String csvHeader() {
    return 'PLU_NUM,DESC,DEPTNAME,PRICE,COST,TAX_CODE,VENDNAME';
  }

  /// CSV row
  String toCsvRow() {
    return [
      _esc(pluNum),
      _esc(desc),
      _esc(deptName),
      _esc(price),
      _esc(cost),
      _esc(taxCode),
      _esc(vendName),
    ].join(',');
  }

  static String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  PLUProduct copy() {
    return PLUProduct(
      pluNum: pluNum,
      desc: desc,
      deptName: deptName,
      deptCode: deptCode,
      price: price,
      cost: cost,
      taxCode: taxCode,
      vendName: vendName,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  POS TAX CODES — Penny Lane POS system
// ═══════════════════════════════════════════════════════════════

/// POS Tax Code constants — Penny Lane uses numeric codes
class POSTaxCode {
  static const String taxable = '1';
  static const String nonTaxable = '4';

  static bool isTaxable(String code) => code == taxable;

  static String label(String code) {
    switch (code) {
      case '1': return 'Taxable';
      case '4': return 'Non-Taxable';
      default: return 'Unknown ($code)';
    }
  }

  static const List<String> allCodes = ['1', '4'];
  static const Map<String, String> labels = {
    '1': 'Taxable (1)',
    '4': 'Non-Taxable (4)',
  };
}

// ═══════════════════════════════════════════════════════════════
//  SHOPIFY MASTER TAGS — extracted from shopify_all_existing_products.csv
//  Tags drive Shopify collections. Products MUST have at least one tag.
// ═══════════════════════════════════════════════════════════════

class ShopifyMasterTags {
  /// All known Shopify tags sorted by frequency (most used first).
  /// Source: 11,879 products from shopify_all_existing_products.csv
  static const List<String> allTags = [
    // ── Food & Snacks ──
    'Namkeen',
    'Biscuit & Cookies',
    'Chips',
    'South Indian Snacks',
    'Rusk & Cake',
    'Papad',
    'Khakhra',
    'Chikki and Gachak',
    'Golgappa',
    'Bhakri',
    // ── Spices & Masala ──
    'Masala Boxed',
    'Masala Powder',
    'Masala Powder - special',
    'Cooking Paste',
    // ── Ready to Eat / Frozen ──
    'Frozen Ready to Eat',
    'Frozen Vegetables',
    'Paratha & Roti',
    'Naan',
    'Ready To Eat - North Indian',
    'Ready To Eat - South Indian',
    'Instant Mixes',
    // ── Grains & Staples ──
    'Flour',
    'Atta',
    'Rice',
    'Dal & Lentils',
    'Poha & Mumra',
    'Vermicelli',
    'Noodles & Pasta',
    // ── Beverages ──
    'Juice & Soft Drink',
    'Tea & Coffee',
    'Dairy',
    'Yogurt Dahi',
    // ── Condiments ──
    'Pickle',
    'Chutney & Sauces',
    'Jam',
    'Vinegar',
    // ── Cooking ──
    'Cooking Oil',
    'Desi Ghee',
    'Jaggery',
    'Salt Sugar',
    'Canned Foods',
    'Fried Onion',
    'Baking Powder',
    'Food Colour & Essence',
    // ── Dry Fruits & Sweets ──
    'Dry Fruits & Candy',
    'Sweets',
    // ── Fresh ──
    'Vegetables',
    'Fruits',
    'Bread',
    'Paneer & Khoya',
    'Eggs',
    // ── Health & Beauty ──
    'Beauty - Body Care',
    'Beauty - Hair Care',
    'Health Care',
    'Baby Care',
    // ── Household & Religious ──
    'Households',
    'Cookware',
    'Incense',
    'Pooja Item',
    'Utensils',
    // ── Organic ──
    'Organic Dal & Lentils',
    'Organic Spices',
    'Organic Flour',
    'Organic Rice',
    'Organic Tea',
    'Organic Masala & Spices',
    'Organic Ayurveda',
    'Himalayan Salt',
    // ── Seasonal / Promo ──
    'Diwali',
    'Holi',
    'Lohri',
    'Rakhsha Bandhan',
    // ── Special ──
    "'-- Sale --",
    'Take Away',
    'Regional Goan',
  ];

  /// Top tags — the most commonly used ones shown first in the picker
  static const List<String> topTags = [
    'Namkeen',
    'Masala Boxed',
    'Frozen Ready to Eat',
    'Masala Powder',
    'Biscuit & Cookies',
    'Juice & Soft Drink',
    'Dry Fruits & Candy',
    'Flour',
    'Beauty - Body Care',
    'Pickle',
    'Instant Mixes',
    'Paratha & Roti',
    'Beauty - Hair Care',
    'Chutney & Sauces',
    'Dal & Lentils',
    'Tea & Coffee',
    'Cooking Oil',
    'Frozen Vegetables',
    'Cookware',
    'Cooking Paste',
    'Households',
    'Health Care',
    'Rice',
    'Chips',
  ];

  /// Tag categories for organized display
  static const Map<String, List<String>> tagsByCategory = {
    '🍿 Snacks': ['Namkeen', 'Biscuit & Cookies', 'Chips', 'South Indian Snacks', 'Rusk & Cake', 'Papad', 'Khakhra', 'Chikki and Gachak', 'Golgappa'],
    '🌶️ Spices': ['Masala Boxed', 'Masala Powder', 'Masala Powder - special', 'Cooking Paste'],
    '🧊 Frozen': ['Frozen Ready to Eat', 'Frozen Vegetables', 'Paratha & Roti', 'Naan', 'Ready To Eat - North Indian', 'Ready To Eat - South Indian', 'Instant Mixes'],
    '🌾 Staples': ['Flour', 'Atta', 'Rice', 'Dal & Lentils', 'Poha & Mumra', 'Vermicelli', 'Noodles & Pasta'],
    '🥤 Beverages': ['Juice & Soft Drink', 'Tea & Coffee', 'Dairy', 'Yogurt Dahi'],
    '🫙 Condiments': ['Pickle', 'Chutney & Sauces', 'Jam', 'Vinegar', 'Canned Foods'],
    '🫒 Cooking': ['Cooking Oil', 'Desi Ghee', 'Jaggery', 'Salt Sugar', 'Fried Onion', 'Baking Powder', 'Food Colour & Essence'],
    '🍬 Sweets': ['Dry Fruits & Candy', 'Sweets'],
    '🥬 Fresh': ['Vegetables', 'Fruits', 'Bread', 'Paneer & Khoya', 'Eggs'],
    '💄 Beauty/Health': ['Beauty - Body Care', 'Beauty - Hair Care', 'Health Care', 'Baby Care'],
    '🏠 Household': ['Households', 'Cookware', 'Incense', 'Pooja Item', 'Utensils'],
    '🌿 Organic': ['Organic Dal & Lentils', 'Organic Spices', 'Organic Flour', 'Organic Rice', 'Organic Tea', 'Organic Masala & Spices', 'Organic Ayurveda', 'Himalayan Salt'],
    '🎉 Seasonal': ['Diwali', 'Holi', 'Lohri', 'Rakhsha Bandhan'],
    '⚙️ Special': ["'-- Sale --", 'Take Away', 'Regional Goan'],
  };
}

// ═══════════════════════════════════════════════════════════════
//  PRODUCT HUB STATUS — hydration results from all systems
// ═══════════════════════════════════════════════════════════════

/// Represents the hydrated state of a product across all systems
class ProductHubStatus {
  // PLU (POS) data
  final bool pluChecked;
  final bool inPlu;
  final PLUProduct? pluProduct;

  // Shopify data
  final bool shopifyChecked;
  final bool inShopify;
  final Map<String, dynamic>? shopifyProduct;

  // Conflict detection
  final List<ProductConflict> conflicts;

  ProductHubStatus({
    this.pluChecked = false,
    this.inPlu = false,
    this.pluProduct,
    this.shopifyChecked = false,
    this.inShopify = false,
    this.shopifyProduct,
    this.conflicts = const [],
  });

  bool get isFullyChecked => pluChecked && shopifyChecked;
  bool get hasConflicts => conflicts.isNotEmpty;
  bool get existsEverywhere => inPlu && inShopify;
  bool get missingAnywhere => !inPlu || !inShopify;

  /// Shopify CDN image URL (source of truth for images)
  String get shopifyImageUrl =>
      (inShopify && shopifyProduct != null)
          ? (shopifyProduct!['image'] as String? ?? '')
          : '';

  /// Shopify public product page URL
  String get shopifyPublicUrl =>
      (inShopify && shopifyProduct != null)
          ? (shopifyProduct!['publicUrl'] as String? ?? '')
          : '';
}

/// A detected conflict between systems
class ProductConflict {
  final String field;         // e.g. 'tax', 'price', 'category'
  final String severity;      // 'critical', 'warning', 'info'
  final String posValue;
  final String shopifyValue;
  final String firebaseValue;
  final String message;

  ProductConflict({
    required this.field,
    required this.severity,
    this.posValue = '',
    this.shopifyValue = '',
    this.firebaseValue = '',
    required this.message,
  });

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';
}

// ═══════════════════════════════════════════════════════════════
//  LABEL QUEUE — track shelf labels that need printing
// ═══════════════════════════════════════════════════════════════

/// Status of a label queue item
enum LabelStatus { pending, printed, cancelled }

/// A shelf label that needs to be printed via POS
class LabelQueueItem {
  final String id;
  final String sku;
  final String productName;
  final String reason;        // 'missing', 'wrong_price', 'new_product', 'damaged'
  final double correctPrice;
  final String storeId;
  final LabelStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  LabelQueueItem({
    required this.id,
    required this.sku,
    required this.productName,
    required this.reason,
    required this.correctPrice,
    required this.storeId,
    this.status = LabelStatus.pending,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sku': sku,
      'productName': productName,
      'reason': reason,
      'correctPrice': correctPrice,
      'storeId': storeId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory LabelQueueItem.fromMap(Map<String, dynamic> map) {
    return LabelQueueItem(
      id: map['id'] ?? '',
      sku: (map['sku'] ?? '').toString(),
      productName: map['productName'] ?? '',
      reason: map['reason'] ?? 'missing',
      correctPrice: (map['correctPrice'] ?? 0).toDouble(),
      storeId: map['storeId'] ?? '',
      status: LabelStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => LabelStatus.pending,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
    );
  }

  LabelQueueItem copyWith({LabelStatus? status, DateTime? completedAt}) {
    return LabelQueueItem(
      id: id,
      sku: sku,
      productName: productName,
      reason: reason,
      correctPrice: correctPrice,
      storeId: storeId,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get reasonLabel {
    switch (reason) {
      case 'missing': return '🏷️ Missing Label';
      case 'wrong_price': return '💲 Wrong Price';
      case 'new_product': return '🆕 New Product';
      case 'damaged': return '🔧 Damaged Label';
      default: return reason;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  CATEGORY MAPPING — POS Dept ↔ Shopify Tags/Collections
// ═══════════════════════════════════════════════════════════════

/// Maps a POS department to Shopify tags/collections and vice versa
class CategoryMapping {
  final String posDeptCode;
  final String posDeptName;
  final List<String> shopifyTags;
  final String? shopifyCollection;
  final bool confirmed;       // user has confirmed this mapping

  CategoryMapping({
    required this.posDeptCode,
    required this.posDeptName,
    this.shopifyTags = const [],
    this.shopifyCollection,
    this.confirmed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'posDeptCode': posDeptCode,
      'posDeptName': posDeptName,
      'shopifyTags': shopifyTags,
      'shopifyCollection': shopifyCollection,
      'confirmed': confirmed,
    };
  }

  factory CategoryMapping.fromMap(Map<String, dynamic> map) {
    return CategoryMapping(
      posDeptCode: map['posDeptCode'] ?? '',
      posDeptName: map['posDeptName'] ?? '',
      shopifyTags: List<String>.from(map['shopifyTags'] ?? []),
      shopifyCollection: map['shopifyCollection'],
      confirmed: map['confirmed'] ?? false,
    );
  }
}

class Store {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String pluCsvUrl;
  final DateTime? pluUploadedAt;
  final DateTime createdAt;

  Store({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.pluCsvUrl = '',
    this.pluUploadedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasPlu => pluCsvUrl.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'pluCsvUrl': pluCsvUrl,
      if (pluUploadedAt != null) 'pluUploadedAt': pluUploadedAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      pluCsvUrl: map['pluCsvUrl'] ?? '',
      pluUploadedAt: map['pluUploadedAt'] != null
          ? DateTime.parse(map['pluUploadedAt'])
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}

class Vendor {
  final String id;
  final String name;
  final String whatsappPhoneNumber;
  final DateTime createdAt;

  Vendor({
    required this.id,
    required this.name,
    required this.whatsappPhoneNumber,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'whatsappPhoneNumber': whatsappPhoneNumber,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Vendor.fromMap(Map<String, dynamic> map) {
    return Vendor(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      whatsappPhoneNumber: map['whatsappPhoneNumber'] ?? '',
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
    );
  }
}class ReorderRule {
  final int minStockPcs;
  final int defaultOrderQty;

  ReorderRule({
    required this.minStockPcs,
    required this.defaultOrderQty,
  });

  Map<String, dynamic> toMap() {
    return {
      'minStockPcs': minStockPcs,
      'defaultOrderQty': defaultOrderQty,
    };
  }

  factory ReorderRule.fromMap(Map<String, dynamic> map) {
    return ReorderRule(
      minStockPcs: map['minStockPcs'] ?? 0,
      defaultOrderQty: map['defaultOrderQty'] ?? 0,
    );
  }
}

class Product {
  final String id;
  final String vendorId;
  final String name;
  /// The product name as it appears in the order list. Set once when the product
  /// is first created and never overwritten by SKU scans or PLU lookups.
  final String orderListProductName;
  final String sku;
  final int pcsPerCase;
  final int pcsPerLine;

  // ── Split Pricing ──
  // Firebase is master for prices; pushed to respective systems
  final double storePrice;      // → pushed to POS (Penny Lane)
  final double onlinePrice;     // → pushed to Shopify
  final double storeCasePrice;  // store case price
  final double onlineCasePrice; // online case price (if different)
  final double pcCost;          // cost per piece (same everywhere)
  final double caseCost;        // cost per case (same everywhere)

  // ── Legacy single-price support (maps to storePrice) ──
  double get pcPrice => storePrice;
  double get casePrice => storeCasePrice;

  // ── Tax (POS is master) ──
  final String posTaxCode;          // '1' = taxable, '4' = non-taxable
  final bool shopifyTaxable;        // Shopify tax setting

  // ── Categories (confirm, don't auto-sync) ──
  final String posDepartment;       // POS department code
  final String posDepartmentName;   // POS department name (human readable)
  final List<String> shopifyTags;   // Shopify tags
  final String shopifyCollection;   // Shopify collection
  final bool categoryConfirmed;     // User confirmed the mapping

  // ── Image (Shopify CDN is source of truth) ──
  final String shopifyImageUrl;     // Shopify CDN URL (source of truth)
  final String frontImageBase64;    // local capture (temp, for upload to Shopify)
  final String backImageBase64;     // back of package (reference only)

  // ── Reorder & ordering ──
  final ReorderRule reorderRule;
  final int sortOrder;

  final DateTime createdAt;

  Product({
    required this.id,
    required this.vendorId,
    required this.name,
    this.orderListProductName = '',
    required this.sku,
    required this.pcsPerCase,
    required this.pcsPerLine,
    this.storePrice = 0,
    this.onlinePrice = 0,
    this.storeCasePrice = 0,
    this.onlineCasePrice = 0,
    this.pcCost = 0,
    this.caseCost = 0,
    this.posTaxCode = '1',
    this.shopifyTaxable = true,
    this.posDepartment = '',
    this.posDepartmentName = '',
    this.shopifyTags = const [],
    this.shopifyCollection = '',
    this.categoryConfirmed = false,
    this.shopifyImageUrl = '',
    this.frontImageBase64 = '',
    this.backImageBase64 = '',
    required this.reorderRule,
    this.sortOrder = 0,
    required this.createdAt,
  });

  /// Is this product taxable per POS master?
  bool get isTaxable => POSTaxCode.isTaxable(posTaxCode);

  /// Do POS and Shopify tax settings agree?
  bool get taxInSync => isTaxable == shopifyTaxable;

  /// Are store and online prices different? (intentional)
  bool get hasSplitPricing => storePrice != onlinePrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'name': name,
      'orderListProductName': orderListProductName.isNotEmpty ? orderListProductName : name,
      'sku': sku,
      'pcsPerCase': pcsPerCase,
      'pcsPerLine': pcsPerLine,
      'storePrice': storePrice,
      'onlinePrice': onlinePrice,
      'storeCasePrice': storeCasePrice,
      'onlineCasePrice': onlineCasePrice,
      'pcCost': pcCost,
      'caseCost': caseCost,
      'posTaxCode': posTaxCode,
      'shopifyTaxable': shopifyTaxable,
      'posDepartment': posDepartment,
      'posDepartmentName': posDepartmentName,
      'shopifyTags': shopifyTags,
      'shopifyCollection': shopifyCollection,
      'categoryConfirmed': categoryConfirmed,
      'shopifyImageUrl': shopifyImageUrl,
      // NOTE: frontImageBase64 and backImageBase64 are NOT stored in Firestore
      // (too large — would exceed the 1MB document limit).
      // Images are uploaded to Firebase Storage instead.
      'reorderRule': reorderRule.toMap(),
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      // Legacy compat
      'pcPrice': storePrice,
      'casePrice': storeCasePrice,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    // Support legacy single-price data
    final storePrice = (map['storePrice'] ?? map['pcPrice'] ?? 0).toDouble();
    final onlinePrice = (map['onlinePrice'] ?? map['pcPrice'] ?? 0).toDouble();
    final storeCasePrice = (map['storeCasePrice'] ?? map['casePrice'] ?? 0).toDouble();
    final onlineCasePrice = (map['onlineCasePrice'] ?? map['casePrice'] ?? 0).toDouble();

    return Product(
      id: map['id'] ?? '',
      vendorId: map['vendorId'] ?? '',
      name: map['name'] ?? '',
      orderListProductName: (map['orderListProductName'] as String?)?.isNotEmpty == true
          ? map['orderListProductName']
          : map['name'] ?? '',
      sku: (map['sku'] ?? '').toString(),
      pcsPerCase: map['pcsPerCase'] ?? 0,
      pcsPerLine: map['pcsPerLine'] ?? 0,
      storePrice: storePrice,
      onlinePrice: onlinePrice,
      storeCasePrice: storeCasePrice,
      onlineCasePrice: onlineCasePrice,
      pcCost: (map['pcCost'] ?? 0).toDouble(),
      caseCost: (map['caseCost'] ?? 0).toDouble(),
      posTaxCode: map['posTaxCode'] ?? '1',
      shopifyTaxable: map['shopifyTaxable'] ?? true,
      posDepartment: map['posDepartment'] ?? '',
      posDepartmentName: map['posDepartmentName'] ?? '',
      shopifyTags: List<String>.from(map['shopifyTags'] ?? []),
      shopifyCollection: map['shopifyCollection'] ?? '',
      categoryConfirmed: map['categoryConfirmed'] ?? false,
      shopifyImageUrl: map['shopifyImageUrl'] ?? '',
      frontImageBase64: map['frontImageBase64'] ?? '',
      backImageBase64: map['backImageBase64'] ?? '',
      reorderRule: map['reorderRule'] != null
          ? ReorderRule.fromMap(map['reorderRule'])
          : ReorderRule(minStockPcs: 0, defaultOrderQty: 0),
      sortOrder: map['sortOrder'] ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}

class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final int onHandQtyPcs;
  final int orderQtyCases;
  final DateTime createdAt;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.onHandQtyPcs,
    required this.orderQtyCases,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'onHandQtyPcs': onHandQtyPcs,
      'orderQtyCases': orderQtyCases,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      onHandQtyPcs: map['onHandQtyPcs'] ?? 0,
      orderQtyCases: map['orderQtyCases'] ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}

class Order {
  final String id;
  final String storeId;
  final String vendorId;
  final DateTime orderDate;
  final List<OrderItem> items;
  final String status; // draft, submitted, completed
  final DateTime createdAt;

  Order({
    required this.id,
    required this.storeId,
    required this.vendorId,
    required this.orderDate,
    required this.items,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'vendorId': vendorId,
      'orderDate': orderDate.toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] ?? '',
      storeId: map['storeId'] ?? '',
      vendorId: map['vendorId'] ?? '',
      orderDate: map['orderDate'] != null
          ? DateTime.parse(map['orderDate'])
          : DateTime.now(),
      items: map['items'] != null
          ? List<OrderItem>.from(
              (map['items'] as List).map((item) => OrderItem.fromMap(item)))
          : [],
      status: map['status'] ?? 'draft',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}

class User {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CROSS-STORE PRODUCT — aggregated product view across stores
// ═══════════════════════════════════════════════════════════════

/// A product grouped by SKU across multiple stores.
class CrossStoreProduct {
  final String sku;
  final String name;
  final Map<String, StoreProductRef> storeRefs; // storeId → ref

  CrossStoreProduct({
    required this.sku,
    required this.name,
    required this.storeRefs,
  });

  int get storeCount => storeRefs.length;
  List<String> get storeIds => storeRefs.keys.toList();
  List<StoreProductRef> get refs => storeRefs.values.toList();
}

/// Reference to a specific product instance in a store/vendor.
class StoreProductRef {
  final String storeId;
  final String storeName;
  final String vendorId;
  final String vendorName;
  final String productId;
  final Product product;

  StoreProductRef({
    required this.storeId,
    required this.storeName,
    required this.vendorId,
    required this.vendorName,
    required this.productId,
    required this.product,
  });
}

// ═══════════════════════════════════════════════════════════════
//  MULTI-STORE HUB STATUS — hydration across N stores + Shopify
// ═══════════════════════════════════════════════════════════════

/// PLU lookup result for a single store.
class StorePLUResult {
  final String storeId;
  final String storeName;
  final bool checked;
  final bool found;
  final PLUProduct? pluProduct;

  StorePLUResult({
    required this.storeId,
    required this.storeName,
    this.checked = false,
    this.found = false,
    this.pluProduct,
  });
}

/// Hydration result for a product across multiple stores + Shopify.
class MultiStoreHubStatus {
  final Map<String, StorePLUResult> storeResults; // storeId → PLU result
  final bool shopifyChecked;
  final bool inShopify;
  final Map<String, dynamic>? shopifyProduct;
  final List<ProductConflict> conflicts;

  MultiStoreHubStatus({
    this.storeResults = const {},
    this.shopifyChecked = false,
    this.inShopify = false,
    this.shopifyProduct,
    this.conflicts = const [],
  });

  factory MultiStoreHubStatus.empty() => MultiStoreHubStatus();

  bool get isFullyChecked =>
      storeResults.values.every((r) => r.checked) && shopifyChecked;
  bool get hasConflicts => conflicts.isNotEmpty;

  String get shopifyImageUrl =>
      (inShopify && shopifyProduct != null)
          ? (shopifyProduct!['image'] as String? ?? '')
          : '';

  String get shopifyPublicUrl =>
      (inShopify && shopifyProduct != null)
          ? (shopifyProduct!['publicUrl'] as String? ?? '')
          : '';
}
