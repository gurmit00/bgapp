import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInEmail(AuthProvider auth) async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    await auth.signInWithEmailPassword(email, password);
    // Navigation handled by Consumer<AuthProvider> in main.dart
  }

  Future<void> _signInGoogle(AuthProvider auth) async {
    await auth.signInWithGoogle();
    // Navigation handled by Consumer<AuthProvider> in main.dart
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'NewStore',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order Management',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 48),

                  // Login card
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 380),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text('Sign in to continue', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 24),

                        // Email field
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                          onSubmitted: (_) => _signInEmail(auth),
                        ),
                        const SizedBox(height: 12),

                        // Password field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          onSubmitted: (_) => _signInEmail(auth),
                        ),
                        const SizedBox(height: 8),

                        // Error message
                        if (auth.error != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            auth.error!,
                            style: TextStyle(color: AppTheme.errorColor, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                        ],

                        const SizedBox(height: 12),

                        // Sign In button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : () => _signInEmail(auth),
                            child: auth.isLoading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Sign In'),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Divider
                        Row(children: [
                          Expanded(child: Divider(color: AppTheme.borderColor)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: Theme.of(context).textTheme.bodySmall),
                          ),
                          Expanded(child: Divider(color: AppTheme.borderColor)),
                        ]),
                        const SizedBox(height: 20),

                        // Google Sign In
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: auth.isLoading ? null : () => _signInGoogle(auth),
                            icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                            label: const Text('Sign in with Google'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Guest (testing only)
                        Center(
                          child: TextButton(
                            onPressed: auth.isLoading ? null : () => auth.signInAsGuest(),
                            child: Text(
                              'Continue as Guest (limited access)',
                              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
