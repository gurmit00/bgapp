# NewStore Ordering App - Quick Start Guide

## What's Been Built

A complete professional Flutter application for managing inventory orders across multiple stores and vendors with the following screens:

✅ **Login Screen** - Guest authentication (temporary)  
✅ **Home Screen** - Store selection dashboard  
✅ **Store Management** - View and manage stores  
✅ **Vendor Management** - Add vendors with WhatsApp contact  
✅ **Product Management** - Complete product details with pricing  
✅ **Order Creation** - Smart order creation with reorder rules  

## Project Features

### Core Functionality
- Multi-store management (BG Mississauga, BG Oakville)
- Vendor tracking with contact information
- Product management with comprehensive pricing
- Smart reorder rules based on minimum stock levels
- Order creation and management
- Firebase/Firestore backend integration
- Provider-based state management

### Design
- Minimalist modern UI design
- Professional color scheme
- Responsive web layout
- Material Design 3 compliance
- Excellent UX with smooth navigation

## File Structure

```
newstore-ordering-app/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── models/
│   │   └── models.dart                   # Data models (Store, Vendor, Product, Order, etc.)
│   ├── screens/
│   │   ├── login_screen.dart             # Login screen
│   │   ├── home_screen.dart              # Home/Dashboard
│   │   ├── store_detail_screen.dart      # Store management
│   │   ├── vendor_detail_screen.dart     # Vendor management
│   │   └── order_creation_screen.dart    # Order creation
│   ├── services/
│   │   └── firebase_service.dart         # Firebase operations
│   ├── providers/
│   │   └── app_providers.dart            # State management (Provider)
│   ├── utils/
│   │   └── theme.dart                    # App theme and styling
│   └── widgets/
│       └── [Custom widgets directory]
├── web/
│   ├── index.html                        # Web entry point
│   ├── manifest.json                     # PWA manifest
│   └── favicon.png                       # App icon
├── pubspec.yaml                          # Dependencies
├── firebase.json                         # Firebase config
└── README.md                             # Documentation
```

## Quick Start

### 1. Install Dependencies
```bash
cd newstore-ordering-app
flutter pub get
```

### 2. Set Up Firebase
1. Go to [firebase.google.com](https://firebase.google.com)
2. Create a new project
3. Enable Firestore Database
4. Enable Authentication → Anonymous
5. Download your Firebase configuration

### 3. Run the App
```bash
# For web (recommended for testing)
flutter run -d chrome

# For Android
flutter run -d android

# For iOS
flutter run -d ios
```

## Data Models Overview

### Store
- Stores data with unique ID and name
- Links to multiple vendors

### Vendor
- Vendor information with WhatsApp phone number
- Belongs to a specific store
- Contains multiple products

### Product
- Product name, SKU/Barcode
- Pricing: Per unit and per case (both price and cost)
- Packaging: Pieces per case and per line
- Reorder Rules: Minimum stock and default order quantity

### Order
- Store and vendor reference
- Multiple order items
- Status tracking: draft, submitted, completed

### OrderItem
- Product reference
- On-hand quantity (in pieces)
- Order quantity (in cases)

## State Management

Uses **Provider** package for clean state management:

- `AuthProvider` - User authentication
- `StoreProvider` - Store operations
- `VendorProvider` - Vendor operations per store
- `ProductProvider` - Product operations per vendor
- `OrderProvider` - Order creation and management

## Key Features Explained

### Smart Reorder Rules
When creating an order, each product shows:
- Minimum stock threshold (in pieces)
- Default order quantity (in cases)
- Smart calculation based on on-hand inventory

### Multi-Store Architecture
- BG Mississauga and BG Oakville are pre-configured
- Each store can have multiple vendors
- Each vendor can have multiple products
- Hierarchical data organization

### Professional UI
- Dark blue-gray primary color (#1F2937)
- Blue secondary color (#3B82F6)
- Green accent color (#10B981)
- Clean, spacious layouts
- Responsive design for all screen sizes

## Firestore Database Schema

```
/stores
  /storeId
    - name: string
    - createdAt: timestamp

/vendors
  /vendorId
    - storeId: string
    - name: string
    - whatsappPhoneNumber: string
    - createdAt: timestamp

/products
  /productId
    - vendorId: string
    - name: string
    - sku: string
    - pcsPerCase: number
    - pcsPerLine: number
    - pcPrice: number
    - pcCost: number
    - casePrice: number
    - caseCost: number
    - reorderRule: { minStockPcs, defaultOrderQty }
    - createdAt: timestamp

/orders
  /orderId
    - storeId: string
    - vendorId: string
    - orderDate: timestamp
    - items: array of OrderItem
    - status: string
    - createdAt: timestamp
```

## Dependencies

- **firebase_core** - Firebase initialization
- **firebase_auth** - Authentication
- **cloud_firestore** - Database
- **provider** - State management
- **flutter** - UI framework

## Next Steps

1. **Firebase Setup** - Configure your Firebase project
2. **Run the App** - Test in browser with `flutter run -d chrome`
3. **Add Stores** - Through Settings → Manage Stores
4. **Add Vendors** - Via Store detail screen
5. **Add Products** - Through Vendor detail screen
6. **Create Orders** - Use Order Creation screen

## Customization Tips

### Update Store Names
Edit the default stores in `models.dart` or add them through the UI

### Modify Theme Colors
Update `lib/utils/theme.dart` with your brand colors

### Add More Screens
Create new screen files in `lib/screens/` and add routes to `main.dart`

### Extend Products
Add new fields to the `Product` model in `models.dart`

## Troubleshooting

### Firestore Connection Issues
- Check Firebase project configuration
- Verify Firestore security rules allow read/write
- Ensure authentication is enabled

### Flutter Errors
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Web Build Issues
```bash
flutter clean
flutter pub cache repair
flutter run -d chrome
```

## Deployment

### Deploy to Firebase Hosting
```bash
flutter build web --release
firebase deploy --only hosting
```

### Build APK for Android
```bash
flutter build apk --release
```

### Build for iOS
```bash
flutter build ios --release
```

## Support & Documentation

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Provider Package](https://pub.dev/packages/provider)

---

**Version**: 1.0.0  
**Last Updated**: March 2026  
**Status**: ✅ Complete and Ready for Deployment
