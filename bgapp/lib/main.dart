import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:newstore_ordering_app/models/models.dart';
import 'package:newstore_ordering_app/providers/app_providers.dart';
import 'package:newstore_ordering_app/screens/home_screen.dart';
import 'package:newstore_ordering_app/screens/login_screen.dart';
import 'package:newstore_ordering_app/screens/store_detail_screen.dart';
import 'package:newstore_ordering_app/screens/vendor_detail_screen.dart';
import 'package:newstore_ordering_app/screens/order_creation_screen.dart';
import 'package:newstore_ordering_app/screens/product_hub_screen.dart';
import 'package:newstore_ordering_app/screens/manage_stores_screen.dart';
import 'package:newstore_ordering_app/screens/import_screen.dart';
import 'package:newstore_ordering_app/screens/product_sync_screen.dart';
import 'package:newstore_ordering_app/screens/shopify_missing_screen.dart';
import 'package:newstore_ordering_app/screens/pending_approval_screen.dart';
import 'package:newstore_ordering_app/screens/platform_markup_screen.dart';
import 'package:newstore_ordering_app/providers/plu_provider.dart';
import 'package:newstore_ordering_app/services/firebase_service.dart';
import 'package:newstore_ordering_app/services/sync_service.dart';
import 'package:newstore_ordering_app/utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Load Shopify config from Firestore on startup
    await SyncService().loadConfig();
    // Seed PLU URLs for known stores (one-time, skips if already set)
    await FirebaseService().seedStorePluUrls();
  } catch (e) {
    print('Firebase initialization: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => VendorProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => PLUProvider()),
      ],
      child: MaterialApp(
        title: 'NewStore Ordering',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            if (!authProvider.isAuthenticated) return const LoginScreen();
            if (authProvider.isPending)        return const PendingApprovalScreen();
            return const HomeScreen();
          },
        ),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/manage-stores': (context) => const ManageStoresScreen(),
          '/import': (context) => const ImportScreen(),
          '/uber-markup': (context) => const PlatformMarkupScreen(
                title: 'Uber Markup', platformDocId: 'ubereats_margins'),
          '/instacart-markup': (context) => const PlatformMarkupScreen(
                title: 'Instacart Markup', platformDocId: 'instacart_margins'),
          '/product-sync': (context) => const ProductSyncScreen(),
          '/store': (context) {
            final store = ModalRoute.of(context)?.settings.arguments as Store;
            return StoreDetailScreen(store: store);
          },
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/vendor') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => VendorDetailScreen(
                vendor: args?['vendor'] as Vendor,
                store: args?['store'] as Store,
              ),
            );
          } else if (settings.name == '/order-creation') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => OrderCreationScreen(
                store: args['store'] as Store,
                vendor: args['vendor'] as Vendor,
                editingOrder: args['editingOrder'] as Order?,
              ),
            );
          } else if (settings.name == '/product') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => ProductHubScreen(
                product: args['product'] as Product,
                store: args['store'] as Store,
                vendor: args['vendor'] as Vendor,
                currentOrder: args['currentOrder'] as Order?,
                mode: (args['mode'] as String?) ?? 'stock',
              ),
            );
          } else if (settings.name == '/product-multi') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => ProductHubScreen(
                crossStoreProduct: args['crossStoreProduct'] as CrossStoreProduct,
                allStores: args['allStores'] as List<Store>,
              ),
            );
          } else if (settings.name == '/product-lookup') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => ProductHubScreen(
                lookupSku: args['sku'] as String,
                allStores: args['allStores'] as List<Store>,
                lookupOrderListProductName: args['orderListProductName'] as String?,
              ),
            );
          } else if (settings.name == '/shopify-missing') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => ShopifyMissingScreen(
                store: args['store'] as Store,
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
