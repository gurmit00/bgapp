import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:newstore_ordering_app/models/models.dart';

/// Provider for the Label Queue system.
/// Tracks shelf labels that need printing/fixing via POS batch export.
///
/// Firestore path: stores/{storeId}/labelQueue/{itemId}
class LabelQueueProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<LabelQueueItem> _items = [];
  bool _isLoading = false;
  String? _currentStoreId;

  List<LabelQueueItem> get items => _items;
  List<LabelQueueItem> get pendingItems =>
      _items.where((i) => i.status == LabelStatus.pending).toList();
  int get pendingCount => pendingItems.length;
  bool get isLoading => _isLoading;
  bool get hasPending => pendingItems.isNotEmpty;

  /// Load all label queue items for a store
  Future<void> loadQueue(String storeId) async {
    _currentStoreId = storeId;
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('labelQueue')
          .orderBy('createdAt', descending: true)
          .get();

      _items = snapshot.docs
          .map((doc) => LabelQueueItem.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error loading label queue: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add a label request to the queue
  Future<void> addToQueue(LabelQueueItem item) async {
    final storeId = item.storeId;

    try {
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('labelQueue')
          .doc(item.id)
          .set(item.toMap());

      _items.insert(0, item);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to label queue: $e');
      rethrow;
    }
  }

  /// Mark a label as printed
  Future<void> markPrinted(String itemId) async {
    if (_currentStoreId == null) return;

    final updated = _items
        .firstWhere((i) => i.id == itemId)
        .copyWith(status: LabelStatus.printed, completedAt: DateTime.now());

    await _firestore
        .collection('stores')
        .doc(_currentStoreId!)
        .collection('labelQueue')
        .doc(itemId)
        .update(updated.toMap());

    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx != -1) {
      _items[idx] = updated;
      notifyListeners();
    }
  }

  /// Cancel a label request
  Future<void> cancelItem(String itemId) async {
    if (_currentStoreId == null) return;

    final updated = _items
        .firstWhere((i) => i.id == itemId)
        .copyWith(status: LabelStatus.cancelled, completedAt: DateTime.now());

    await _firestore
        .collection('stores')
        .doc(_currentStoreId!)
        .collection('labelQueue')
        .doc(itemId)
        .update(updated.toMap());

    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx != -1) {
      _items[idx] = updated;
      notifyListeners();
    }
  }

  /// Remove a label from queue entirely
  Future<void> removeFromQueue(String itemId) async {
    if (_currentStoreId == null) return;

    await _firestore
        .collection('stores')
        .doc(_currentStoreId!)
        .collection('labelQueue')
        .doc(itemId)
        .delete();

    _items.removeWhere((i) => i.id == itemId);
    notifyListeners();
  }

  /// Check if SKU already has a pending label request
  bool hasPendingForSku(String sku) {
    return _items.any(
      (i) => i.sku == sku && i.status == LabelStatus.pending,
    );
  }

  /// Generate POS import data for all pending labels
  /// Returns list of maps ready for SyncService.generatePosImport()
  List<Map<String, String>> exportPendingForPOS() {
    return pendingItems.map((item) {
      return {
        'sku': item.sku,
        'name': item.productName,
        'price': item.correctPrice.toStringAsFixed(2),
        'cost': '0',
        'department': '',
        'departmentName': '',
        'vendor': '',
        'reorderLevel': '0',
        'reorderQty': '0',
      };
    }).toList();
  }

  /// Mark all pending items as printed (after batch export)
  Future<void> markAllPrinted() async {
    for (final item in pendingItems) {
      await markPrinted(item.id);
    }
  }
}
