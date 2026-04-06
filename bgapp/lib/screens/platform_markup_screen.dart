import 'package:flutter/material.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';
import 'package:newstore_ordering_app/services/sync_service.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

/// Generic markup settings screen for any online platform (UberEats, Instacart, …).
/// Pass [title] (e.g. "Uber Markup") and [platformDocId] (e.g. "ubereats_margins").
class PlatformMarkupScreen extends StatefulWidget {
  final String title;
  final String platformDocId;

  const PlatformMarkupScreen({
    Key? key,
    required this.title,
    required this.platformDocId,
  }) : super(key: key);

  @override
  State<PlatformMarkupScreen> createState() => _PlatformMarkupScreenState();
}

class _PlatformMarkupScreenState extends State<PlatformMarkupScreen> {
  final _firebaseService = FirebaseService();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  double _defaultMargin = 20.0;
  final _defaultMarginCtrl = TextEditingController(text: '20');

  List<String> _allTags = [];
  final Map<String, TextEditingController> _tagCtrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _defaultMarginCtrl.dispose();
    for (final c in _tagCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });

    // ── Step 1: Load saved margins — must succeed to show the form ──
    Map<String, dynamic> saved;
    try {
      saved = await _firebaseService.getPlatformMargins(widget.platformDocId);
    } catch (e) {
      setState(() { _loading = false; _error = 'Could not load margins: $e'; });
      return;
    }

    final savedDefault = (saved['defaultMargin'] as num?)?.toDouble() ?? 20.0;
    final savedTagMap  = (saved['tagMargins'] as Map<String, dynamic>?) ?? {};

    _defaultMarginCtrl.text = _fmt(savedDefault);
    setState(() {
      _defaultMargin = savedDefault;
      _loading = false;
    });

    // ── Step 2: Load Shopify tags — optional, failure shows empty list ──
    try {
      final products = await SyncService().getShopifyActiveProducts();
      final tagSet = <String>{};
      for (final p in products) {
        final tags = p['tags'] as String? ?? '';
        for (final t in tags.split(',')) {
          final trimmed = t.trim();
          if (trimmed.isNotEmpty) tagSet.add(trimmed);
        }
      }
      final sortedTags = tagSet.toList()..sort();

      final newCtrls = <String, TextEditingController>{};
      for (final tag in sortedTags) {
        final val = (savedTagMap[tag] as num?)?.toDouble();
        newCtrls[tag] = TextEditingController(text: val != null ? _fmt(val) : '');
      }

      if (mounted) {
        setState(() {
          for (final c in _tagCtrls.values) c.dispose();
          _tagCtrls..clear()..addAll(newCtrls);
          _allTags = sortedTags;
        });
      }
    } catch (_) {
      // Tags list stays empty — user can still edit the default margin
    }
  }

  Future<void> _save() async {
    final defaultVal = double.tryParse(_defaultMarginCtrl.text.trim());
    if (defaultVal == null || defaultVal < 0 || defaultVal > 999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid default margin (0–999)')),
      );
      return;
    }

    final tagMargins = <String, double>{};
    for (final tag in _allTags) {
      final text = _tagCtrls[tag]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final val = double.tryParse(text);
      if (val == null || val < 0 || val > 999) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid margin for "$tag"')),
        );
        return;
      }
      tagMargins[tag] = val;
    }

    setState(() => _saving = true);
    try {
      await _firebaseService.savePlatformMargins(
        platformDocId: widget.platformDocId,
        defaultMargin: defaultVal,
        tagMargins: tagMargins,
      );
      if (mounted) {
        setState(() { _defaultMargin = defaultVal; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Margins saved'), backgroundColor: AppTheme.accentColor),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!_loading)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? 'Saving…' : 'Save'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Default margin card ──────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Default Margin',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text(
                  'Applied to any tag that has no specific margin set.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(width: 100, child: _MarginField(controller: _defaultMarginCtrl)),
                    const SizedBox(width: 8),
                    const Text('%', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Per-tag margins ──────────────────────────────────────
        Text('Margins by Tag  (${_allTags.length} tags)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 8),

        if (_allTags.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No tags found — loading or proxy not deployed')),
          )
        else
          Card(
            child: Column(
              children: [
                for (int i = 0; i < _allTags.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16),
                  _TagRow(
                    tag: _allTags[i],
                    controller: _tagCtrls[_allTags[i]]!,
                    defaultMargin: _defaultMargin,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ── Tag row ──────────────────────────────────────────────────
class _TagRow extends StatelessWidget {
  final String tag;
  final TextEditingController controller;
  final double defaultMargin;
  const _TagRow({required this.tag, required this.controller, required this.defaultMargin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(tag, style: const TextStyle(fontSize: 14))),
          SizedBox(
            width: 80,
            child: _MarginField(
              controller: controller,
              hintText: '${_fmt(defaultMargin)} (def)',
            ),
          ),
          const SizedBox(width: 6),
          const Text('%', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.clear, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Reset to default',
            onPressed: controller.text.isEmpty ? null : () => controller.clear(),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ── Reusable % input field ───────────────────────────────────
class _MarginField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  const _MarginField({required this.controller, this.hintText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText ?? '20',
        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
