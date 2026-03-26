import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

class SkuCollectScreen extends StatefulWidget {
  const SkuCollectScreen({Key? key}) : super(key: key);

  @override
  State<SkuCollectScreen> createState() => _SkuCollectScreenState();
}

class _SkuCollectScreenState extends State<SkuCollectScreen> {
  final List<_ScannedSku> _scannedSkus = [];
  final _manualController = TextEditingController();
  bool _showScanner = false;
  bool _continuousScan = true;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    // Check for duplicate
    final existing = _scannedSkus.indexWhere((s) => s.sku == trimmed);
    if (existing != -1) {
      // Increment quantity
      setState(() {
        _scannedSkus[existing] = _ScannedSku(
          sku: trimmed,
          qty: _scannedSkus[existing].qty + 1,
          scannedAt: _scannedSkus[existing].scannedAt,
        );
      });
      _showAddedFeedback(trimmed, isNew: false);
    } else {
      setState(() {
        _scannedSkus.insert(0, _ScannedSku(sku: trimmed, qty: 1, scannedAt: DateTime.now()));
      });
      _showAddedFeedback(trimmed, isNew: true);
    }

    if (!_continuousScan) {
      setState(() => _showScanner = false);
    }
  }

  void _showAddedFeedback(String sku, {required bool isNew}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isNew ? Icons.add_circle : Icons.exposure_plus_1,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isNew ? 'Added: $sku' : 'Updated qty: $sku',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${_scannedSkus.length} items',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: isNew ? AppTheme.accentColor : AppTheme.secondaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      ),
    );
  }

  void _addManualSku() {
    final sku = _manualController.text.trim();
    if (sku.isEmpty) return;
    _manualController.clear();
    _onBarcodeDetected(sku);
  }

  void _removeSku(int index) {
    setState(() => _scannedSkus.removeAt(index));
  }

  void _editSkuQty(int index) {
    final item = _scannedSkus[index];
    final qtyController = TextEditingController(text: item.qty.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit: ${item.sku}'),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            prefixIcon: Icon(Icons.numbers),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = int.tryParse(qtyController.text) ?? 1;
              if (newQty > 0) {
                setState(() {
                  _scannedSkus[index] = _ScannedSku(
                    sku: item.sku,
                    qty: newQty,
                    scannedAt: item.scannedAt,
                  );
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _clearAll() async {
    if (_scannedSkus.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All SKUs'),
        content: Text('Remove all ${_scannedSkus.length} scanned items?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _scannedSkus.clear());
    }
  }

  void _copyToClipboard() {
    if (_scannedSkus.isEmpty) return;
    final text = _buildSkuListText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SKU list copied to clipboard'),
        backgroundColor: AppTheme.accentColor,
      ),
    );
  }

  String _buildSkuListText() {
    final buffer = StringBuffer();
    for (final item in _scannedSkus) {
      buffer.writeln('${item.sku},${item.qty}');
    }
    return buffer.toString().trimRight();
  }

  Future<void> _sendWhatsApp() async {
    if (_scannedSkus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No SKUs to send. Scan some items first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show phone number input dialog
    final phoneController = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send via WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_scannedSkus.length} SKUs will be sent',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Phone Number',
                hintText: '1234567890',
                prefixIcon: Icon(Icons.phone),
                helperText: 'Include country code (e.g. 1 for US/CA)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () {
              final num = phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
              if (num.isNotEmpty) {
                Navigator.pop(ctx, num);
              }
            },
          ),
        ],
      ),
    );

    if (phone == null || phone.isEmpty) return;

    final message = _buildSkuListText();
    final encodedMessage = Uri.encodeComponent(message);
    final waUrl = Uri.parse('https://wa.me/$phone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open WhatsApp'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalQty = 0;
    for (final s in _scannedSkus) {
      totalQty += s.qty;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Collect SKUs', style: TextStyle(fontSize: 16)),
            Text('Scan & send via WhatsApp',
                style: TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          if (_scannedSkus.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy to clipboard',
              onPressed: _copyToClipboard,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, size: 20),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // ─── Scanner area ───
          if (_showScanner)
            SizedBox(
              height: 260,
              child: _SkuBarcodeScannerWidget(
                onDetected: _onBarcodeDetected,
                onClose: () => setState(() => _showScanner = false),
                continuousScan: _continuousScan,
              ),
            ),

          // ─── Controls bar ───
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: AppTheme.surfaceColor,
            child: Column(
              children: [
                // Scan button + continuous toggle
                if (!_showScanner)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                          label: const Text('Start Scanning'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => setState(() => _showScanner = true),
                        ),
                      ),
                    ],
                  ),

                if (_showScanner)
                  Row(
                    children: [
                      Icon(Icons.repeat, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text('Continuous scan',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary)),
                      const Spacer(),
                      Switch(
                        value: _continuousScan,
                        onChanged: (v) =>
                            setState(() => _continuousScan = v),
                        activeColor: AppTheme.accentColor,
                      ),
                    ],
                  ),

                const SizedBox(height: 8),

                // Manual entry
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualController,
                        decoration: InputDecoration(
                          hintText: 'Enter SKU manually…',
                          prefixIcon: const Icon(Icons.keyboard, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onSubmitted: (_) => _addManualSku(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _addManualSku,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Count badge ───
          if (_scannedSkus.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryColor.withOpacity(0.05),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    '${_scannedSkus.length} SKUs · $totalQty total units',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Swipe to delete',
                    style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),

          // ─── SKU list ───
          Expanded(
            child: _scannedSkus.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(Icons.qr_code_2_rounded,
                              size: 36, color: AppTheme.secondaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text('No SKUs collected yet',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          'Scan barcodes or enter SKUs manually',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _scannedSkus.length,
                    itemBuilder: (context, index) {
                      final item = _scannedSkus[index];
                      return Dismissible(
                        key: ValueKey('${item.sku}_${item.scannedAt.millisecondsSinceEpoch}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: AppTheme.errorColor.withOpacity(0.1),
                          child: Icon(Icons.delete_outline,
                              color: AppTheme.errorColor),
                        ),
                        onDismissed: (_) => _removeSku(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: index % 2 == 0
                                ? Colors.white
                                : const Color(0xFFF8FAFC),
                            border: Border(
                              bottom: BorderSide(
                                  color: AppTheme.borderColor, width: 0.5),
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                            ),
                            title: Text(
                              item.sku,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                letterSpacing: 0.5,
                              ),
                            ),
                            trailing: GestureDetector(
                              onTap: () => _editSkuQty(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: item.qty > 1
                                      ? AppTheme.accentColor.withOpacity(0.1)
                                      : AppTheme.borderColor.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '×${item.qty}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: item.qty > 1
                                        ? AppTheme.accentColor
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // ─── Bottom action bar ───
      bottomNavigationBar: _scannedSkus.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: AppTheme.borderColor)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Copy button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                      onPressed: _copyToClipboard,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // WhatsApp button
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send, size: 18),
                        label: Text(
                            'Send ${_scannedSkus.length} SKUs via WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _sendWhatsApp,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

// ─── Scanned SKU model ──────────────────────────────────────
class _ScannedSku {
  final String sku;
  final int qty;
  final DateTime scannedAt;

  const _ScannedSku({
    required this.sku,
    required this.qty,
    required this.scannedAt,
  });
}

// ─── Barcode Scanner Widget ─────────────────────────────────
class _SkuBarcodeScannerWidget extends StatefulWidget {
  final void Function(String code) onDetected;
  final VoidCallback onClose;
  final bool continuousScan;

  const _SkuBarcodeScannerWidget({
    required this.onDetected,
    required this.onClose,
    this.continuousScan = true,
  });

  @override
  State<_SkuBarcodeScannerWidget> createState() =>
      _SkuBarcodeScannerWidgetState();
}

class _SkuBarcodeScannerWidgetState extends State<_SkuBarcodeScannerWidget> {
  final MobileScannerController _controller = MobileScannerController();
  String? _lastScanned;
  DateTime _lastScanTime = DateTime.now();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final value = barcode.rawValue!;

    // Debounce: ignore same barcode within 1.5 seconds
    final now = DateTime.now();
    if (value == _lastScanned &&
        now.difference(_lastScanTime).inMilliseconds < 1500) {
      return;
    }

    _lastScanned = value;
    _lastScanTime = now;

    widget.onDetected(value);

    if (!widget.continuousScan) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        // Close button
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            radius: 18,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              padding: EdgeInsets.zero,
              onPressed: () {
                _controller.stop();
                widget.onClose();
              },
            ),
          ),
        ),
        // Flash toggle
        Positioned(
          top: 8,
          left: 8,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            radius: 18,
            child: IconButton(
              icon: const Icon(Icons.flash_on, color: Colors.white, size: 18),
              padding: EdgeInsets.zero,
              onPressed: () => _controller.toggleTorch(),
            ),
          ),
        ),
        // Instruction
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.continuousScan
                    ? 'Scanning continuously…'
                    : 'Point at barcode',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
