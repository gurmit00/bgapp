import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbauth;
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';
import 'package:newstore_ordering_app/utils/app_roles.dart';

class StoreProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<Store> _stores = [];
  Store? _selectedStore;
  bool _isLoading = false;
  String? _error;

  List<Store> get stores => _stores;
  Store? get selectedStore => _selectedStore;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadStores() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _stores = await _firebaseService.getStores();
    } catch (e) {
      _error = 'Failed to load stores';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectStore(Store store) {
    _selectedStore = store;
    notifyListeners();
  }

  Future<void> addStore(String name) async {
    final store = Store(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      address: '',
      phone: '',
    );
    await _firebaseService.addStore(store);
    _stores.add(store);
    notifyListeners();
  }

  Future<void> updateStore(Store store) async {
    await _firebaseService.updateStore(store);
    final index = _stores.indexWhere((s) => s.id == store.id);
    if (index != -1) {
      _stores[index] = store;
      notifyListeners();
    }
  }

  Future<void> deleteStore(String storeId) async {
    await _firebaseService.deleteStore(storeId);
    _stores.removeWhere((s) => s.id == storeId);
    notifyListeners();
  }
}

class VendorProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<Vendor> _vendors = [];
  Vendor? _selectedVendor;
  bool _isLoading = false;
  String? _currentStoreId;

  List<Vendor> get vendors => _vendors;
  Vendor? get selectedVendor => _selectedVendor;
  bool get isLoading => _isLoading;
  String? get currentStoreId => _currentStoreId;

  Future<void> loadVendors(String storeId) async {
    _currentStoreId = storeId;
    _isLoading = true;
    notifyListeners();
    
    _vendors = await _firebaseService.getVendors(storeId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addVendor(String storeId, String name, String whatsappPhoneNumber) async {
    final vendor = Vendor(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      whatsappPhoneNumber: whatsappPhoneNumber,
      createdAt: DateTime.now(),
    );
    
    await _firebaseService.addVendor(storeId, vendor);
    _vendors.add(vendor);
    notifyListeners();
  }

  Future<void> deleteVendor(String storeId, String vendorId) async {
    await _firebaseService.deleteVendor(storeId, vendorId);
    _vendors.removeWhere((v) => v.id == vendorId);
    notifyListeners();
  }

  Future<void> updateVendor(String storeId, Vendor vendor) async {
    await _firebaseService.updateVendor(storeId, vendor);
    final index = _vendors.indexWhere((v) => v.id == vendor.id);
    if (index != -1) {
      _vendors[index] = vendor;
      notifyListeners();
    }
  }

  void selectVendor(Vendor vendor) {
    _selectedVendor = vendor;
    notifyListeners();
  }
}

class ProductProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<Product> _products = [];
  bool _isLoading = false;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> loadProductsByVendor(String storeId, String vendorId) async {
    _isLoading = true;
    notifyListeners();
    _products = await _firebaseService.getProducts(storeId, vendorId);
    _products.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProduct(String storeId, String vendorId, Product product) async {
    await _firebaseService.addProduct(storeId, vendorId, product);
    _products.add(product);
    notifyListeners();
  }

  Future<void> updateProduct(String storeId, String vendorId, Product product) async {
    await _firebaseService.updateProduct(storeId, vendorId, product);
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _products[index] = product;
    }
    notifyListeners();
  }

  Future<void> deleteProduct(String storeId, String vendorId, String productId) async {
    await _firebaseService.deleteProduct(storeId, vendorId, productId);
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
  }
}

class OrderProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<Order> _orders = [];
  Order? _currentOrder;
  bool _isLoading = false;
  String? _error;

  List<Order> get orders => _orders;
  Order? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadOrders(String storeId, String vendorId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _firebaseService.getOrdersByStoreAndVendor(storeId, vendorId);
    } catch (e) {
      _error = 'Failed to load orders';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addOrder(Order order) async {
    await _firebaseService.addOrder(order);
    _orders.add(order);
    notifyListeners();
  }

  Future<void> loadAllOrders() async {
    _isLoading = true;
    notifyListeners();
    _orders = await _firebaseService.getOrders();
    _isLoading = false;
    notifyListeners();
  }

  void createNewOrder(String storeId, String vendorId) {
    _currentOrder = Order(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      storeId: storeId,
      vendorId: vendorId,
      orderDate: DateTime.now(),
      items: [],
      status: 'draft',
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  void setCurrentOrderForEditing(Order order) {
    _currentOrder = order;
    notifyListeners();
  }

  void addOrderItem(OrderItem item) {
    if (_currentOrder != null) {
      _currentOrder!.items.add(item);
      notifyListeners();
    }
  }

  void removeOrderItem(String itemId) {
    if (_currentOrder != null) {
      _currentOrder!.items.removeWhere((item) => item.id == itemId);
      notifyListeners();
    }
  }

  Future<void> saveOrder() async {
    if (_currentOrder != null) {
      await _firebaseService.addOrder(_currentOrder!);
      _orders.add(_currentOrder!);
      _currentOrder = null;
      notifyListeners();
    }
  }

  Future<void> updateOrder(Order order) async {
    await _firebaseService.updateOrder(order);
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
      _orders[index] = order;
      notifyListeners();
    }
  }

  /// Upsert — creates or overwrites. Used for auto-save drafts.
  Future<void> addOrUpdateOrder(Order order) async {
    await _firebaseService.addOrder(order); // addOrder uses .set() — safe as upsert
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
      _orders[index] = order;
    } else {
      _orders.add(order);
    }
    notifyListeners();
  }

  Future<void> deleteOrder(String orderId) async {
    await _firebaseService.deleteOrder(orderId);
    _orders.removeWhere((o) => o.id == orderId);
    notifyListeners();
  }
}

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  User? _user;
  String _role = AppRoles.staff;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  String get role => _role;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  bool get isPending => _role == AppRoles.pending && _user != null;
  bool hasPermission(String permission) => AppRoles.hasPermission(_role, permission);

  /// Re-fetches the user's role from Firestore. Used on the pending screen.
  Future<void> refreshRole() async {
    if (_user == null) return;
    final role = await _firebaseService.getUserRole(_user!.id);
    if (role != null && role != _role) {
      _role = role;
      notifyListeners();
    }
  }

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _firebaseService.rawAuthStateChanges.listen((fbUser) async {
      if (fbUser == null) {
        _user = null;
        _role = AppRoles.staff;
        _isLoading = false;
        notifyListeners();
        return;
      }
      _user = User(
        id: fbUser.uid,
        email: fbUser.email ?? '',
        displayName: fbUser.displayName ?? 'User',
      );
      // Anonymous users get staff by default, no Firestore doc created
      if (!fbUser.isAnonymous) {
        final role = await _firebaseService.getUserRole(fbUser.uid);
        _role = role ?? AppRoles.pending; // unknown users are pending until admin assigns a role
      } else {
        _role = AppRoles.pending; // guest users also get no access
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _firebaseService.signInWithGoogle();
    } catch (e) {
      _error = 'Google sign-in failed. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmailPassword(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _firebaseService.signInWithEmailPassword(email, password);
    } on fbauth.FirebaseAuthException catch (e) {
      _error = _authErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Sign-in failed. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInAsGuest() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _firebaseService.signInAnonymously();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
    _user = null;
    _role = AppRoles.staff;
    notifyListeners();
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential': return 'Incorrect email or password.';
      case 'wrong-password':     return 'Incorrect password.';
      case 'invalid-email':      return 'Invalid email address.';
      case 'user-disabled':      return 'This account has been disabled.';
      case 'too-many-requests':  return 'Too many attempts. Try again later.';
      default:                   return 'Sign-in failed. Please try again.';
    }
  }
}
