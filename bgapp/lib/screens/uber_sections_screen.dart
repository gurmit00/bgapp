import 'package:flutter/material.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

/// Manages the section → subsection (tag) mapping used in the UberEats export.
/// Each subsection value is a Shopify tag; the section groups tags into categories.
/// Data is stored in Firestore: settings/uber_sections → { entries: [{section, subsection}] }
class UberSectionsScreen extends StatefulWidget {
  const UberSectionsScreen({Key? key}) : super(key: key);

  @override
  State<UberSectionsScreen> createState() => _UberSectionsScreenState();
}

class _UberSectionsScreenState extends State<UberSectionsScreen> {
  final _firebaseService = FirebaseService();
  bool _loading = true;
  String? _error;

  // Flat list of all entries — grouped in UI by section name.
  List<Map<String, String>> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _firebaseService.getUberSections();
      final raw  = (data['entries'] as List<dynamic>?) ?? [];
      var entries = raw.map<Map<String, String>>((e) => {
        'section':    (e['section']    as String? ?? '').trim(),
        'subsection': (e['subsection'] as String? ?? '').trim(),
      }).where((e) => e['section']!.isNotEmpty && e['subsection']!.isNotEmpty).toList();

      // Seed defaults if Firestore has no data yet.
      if (entries.isEmpty) entries = List<Map<String, String>>.from(_defaults);

      entries.sort((a, b) {
        final s = a['section']!.compareTo(b['section']!);
        return s != 0 ? s : a['subsection']!.compareTo(b['subsection']!);
      });

      setState(() { _entries = entries; _loading = false; });

