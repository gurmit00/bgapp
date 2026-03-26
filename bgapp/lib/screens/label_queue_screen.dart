import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/label_queue_provider.dart';
import 'package:newstore_ordering_app/services/sync_service.dart';
import 'package:newstore_ordering_app/utils/theme.dart';
import 'package:flutter/services.dart';

/// Label Queue Screen — manage all pending shelf label requests.
/// Allows batch export to POS via NewCodes.txt.
class LabelQueueScreen extends StatefulWidget {
  final Store store;

  const LabelQueueScreen({Key? key, required this.store}) : super(key: key);

  @override
  State<LabelQueueScreen> createState() => _LabelQueueScreenState();
}

class _LabelQueueScreenState extends State<LabelQueueScreen> {
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LabelQueueProvider>().loadQueue(widget.store.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Label Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(widget.store.name, style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          Consumer<LabelQueueProvider>(
            builder: (_, provider, __) {
              if (provider.pendingCount == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${provider.pendingCount} pending',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<LabelQueueProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.label_off_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No label requests', style: TextStyle(fontSize: 16, color: Colors.grey[400])),
                  const SizedBox(height: 8),
                  Text('Add labels from the Product Hub screen', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.items.length,
            itemBuilder: (context, index) {
              final item = provider.items[index];
              return _buildLabelCard(item, provider);
            },
          );
        },
      ),
      bottomNavigationBar: Consumer<LabelQueueProvider>(
        builder: (context, provider, _) {
          if (!provider.hasPending) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFD0D5DD))),
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : () => _exportAllToPOS(provider),
                icon: _isExporting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.print, size: 18),
                label: Text(
                  _isExporting
                      ? 'Exporting…'
                      : 'Export ${provider.pendingCount} Labels to POS',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabelCard(LabelQueueItem item, LabelQueueProvider provider) {
    final isPending = item.status == LabelStatus.pending;
    final isPrinted = item.status == LabelStatus.printed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isPending
                ? const Color(0xFFF3E8FF)
                : isPrinted
                    ? const Color(0xFFD1FAE5)
                    : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isPending ? Icons.label_outline : isPrinted ? Icons.check_circle : Icons.cancel,
            color: isPending
                ? const Color(0xFF7C3AED)
                : isPrinted
                    ? const Color(0xFF047857)
                    : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(item.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${item.sku}  ·  \$${item.correctPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            Text(item.reasonLabel, style: TextStyle(fontSize: 10, color: isPending ? const Color(0xFF7C3AED) : Colors.grey)),
          ],
        ),
        trailing: isPending
            ? PopupMenuButton<String>(
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'print', child: Text('Mark Printed')),
                  const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
                onSelected: (action) async {
                  switch (action) {
                    case 'print': await provider.markPrinted(item.id); break;
                    case 'cancel': await provider.cancelItem(item.id); break;
                    case 'delete': await provider.removeFromQueue(item.id); break;
                  }
                },
              )
            : null,
        isThreeLine: true,
      ),
    );
  }

  Future<void> _exportAllToPOS(LabelQueueProvider provider) async {
    setState(() => _isExporting = true);

    try {
      final products = provider.exportPendingForPOS();
      final csv = await SyncService().generatePosImport(products)
          .timeout(const Duration(seconds: 15), onTimeout: () => null);

      if (csv != null && mounted) {
        // Upload to cloud with timeout
        final url = await SyncService().uploadNewCodesToCloud(csv)
            .timeout(const Duration(seconds: 30), onTimeout: () => null);

        if (url != null) {
          await provider.markAllPrinted();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ ${products.length} labels exported & uploaded to POS'),
                backgroundColor: const Color(0xFF047857),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload timed out — check connection'), backgroundColor: Colors.orange),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('POS import generation failed'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }

    if (mounted) setState(() => _isExporting = false);
  }
}
