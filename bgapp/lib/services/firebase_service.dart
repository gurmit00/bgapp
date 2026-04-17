import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:newstore_ordering_app/models/models.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  late final FirebaseFirestore _firestore;
  late final auth.FirebaseAuth _firebaseAuth;

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal() {
    _firestore = FirebaseFirestore.instance;
    _firebaseAuth = auth.FirebaseAuth.instance;
  }

  // Auth Methods
  Future<User?> signInAnonymously() async {
    try {
      final result = await _firebaseAuth.signInAnonymously();
      if (result.user != null) {
        return User(
          id: result.user!.uid,
          email: result.user!.email ?? 'guest@example.com',
          displayName: result.user!.displayName ?? 'Guest User',
        );
      }
    } catch (e) {
      print('Error signing in: $e');
    }
    return null;
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Raw Firebase auth stream — used by AuthProvider to load role after sign-in.
  Stream<auth.User?> get rawAuthStateChanges => _firebaseAuth.authStateChanges();

  Stream<User?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) return null;
      return User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? 'guest@example.com',
        displayName: firebaseUser.displayName ?? 'Guest User',
      );
    });
  }

  /// Google Sign-In via popup (web).
  Future<User?> signInWithGoogle() async {
    try {
      final provider = auth.GoogleAuthProvider();
      final result = await _firebaseAuth.signInWithPopup(provider);
      if (result.user != null) {
        final u = result.user!;
        await upsertUserDoc(u.uid, u.email ?? '', u.displayName ?? u.email ?? '');
        return User(id: u.uid, email: u.email ?? '', displayName: u.displayName ?? '');
      }
    } catch (e) {
      print('Google sign-in error: $e');
      rethrow;
    }
    return null;
  }

  /// Email + password sign-in.
  Future<User?> signInWithEmailPassword(String email, String password) async {
    final result = await _firebaseAuth.signInWithEmailAndPassword(
      email: email, password: password,
    );
    if (result.user != null) {
      final u = result.user!;
      await upsertUserDoc(u.uid, u.email ?? '', u.displayName ?? u.email ?? '');
      return User(id: u.uid, email: u.email ?? '', displayName: u.displayName ?? '');
    }
    return null;
  }

  // ── User role management ─────────────────────────────────────

  /// Creates a user doc with default role 'staff' if it doesn't exist.
  Future<void> upsertUserDoc(String uid, String email, String displayName) async {
    final doc = _firestore.collection('users').doc(uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });
    } else {
      await doc.update({'email': email, 'displayName': displayName});
    }
  }

  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) return doc.data()?['role'] as String?;
    } catch (e) {
      print('Error getting user role: $e');
    }
    return null;
  }

  Future<void> setUserRole(String uid, String role) async {
    await _firestore.collection('users').doc(uid).update({'role': role});
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snap = await _firestore.collection('users').get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  // Store Methods
  Future<List<Store>> getStores() async {
    try {
      final snapshot = await _firestore.collection('stores').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Store.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error fetching stores: $e');
      return [];
    }
  }

  Future<void> addStore(Store store) async {
    try {
      await _firestore.collection('stores').doc(store.id).set(store.toMap());
    } catch (e) {
      print('Error adding store: $e');
    }
  }

  Future<void> updateStore(Store store) async {
    try {
      await _firestore.collection('stores').doc(store.id).update(store.toMap());
    } catch (e) {
      print('Error updating store: $e');
    }
  }

  Future<void> deleteStore(String storeId) async {
    try {
      await _firestore.collection('stores').doc(storeId).delete();
    } catch (e) {
      print('Error deleting store: $e');
      rethrow;
    }
  }

  // Vendor Methods (store-scoped: stores/{storeId}/vendors/{vendorId})

  Future<List<Vendor>> getVendors(String storeId) async {
    try {
      final snapshot = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('vendors')
          .orderBy('name')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Vendor.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error fetching vendors for store $storeId: $e');
      return [];
    }
  }

  Future<void> addVendor(String storeId, Vendor vendor) async {
    try {
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('vendors')
          .doc(vendor.id)
          .set(vendor.toMap());
    } catch (e) {
      print('Error adding vendor: $e');
    }
  }

  Future<void> updateVendor(String storeId, Vendor vendor) async {
    try {
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('vendors')
          .doc(vendor.id)
          .update(vendor.toMap());
    } catch (e) {
      print('Error updating vendor: $e');
    }
  }

  Future<void> deleteVendor(String storeId, String vendorId) async {
    try {
      // Delete all products under this vendor first
      final products = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('vendors')
          .doc(vendorId)
          .collection('products')
          .get();
      for (final doc in products.docs) {
        await doc.reference.delete();
      }
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('vendors')
          .doc(vendorId)
          .delete();
    } catch (e) {
      print('Error deleting vendor: $e');
      rethrow;
    }
  }

  // Product Methods (store-scoped: stores/{storeId}/vendors/{vendorId}/products/{productId})

  Future<List<Product>> getProducts(String storeId, String vendorId) async {
    try {
      final snapshot = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('vendors')
          .doc(vendorId)
          .collection('products')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Product.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  Future<void> addProduct(String storeId, String vendorId, Product product) async {
    try {
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('vendors')
          .doc(vendorId)
          .collection('products')
          .doc(product.id)
          .set(product.toMap());
    } catch (e) {
      print('Error adding product: $e');
    }
  }

  /// Partial update — only writes the supplied fields (e.g. just shopifyImageUrl after a Shopify sync).
  // ── Platform markup settings (UberEats, Instacart, …) ──────
  // Stored in Firestore: settings/{platformDocId}
  // { defaultMargin: 20.0, tagMargins: { "Flour": 25.0, ... } }

  Future<Map<String, dynamic>> getPlatformMargins(String platformDocId) async {
    try {
      final doc = await _firestore.collection('settings').doc(platformDocId).get();
      if (doc.exists) return doc.data() ?? {};
    } catch (e) {
      print('Error getting platform margins ($platformDocId): $e');
    }
    return {};
  }

  Future<void> savePlatformMargins({
    required String platformDocId,
    required double defaultMargin,
    required Map<String, double> tagMargins,
  }) async {
    await _firestore.collection('settings').doc(platformDocId).set({
      'defaultMargin': defaultMargin,
      'tagMargins': tagMargins,
    });
  }

  // ── Uber sections (section → subsection/tag mapping) ────────
  // Stored in Firestore: settings/uber_sections → { entries: [{section, subsection}] }

  Future<Map<String, dynamic>> getUberSections() async {
    try {
      final doc = await _firestore.collection('settings').doc('uber_sections').get();
      if (doc.exists) return doc.data() ?? {};
    } catch (e) {
      print('Error getting uber sections: $e');
    }
    return {};
  }

  Future<void> saveUberSections(List<Map<String, String>> entries) async {
    await _firestore.collection('settings').doc('uber_sections').set({
      'entries': entries,
    });
  }

  Future<void> updateProductFields(String storeId, String vendorId, String productId, Map<String, dynamic> fields) async {
    try {
      await _firestore
          .collection('stores').doc(storeId)
          .collection('vendors').doc(vendorId)
          .collection('products').doc(productId)
          .update(fields);
    } catch (e) {
      print('Error partial-updating product: $e');
    }
  }

  Future<void> updateProduct(String storeId, String vendorId, Product product) async {
    await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('vendors')
        .doc(vendorId)
        .collection('products')
        .doc(product.id)
        .update(product.toMap());
  }

  Future<void> deleteProduct(String storeId, String vendorId, String productId) async {
    try {
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('vendors')
          .doc(vendorId)
          .collection('products')
          .doc(productId)
          .delete();
    } catch (e) {
      print('Error deleting product: $e');
    }
  }

  // Order Methods
  Future<List<Order>> getOrdersByStoreAndVendor(
      String storeId, String vendorId) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('vendorId', isEqualTo: vendorId)
          .get();
      return snapshot.docs.map((doc) => Order.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error fetching orders: $e');
      return [];
    }
  }

  // Orders
  Future<List<Order>> getOrders() async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => Order.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error fetching orders: $e');
      return [];
    }
  }

  Future<Order?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      return Order.fromMap(doc.data()!);
    } catch (e) {
      print('Error fetching order $orderId: $e');
      return null;
    }
  }

  Future<void> addOrder(Order order) async {
    try {
      await _firestore.collection('orders').doc(order.id).set(order.toMap());
    } catch (e) {
      print('Error adding order: $e');
    }
  }

  Future<void> updateOrder(Order order) async {
    try {
      await _firestore.collection('orders').doc(order.id).update(order.toMap());
    } catch (e) {
      print('Error updating order: $e');
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();
    } catch (e) {
      print('Error deleting order: $e');
      rethrow;
    }
  }

  Future<List<Order>> getAllOrders() async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .orderBy('orderDate', descending: true)
          .get();
      return snapshot.docs.map((doc) => Order.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error fetching all orders: $e');
      return [];
    }
  }

  // Cross-Store Product Methods

  /// Fetch all products across all stores, grouped by SKU.
  Future<Map<String, List<StoreProductRef>>> getAllProductsGroupedBySku(
      List<Store> stores) async {
    final result = <String, List<StoreProductRef>>{};
    for (final store in stores) {
      final vendors = await getVendors(store.id);
      for (final vendor in vendors) {
        final products = await getProducts(store.id, vendor.id);
        for (final product in products) {
          if (product.sku.isEmpty) continue;
          result.putIfAbsent(product.sku, () => []);
          result[product.sku]!.add(StoreProductRef(
            storeId: store.id,
            storeName: store.name,
            vendorId: vendor.id,
            vendorName: vendor.name,
            productId: product.id,
            product: product,
          ));
        }
      }
    }
    return result;
  }

  // PLU File Upload Methods

  /// Upload a PLU CSV file to Firebase Storage for a specific store.
  Future<String> uploadStorePLU(String storeId, Uint8List csvBytes, String fileName) async {
    final ref = FirebaseStorage.instance
        .ref('stores/$storeId/plu/$fileName');
    await ref.putData(csvBytes, SettableMetadata(contentType: 'text/csv'));
    return await ref.getDownloadURL();
  }

  /// Update the store document with the PLU CSV URL and upload timestamp.
  Future<void> updateStorePluUrl(String storeId, String url) async {
    await _firestore.collection('stores').doc(storeId).update({
      'pluCsvUrl': url,
      'pluUploadedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Seed known PLU URLs for stores that don't have one yet.
  /// Maps store names to their gs:// Firebase Storage paths.
  static const _knownPluUrls = {
    'BG Mississauga': 'gs://storeordering-10125.firebasestorage.app/BG_MISS_PLU.csv',
    'BG Oakville': 'gs://storeordering-10125.firebasestorage.app/BG_OAK_PLU.csv',
  };

  Future<void> seedStorePluUrls() async {
    try {
      final snapshot = await _firestore.collection('stores').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? '';
        final existingUrl = data['pluCsvUrl'] as String? ?? '';
        if (existingUrl.isEmpty && _knownPluUrls.containsKey(name)) {
          await doc.reference.update({
            'pluCsvUrl': _knownPluUrls[name],
            'pluUploadedAt': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      print('Error seeding PLU URLs: $e');
    }
  }
}

