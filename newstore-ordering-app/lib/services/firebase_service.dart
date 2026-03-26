import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart' as auth;
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

  // Store Methods
  Future<List<Store>> getStores() async {
    try {
      final snapshot = await _firestore.collection('stores').get();
      return snapshot.docs.map((doc) => Store.fromMap(doc.data())).toList();
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
      return snapshot.docs.map((doc) => Vendor.fromMap(doc.data())).toList();
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
      return snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
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

  Future<void> updateProduct(String storeId, String vendorId, Product product) async {
    try {
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('vendors')
          .doc(vendorId)
          .collection('products')
          .doc(product.id)
          .update(product.toMap());
    } catch (e) {
      print('Error updating product: $e');
    }
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
}

