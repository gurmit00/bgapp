/// Role and permission definitions for the app.
/// Edit _rolePermissions below to change what each role can do.
///
/// ┌──────────────────────────┬──────────────────────────────────────────────────┬───────┬─────────┬───────┬─────────────────┐
/// │ Permission               │ What it controls                                 │ Admin │ Manager │ Staff │ Apniroots Staff │
/// ├──────────────────────────┼──────────────────────────────────────────────────┼───────┼─────────┼───────┼─────────────────┤
/// │ push_shopify             │ "Shopify" button on Product Hub screen           │  ✓    │         │       │       ✓         │
/// │ push_pos                 │ "POS" button on Product Hub screen               │  ✓    │         │       │                 │
/// │ import_data              │ Import Data screen (drawer menu)                 │  ✓    │         │       │                 │
/// │ export_data              │ Export Products / Export Orders CSV (drawer)     │  ✓    │         │       │                 │
/// │ manage_stores            │ Manage Stores screen (drawer menu)               │  ✓    │         │       │                 │
/// │ shopify_missing          │ "Missing from Shopify" screen (drawer menu)      │  ✓    │         │       │       ✓         │
/// │ manage_users             │ User Management card in Settings tab             │  ✓    │         │       │                 │
/// │ danger_zone              │ Destructive bulk ops (delete all vendors etc.)   │  ✓    │         │       │                 │
/// │ shopify_config           │ Edit Shopify / POS integration settings          │  ✓    │         │       │                 │
/// │ delete_order             │ Delete button on Orders screen                   │  ✓    │         │       │                 │
/// │ delete_vendor            │ Delete vendor button on Store Detail screen      │  ✓    │         │       │                 │
/// │ delete_product           │ Delete (×) product button on Vendor Detail       │  ✓    │         │       │                 │
/// │ edit_product             │ Save button on Product Hub (edit product fields) │  ✓    │         │       │       ✓         │
/// │ export_ubereats          │ Export UberEats CSV (Online Platforms menu)      │  ✓    │         │       │                 │
/// │ uber_markup              │ Uber Markup settings screen (Online Platforms)   │  ✓    │         │       │                 │
/// │ export_instacart         │ Export Instacart CSV (Online Platforms menu)     │  ✓    │         │       │                 │
/// │ instacart_markup         │ Instacart Markup settings screen                 │  ✓    │         │       │                 │
/// ├──────────────────────────┼──────────────────────────────────────────────────┼───────┼─────────┼───────┼─────────────────┤
/// │ — not yet wired —        │ Add permission constant + hasPermission() check  │       │         │       │                 │
/// │ create_order             │ "New Order" button on Orders screen              │       │         │       │                 │
/// │ submit_order             │ "Submit Order" button on Order Creation screen   │       │         │       │                 │
/// │ add_product              │ "Add Product" button on Vendor Detail screen     │       │         │       │                 │
/// │ add_vendor               │ "Add Vendor" button on Store Detail screen       │       │         │       │                 │
/// │ view_products_tab        │ Products tab in main menu                        │       │         │       │                 │
/// │ view_stores_tab          │ Stores tab in main menu                          │       │         │       │                 │
/// └──────────────────────────┴──────────────────────────────────────────────────┴───────┴─────────┴───────┴─────────────────┘
class AppRoles {
  // ── Role names ──────────────────────────────────────────────
  static const String admin          = 'admin';
  static const String manager        = 'manager';
  static const String staff          = 'staff';
  static const String apnirootsStaff = 'apniroots_staff'; // Apniroots team: push_shopify, shopify_missing, edit_product
  static const String pending        = 'pending';         // new user awaiting admin approval

  static const List<String> all        = [admin, manager, staff, apnirootsStaff];
  static const List<String> assignable = [admin, manager, staff, apnirootsStaff, pending];

  // ── Permission constants ─────────────────────────────────────
  static const String pushShopify    = 'push_shopify';
  static const String pushPos        = 'push_pos';
  static const String importData     = 'import_data';
  static const String exportData     = 'export_data';      // Export Products + Export Orders
  static const String manageStores   = 'manage_stores';
  static const String shopifyMissing = 'shopify_missing';
  static const String manageUsers    = 'manage_users';
  static const String shopifyConfig  = 'shopify_config';
  static const String dangerZone     = 'danger_zone';
  static const String deleteVendor   = 'delete_vendor';
  static const String deleteOrder    = 'delete_order';
  static const String deleteProduct  = 'delete_product';
  static const String editProduct    = 'edit_product';
  static const String exportUberEats    = 'export_ubereats';   // Export UberEats CSV
  static const String uberMarkup        = 'uber_markup';        // Uber Markup settings screen
  static const String exportInstacart   = 'export_instacart';  // Export Instacart CSV
  static const String instacartMarkup   = 'instacart_markup';  // Instacart Markup settings screen

  // ── Role → permissions map ───────────────────────────────────
  static const Map<String, List<String>> _rolePermissions = {
    admin: [
      pushShopify,    // "Shopify" button on Product Hub
      pushPos,        // "POS" button on Product Hub
      importData,     // Import Data screen
      exportData,     // Export Products / Export Orders CSV
      manageStores,   // Manage Stores screen
      shopifyMissing, // Missing from Shopify screen
      manageUsers,    // User Management in Settings
      shopifyConfig,  // Shopify / POS integration settings
      dangerZone,     // Destructive bulk ops
      deleteOrder,    // Delete button on Orders screen
      deleteVendor,   // Delete vendor on Store Detail screen
      deleteProduct,  // Delete product on Vendor Detail screen
      editProduct,    // Save button on Product Hub
      exportUberEats,  // Export UberEats CSV
      uberMarkup,      // Uber Markup settings screen
      exportInstacart, // Export Instacart CSV
      instacartMarkup, // Instacart Markup settings screen
    ],
    manager:        [],
    staff:          [],
    apnirootsStaff: [
      pushShopify,    // "Shopify" button on Product Hub
      shopifyMissing, // Missing from Shopify screen
      editProduct,    // Save button on Product Hub
    ],
  };

  static bool hasPermission(String role, String permission) {
    return _rolePermissions[role]?.contains(permission) ?? false;
  }

  static String label(String role) {
    switch (role) {
      case admin:          return 'Admin';
      case manager:        return 'Manager';
      case staff:          return 'Staff';
      case apnirootsStaff: return 'Apniroots Staff';
      case pending:        return 'Pending';
      default:             return 'Pending';
    }
  }
}