      // Persist defaults on first load
      if (raw.isEmpty) await _persist();
    } catch (e) {
      setState(() { _loading = false; _error = 'Could not load sections: $e'; });
    }
  }

  Future<void> _persist() async {
    await _firebaseService.saveUberSections(_entries);
  }

  // ── Derived: entries grouped by section ──────────────────────
  Map<String, List<int>> get _grouped {
    final map = <String, List<int>>{};
    for (int i = 0; i < _entries.length; i++) {
      final s = _entries[i]['section']!;
      map.putIfAbsent(s, () => []).add(i);
    }
    return map;
  }

  // ── Add / Edit ────────────────────────────────────────────────
  Future<void> _showDialog({int? editIndex}) async {
    final sectionCtrl    = TextEditingController(
        text: editIndex != null ? _entries[editIndex]['section'] : '');
    final subsectionCtrl = TextEditingController(
        text: editIndex != null ? _entries[editIndex]['subsection'] : '');

    final existingSections = _entries.map((e) => e['section']!).toSet().toList()..sort();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editIndex != null ? 'Edit Entry' : 'Add Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Section', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: sectionCtrl.text),
              optionsBuilder: (value) => value.text.isEmpty
                  ? existingSections
                  : existingSections.where((s) => s.toLowerCase().contains(value.text.toLowerCase())),
              fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                sectionCtrl.text = ctrl.text;
                ctrl.addListener(() => sectionCtrl.text = ctrl.text);
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Beverages',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                );
              },
              onSelected: (s) => sectionCtrl.text = s,
            ),
            const SizedBox(height: 16),
            const Text('Subsection (= Shopify tag)', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            TextField(
              controller: subsectionCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. Juice & Soft Drink',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true) return;
    final section    = sectionCtrl.text.trim();
    final subsection = subsectionCtrl.text.trim();
    if (section.isEmpty || subsection.isEmpty) return;

    setState(() {
      if (editIndex != null) {
        _entries[editIndex] = {'section': section, 'subsection': subsection};
      } else {
        _entries.add({'section': section, 'subsection': subsection});
      }
      _entries.sort((a, b) {
        final s = a['section']!.compareTo(b['section']!);
        return s != 0 ? s : a['subsection']!.compareTo(b['subsection']!);
      });
    });

    await _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(editIndex != null ? 'Entry updated' : 'Entry added'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
    }
  }

  Future<void> _delete(int index) async {
    final entry = _entries[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Remove "${entry['subsection']}" from ${entry['section']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _entries.removeAt(index));
    await _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uber Sections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton(
              onPressed: () => _showDialog(),
              child: const Icon(Icons.add),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final grouped = _grouped;
    final sectionNames = grouped.keys.toList()..sort();

    if (sectionNames.isEmpty) {
      return const Center(child: Text('No sections yet. Tap + to add.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: sectionNames.length,
      itemBuilder: (ctx, si) {
        final section = sectionNames[si];
        final indices = grouped[section]!;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  section,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentColor,
                  ),
                ),
              ),
              const Divider(height: 1),
              for (int i = 0; i < indices.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16),
                _SubsectionRow(
                  subsection: _entries[indices[i]]['subsection']!,
                  onEdit:   () => _showDialog(editIndex: indices[i]),
                  onDelete: () => _delete(indices[i]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SubsectionRow extends StatelessWidget {
  final String subsection;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _SubsectionRow({required this.subsection, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(subsection, style: const TextStyle(fontSize: 13))),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: AppTheme.errorColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Default seed data from the Uber sections CSV ─────────────
const List<Map<String, String>> _defaults = [
  {'section': 'Baby Care',               'subsection': 'Baby Care'},
  {'section': 'Beverages',               'subsection': 'Juice & Soft Drink'},
  {'section': 'Beverages',               'subsection': 'Tea & Coffee'},
  {'section': 'Chutney & Sauces',        'subsection': 'Chutney & Sauces'},
  {'section': 'Chutney & Sauces',        'subsection': 'Noodles & Pasta'},
  {'section': 'Cooking Essentials',      'subsection': 'Baking Powder'},
  {'section': 'Cooking Essentials',      'subsection': 'Canned Foods'},
  {'section': 'Cooking Essentials',      'subsection': 'Cooking Paste'},
  {'section': 'Cooking Essentials',      'subsection': 'Food Colour & Essence'},
  {'section': 'Cooking Essentials',      'subsection': 'Fried Onion'},
  {'section': 'Cooking Essentials',      'subsection': 'Vinegar'},
  {'section': 'Cooking Oils',            'subsection': 'Cooking Oil'},
  {'section': 'Cooking Oils',            'subsection': 'Desi Ghee'},
  {'section': 'Cookware',                'subsection': 'Cookware'},
  {'section': 'Dairy & Bread',           'subsection': 'Bread'},
  {'section': 'Dairy & Bread',           'subsection': 'Dairy'},
  {'section': 'Dairy & Bread',           'subsection': 'Eggs'},
  {'section': 'Dairy & Bread',           'subsection': 'Paneer & Khoya'},
  {'section': 'Dairy & Bread',           'subsection': 'Yogurt Dahi'},
  {'section': 'Dal & Lentils',           'subsection': 'Dal & Lentils'},
  {'section': 'Deserts & Sweets',        'subsection': 'Sweets'},
  {'section': 'Festival',                'subsection': 'Covid-19 Supplies'},
  {'section': 'Festival',                'subsection': 'Diwali'},
  {'section': 'Festival',                'subsection': 'Fireworks'},
  {'section': 'Festival',                'subsection': 'Holi'},
  {'section': 'Festival',                'subsection': 'Lohri'},
  {'section': 'Festival',                'subsection': 'Rakhi'},
  {'section': 'Festival',                'subsection': 'Rakhsha Bandhan'},
  {'section': 'Flour',                   'subsection': 'Flour'},
  {'section': 'Frozen Ready To Eat',     'subsection': 'Frozen Ready to Eat'},
  {'section': 'Frozen Ready To Eat',     'subsection': 'Naan'},
  {'section': 'Frozen Ready To Eat',     'subsection': 'Paratha & Roti'},
  {'section': 'Frozen Vegetables',       'subsection': 'Frozen Vegetables'},
  {'section': 'Fruits and Vegetables',   'subsection': 'Fruits'},
  {'section': 'Fruits and Vegetables',   'subsection': 'Vegetables'},
  {'section': 'Health and Beauty',       'subsection': 'Beauty - Body Care'},
  {'section': 'Health and Beauty',       'subsection': 'Beauty - Hair Care'},
  {'section': 'Health and Beauty',       'subsection': 'Health Care'},
  {'section': 'HouseHolds',             'subsection': 'Households'},
  {'section': 'Masala & Spices',         'subsection': 'Masala Boxed'},
  {'section': 'Masala & Spices',         'subsection': 'Masala Powder'},
  {'section': 'Masala & Spices',         'subsection': 'Masala Powder - special'},
  {'section': 'Noodles & Pasta',         'subsection': 'Noodles & Pasta'},
  {'section': 'Organic',                 'subsection': 'Organic Ayurveda'},
  {'section': 'Organic',                 'subsection': 'Organic Dal & Lentils'},
  {'section': 'Organic',                 'subsection': 'Organic Flour'},
  {'section': 'Organic',                 'subsection': 'Organic Rice'},
  {'section': 'Organic',                 'subsection': 'Organic Spices'},
  {'section': 'Organic',                 'subsection': 'Organic Tea'},
  {'section': 'Pickle Honey Jam',        'subsection': 'Jam'},
  {'section': 'Pickle Honey Jam',        'subsection': 'Pickle'},
  {'section': 'Pooja Items',             'subsection': 'Incense'},
  {'section': 'Pooja Items',             'subsection': 'Pooja Item'},
  {'section': 'Ready To Eat',            'subsection': 'Instant Mixes'},
  {'section': 'Ready To Eat',            'subsection': 'Ready To Eat - North Indian'},
  {'section': 'Ready To Eat',            'subsection': 'Ready To Eat - South Indian'},
  {'section': 'Rice & Atta',             'subsection': 'Atta'},
  {'section': 'Rice & Atta',             'subsection': 'Poha & Mumra'},
  {'section': 'Rice & Atta',             'subsection': 'Rice'},
  {'section': 'Rice & Atta',             'subsection': 'Vermicelli'},
  {'section': 'Sale',                    'subsection': 'Sale'},
  {'section': 'Salt Sugar and Jaggery',  'subsection': 'Himalayan Salt'},
  {'section': 'Salt Sugar and Jaggery',  'subsection': 'Jaggery'},
  {'section': 'Salt Sugar and Jaggery',  'subsection': 'Salt Sugar'},
  {'section': 'Snacks & Namkeen',        'subsection': 'Biscuit & Cookies'},
  {'section': 'Snacks & Namkeen',        'subsection': 'Chikki and Gachak'},
  {'section': 'Snacks & Namkeen',        'subsection': 'Chips'},
  {'section': 'Snacks & Namkeen',        'subsection': 'Dry Fruits & Candy'},
  {'section': 'Snacks & Namkeen',        'subsection': 'Golgappa'},
  {'section': 'Snacks & Namkeen',        'subsection': 'Khakhra'},
  {'section': 'Snacks & Namkeen',        'subsection': 'Namkeen'},
  {'section': 'Snacks & Namkeen',        'subsection': 'Papad'},
  {'section': 'Snacks & Namkeen',        'subsection': 'Rusk & Cake'},
  {'section': 'Snacks & Namkeen',        'subsection': 'South Indian Snacks'},
  {'section': 'Take Away',               'subsection': 'Take Away'},
  {'section': 'Uncategorized',           'subsection': 'Uncategorized'},
];
