import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Unified sync service for Shopify + Penny Lane POS integrations.
///
/// Handles:
///   • Shopify product lookup / create / update via Cloud Run proxy
///   • Penny Lane POS updateproduct.PLU generation via proxy
///   • Firebase Storage upload of updateproduct.PLU for Windows POS pickup
///   • Windows batch script generation for auto-download
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // ── Shopify config ──────────────────────────────────────────
  String _storeDomain = '';   // e.g. 'apniroots.com'
  String _accessToken = '';   // kept for config compat
  String _proxyUrl = '';      // Cloud Run proxy URL

  // ── POS config ──────────────────────────────────────────────
  String _posDataPath = r'C:\PENNYLANE\DATA'; // default Penny Lane data path on Windows

  // Default proxy URL — Cloud Run deployment
  static const String _defaultProxyUrl =
      'https://sync-proxy-111416353624.us-central1.run.app';

  // ── Getters ─────────────────────────────────────────────────
  bool get isConfigured => _proxyUrl.isNotEmpty || _storeDomain.isNotEmpty;
  bool get isProxyConfigured => _proxyUrl.isNotEmpty;
  String get storeDomain => _storeDomain;
  String get accessToken => _accessToken;
  String get proxyUrl => _proxyUrl;
  String get posDataPath => _posDataPath;

  // ════════════════════════════════════════════════════════════
  //  CONFIG – load / save from Firestore
  // ════════════════════════════════════════════════════════════

  /// Load config from Firestore
  Future<void> loadConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('shopify')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _storeDomain = data['storeDomain'] ?? '';
        _accessToken = data['accessToken'] ?? '';
        _proxyUrl = data['proxyUrl'] ?? _defaultProxyUrl;
        _posDataPath = data['posDataPath'] ?? r'C:\PENNYLANE\DATA';
      }
    } catch (e) {
      debugPrint('Error loading sync config: $e');
    }
    if (_proxyUrl.isEmpty) _proxyUrl = _defaultProxyUrl;
  }

  /// Save config to Firestore
  Future<void> saveConfig({
    required String storeDomain,
    required String accessToken,
    String? proxyUrl,
    String? posDataPath,
  }) async {
    _storeDomain = storeDomain.trim();
    _accessToken = accessToken.trim();
    if (proxyUrl != null && proxyUrl.trim().isNotEmpty) {
      _proxyUrl = proxyUrl.trim();
    }
    if (posDataPath != null && posDataPath.trim().isNotEmpty) {
      _posDataPath = posDataPath.trim();
    }
    await FirebaseFirestore.instance
        .collection('settings')
        .doc('shopify')
        .set({
      'storeDomain': _storeDomain,
      'accessToken': _accessToken,
      'proxyUrl': _proxyUrl,
      'posDataPath': _posDataPath,
    });
  }

  // ════════════════════════════════════════════════════════════
  //  SHOPIFY – proxy-based operations
  // ════════════════════════════════════════════════════════════

  /// Public search URL for browser fallback.
  String searchUrl(String sku) {
    if (_storeDomain.isEmpty || sku.isEmpty) return '';
    return 'https://$_storeDomain/search?q=${Uri.encodeComponent(sku)}';
  }

  /// Fetches all SKUs and barcodes from Shopify in one bulk call.
  /// Returns a Set containing every sku and barcode string on Shopify.
  Future<Set<String>> fetchAllShopifySkus() async {
    final baseUrl = _proxyUrl.isNotEmpty ? _proxyUrl : _defaultProxyUrl;
    final url = Uri.parse('$baseUrl/all-skus');
    final response = await http.get(url).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw Exception('all-skus failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final skus = List<String>.from(data['skus'] ?? []);
    final barcodes = List<String>.from(data['barcodes'] ?? []);
    return {...skus, ...barcodes};
  }

  /// Search for a product by barcode/SKU via the proxy.
  Future<Map<String, dynamic>?> findProductBySku(String sku) async {
    if (sku.isEmpty) return null;

    final baseUrl = _proxyUrl.isNotEmpty ? _proxyUrl : _defaultProxyUrl;

    try {
      final url = Uri.parse(
        '$baseUrl/product-by-sku?sku=${Uri.encodeComponent(sku)}',
      );

      debugPrint('Proxy lookup: $url');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['found'] == true && data['product'] != null) {
          final p = data['product'];
          return {
            'productTitle': p['title'] ?? '',
            'status': (p['status'] ?? 'unknown').toString().toUpperCase(),
            'match': data['match'] ?? '',
            'price': p['price'] ?? '',
            'sku': p['sku'] ?? '',
            'barcode': p['barcode'] ?? '',
            'taxable': p['taxable'] as bool? ?? true,
            'tags': List<String>.from(p['tags'] ?? []),
            'inventoryQty': p['inventoryQty'] ?? 0,
            'image': p['image'] ?? '',
            'url': p['url'] ?? '',
            'publicUrl': p['publicUrl'] ?? '',
            'handle': p['handle'] ?? '',
          };
        }
      } else {
        debugPrint('Proxy error: ${response.statusCode} ${response.body}');
      }
      return null;
    } catch (e) {
      debugPrint('Proxy exception: $e');
      return null;
    }
  }

  /// Sync a product to Shopify (create or update based on SKU).
  ///
  /// If [imageBase64] is provided, it is sent directly to Shopify.
  /// Otherwise, tries to find an existing Firebase Storage URL for the SKU.
  Future<Map<String, dynamic>?> syncProductToShopify({
    required String title,
    required String sku,
    String? barcode,
    String? price,
    String? description,
    String? vendor,
    String? productType,
    String? tags,
    bool? taxable,
    String? imageBase64,
    String? backImageBase64,
  }) async {
    final baseUrl = _proxyUrl.isNotEmpty ? _proxyUrl : _defaultProxyUrl;

    try {
      final url = Uri.parse('$baseUrl/sync-product');
      final body = <String, dynamic>{
        'title': title,
        'sku': sku,
        'barcode': barcode ?? sku,
        'price': price ?? '0.00',
        'description': description ?? '',
        'vendor': vendor ?? '',
        'productType': productType ?? '',
        'tags': tags ?? '',
      };
      if (taxable != null) body['taxable'] = taxable;

      // If base64 image(s) provided, send directly for Shopify attachment
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        body['imageBase64'] = imageBase64;
        debugPrint('Sending imageBase64 to proxy (${imageBase64.length} chars)');
      }
      if (backImageBase64 != null && backImageBase64.isNotEmpty) {
        body['backImageBase64'] = backImageBase64;
        debugPrint('Sending backImageBase64 to proxy (${backImageBase64.length} chars)');
      }

      // Also try to look up existing image URL from Firebase Storage
      if (!body.containsKey('imageBase64')) {
        try {
          final safeSku = sku.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final ref = FirebaseStorage.instance.ref('product-images/$safeSku.png');
          final imageUrl = await ref.getDownloadURL().timeout(const Duration(seconds: 10));
          body['imageUrl'] = imageUrl;
          debugPrint('Found image in Storage for Shopify: $imageUrl');
        } catch (e) {
          // Try .jpg fallback
          try {
            final safeSku = sku.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            final ref = FirebaseStorage.instance.ref('product-images/$safeSku.jpg');
            final imageUrl = await ref.getDownloadURL().timeout(const Duration(seconds: 10));
            body['imageUrl'] = imageUrl;
            debugPrint('Found .jpg image in Storage for Shopify: $imageUrl');
          } catch (e2) {
            debugPrint('No image in Storage for SKU $sku — syncing without image');
          }
        }
      }

      debugPrint('Shopify sync: POST $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 90)); // 90s — covers search + update + back image POST to Shopify

      debugPrint('Shopify sync response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
        debugPrint('Shopify sync not success: ${response.body}');
      } else {
        debugPrint('Shopify sync error: ${response.statusCode} ${response.body}');
      }
      return {'success': false, 'error': 'Status ${response.statusCode}: ${response.body}'};
    } catch (e) {
      debugPrint('Shopify sync exception: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  // ════════════════════════════════════════════════════════════
  //  BACKGROUND REMOVAL – Replicate rembg via proxy
  // ════════════════════════════════════════════════════════════

  /// Remove background from a product image.
  /// Sends base64 JPEG/PNG to proxy → Replicate rembg → returns transparent PNG base64.
  /// Fetches all active Shopify products from the public storefront via proxy.
  /// Returns list of maps with: handle, title, sku, taxable, tags, imageUrl.
  Future<List<Map<String, dynamic>>> getShopifyActiveProducts() async {
    final baseUrl = _proxyUrl.isNotEmpty ? _proxyUrl : _defaultProxyUrl;
    final url = Uri.parse('$baseUrl/shopify-active-products');
    final response = await http.get(url).timeout(const Duration(seconds: 60));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['products'] as List);
      }
    }
    throw Exception('Failed to fetch Shopify products: ${response.statusCode}');
  }

  Future<String?> removeBackground(String imageBase64) async {
    final baseUrl = _proxyUrl.isNotEmpty ? _proxyUrl : _defaultProxyUrl;
    try {
      final url = Uri.parse('$baseUrl/remove-bg');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'imageBase64': imageBase64}),
      ).timeout(const Duration(seconds: 60)); // rembg can take 5-15s on cold start
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['imageBase64'] as String?;
      }
      debugPrint('removeBackground failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('removeBackground error: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  PRODUCT IMAGES – Firebase Storage for Shopify
  // ════════════════════════════════════════════════════════════

  /// Upload product image bytes directly to Firebase Storage.
  /// Returns the public download URL on success, null on error.
  Future<String?> uploadProductImageBytes(String sku, Uint8List bytes) async {
    if (sku.isEmpty || bytes.isEmpty) {
      debugPrint('uploadProductImageBytes: SKU or bytes empty');
      return null;
    }

    try {
      final storage = FirebaseStorage.instance;
      debugPrint('📦 uploadProductImageBytes: bucket=${storage.bucket}, sku=$sku, ${bytes.length} bytes');

      final metadata = SettableMetadata(
        contentType: 'image/png',
        customMetadata: {
          'sku': sku,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final safeSku = sku.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final ref = storage.ref('product-images/$safeSku.png');
      debugPrint('📦 Uploading to: ${ref.fullPath}');

      final uploadTask = ref.putData(bytes, metadata);

      // Listen to state changes for debugging
      uploadTask.snapshotEvents.listen((snapshot) {
        debugPrint('📦 Upload state: ${snapshot.state}, transferred: ${snapshot.bytesTransferred}/${snapshot.totalBytes}');
      }, onError: (e) {
        debugPrint('📦 Upload stream error: $e');
      });

      final snapshot = await uploadTask;
      debugPrint('📦 Upload done! state=${snapshot.state}, bytes=${snapshot.bytesTransferred}');

      final downloadUrl = await ref.getDownloadURL();
      debugPrint('📦 Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('❌ uploadProductImageBytes ERROR: $e');
      debugPrint('❌ Stack: $stackTrace');
      return null;
    }
  }

  /// Upload a product image (base64) to Firebase Storage and return
  /// a public download URL that Shopify can fetch.
  Future<String?> uploadProductImage(String sku, String base64Image) async {
    if (sku.isEmpty || base64Image.isEmpty) {
      debugPrint('uploadProductImage: SKU or image is empty');
      return null;
    }

    try {
      // Strip data URI prefix if present (e.g. "data:image/jpeg;base64,")
      String cleanBase64 = base64Image;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }

      final bytes = base64Decode(cleanBase64);
      debugPrint('uploadProductImage: decoded ${bytes.length} bytes, delegating to uploadProductImageBytes');
      return uploadProductImageBytes(sku, Uint8List.fromList(bytes));
    } catch (e, stackTrace) {
      debugPrint('Product image upload error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  PENNY LANE POS – NewCodes generation & cloud delivery
  // ════════════════════════════════════════════════════════════

  /// Generate a Penny Lane POS-format NewCodes.txt for the given products.
  /// Returns the text content on success, null on error.
  Future<String?> generatePosImport(List<Map<String, String>> products) async {
    final baseUrl = _proxyUrl.isNotEmpty ? _proxyUrl : _defaultProxyUrl;

    try {
      final url = Uri.parse('$baseUrl/generate-pos-import');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'products': products}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return response.body;
      }
      debugPrint('POS import gen error: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('POS import gen exception: $e');
      return null;
    }
  }

  /// Upload updateproduct.PLU content via the Cloud Run proxy, which
  /// handles Firebase Storage upload server-side (no browser CORS issues).
  ///
  /// Store-specific: `pos-imports/{storeName}/updateproduct.PLU`
  /// Also archived: `pos-imports/{storeName}/archive/updateproduct_<timestamp>.PLU`
  ///
  /// Returns the download URL on success, null on error.
  Future<String?> uploadNewCodesToCloud(String newCodesContent, {String? storeName}) async {
    final baseUrl = _proxyUrl.isNotEmpty ? _proxyUrl : _defaultProxyUrl;

    try {
      debugPrint('uploadNewCodesToCloud: POSTing ${newCodesContent.length} chars → ${storeName ?? 'default'}');

      final url = Uri.parse('$baseUrl/upload-pos-file');
      final body = <String, dynamic>{'content': newCodesContent};
      if (storeName != null && storeName.isNotEmpty) {
        body['storeName'] = storeName;
      }
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      debugPrint('uploadNewCodesToCloud: response ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final downloadUrl = data['downloadUrl'] ?? data['publicUrl'] ?? '';
          debugPrint('uploadNewCodesToCloud: success → $downloadUrl');
          return downloadUrl;
        }
        debugPrint('uploadNewCodesToCloud: not success: ${response.body}');
        return null;
      } else {
        debugPrint('uploadNewCodesToCloud: error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('uploadNewCodesToCloud ERROR: $e');
      return null;
    }
  }

  /// Generate the Windows batch script that the POS machine runs
  /// on startup to auto-download the latest updateproduct.PLU from
  /// Firebase Storage into the Penny Lane data directory.
  String generateWindowsBatchScript({String? downloadUrl}) {
    // Use a known stable URL pattern if no specific download URL given
    final url = downloadUrl ?? '<PASTE_DOWNLOAD_URL_HERE>';

    return '''@echo off
REM ─────────────────────────────────────────────────
REM  NewStore → Penny Lane POS Auto-Import Script
REM  Place this in Windows Startup folder or run as
REM  a scheduled task before Penny Lane Manager starts.
REM ─────────────────────────────────────────────────

SET POS_DATA_DIR=$_posDataPath
SET PLU_FILE=%POS_DATA_DIR%\\updateproduct.PLU
SET DOWNLOAD_URL=$url
SET LOG_FILE=%POS_DATA_DIR%\\newcodes_sync.log

echo [%DATE% %TIME%] Checking for new POS import... >> "%LOG_FILE%"

REM Download the latest updateproduct.PLU from Firebase Storage
curl -s -o "%PLU_FILE%" "%DOWNLOAD_URL%"

IF %ERRORLEVEL% EQU 0 (
    echo [%DATE% %TIME%] Downloaded updateproduct.PLU successfully >> "%LOG_FILE%"
    
    REM Check file is not empty
    FOR %%A IN ("%PLU_FILE%") DO (
        IF %%~zA GTR 0 (
            echo [%DATE% %TIME%] File size: %%~zA bytes - ready for Penny Lane >> "%LOG_FILE%"
        ) ELSE (
            echo [%DATE% %TIME%] WARNING: Downloaded file is empty >> "%LOG_FILE%"
            DEL "%PLU_FILE%"
        )
    )
) ELSE (
    echo [%DATE% %TIME%] ERROR: Download failed (error %ERRORLEVEL%) >> "%LOG_FILE%"
)

echo [%DATE% %TIME%] Sync check complete. >> "%LOG_FILE%"
''';
  }

  /// Generate a simpler PowerShell version of the download script.
  String generatePowerShellScript({String? downloadUrl}) {
    final url = downloadUrl ?? '<PASTE_DOWNLOAD_URL_HERE>';

    return '''# NewStore → Penny Lane POS Auto-Import Script (PowerShell)
# Run as a Scheduled Task or place shortcut in shell:startup

\$posDataDir = "$_posDataPath"
\$pluFile = "\$posDataDir\\updateproduct.PLU"
\$downloadUrl = "$url"
\$logFile = "\$posDataDir\\newcodes_sync.log"

\$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content \$logFile "[\$timestamp] Checking for new POS import..."

try {
    Invoke-WebRequest -Uri \$downloadUrl -OutFile \$pluFile -UseBasicParsing
    \$fileSize = (Get-Item \$pluFile).Length
    \$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    if (\$fileSize -gt 0) {
        Add-Content \$logFile "[\$timestamp] Downloaded updateproduct.PLU (\$fileSize bytes) - ready for Penny Lane"
    } else {
        Add-Content \$logFile "[\$timestamp] WARNING: Downloaded file is empty"
        Remove-Item \$pluFile
    }
} catch {
    \$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content \$logFile "[\$timestamp] ERROR: \$_"
}
''';
  }
}
