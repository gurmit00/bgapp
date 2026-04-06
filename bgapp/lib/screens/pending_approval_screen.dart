import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

/// Shown when a user has signed in but has not been assigned a role yet.
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({Key? key}) : super(key: key);

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _checking = false;

  Future<void> _checkAccess() async {
    setState(() => _checking = true);
    await context.read<AuthProvider>().refreshRole();
    if (mounted) setState(() => _checking = false);
    // If role changed away from pending, main.dart consumer will redirect automatically
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.hourglass_top_rounded, size: 36, color: AppTheme.warningColor),
                ),
                const SizedBox(height: 20),
                Text('Awaiting Approval',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  'Your account has been created. Please ask an admin to grant you access.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (auth.user?.email != null)
                  Text(
                    auth.user!.email,
                    style: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : _checkAccess,
                    icon: _checking
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(_checking ? 'Checking…' : 'Check Access'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await context.read<AuthProvider>().signOut();
                  },
                  child: Text('Sign Out', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
