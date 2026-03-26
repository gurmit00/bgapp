# NewStore Ordering App

A professional Flutter web application for managing inventory orders across multiple stores and vendors. Built with Firebase/Firestore backend and designed with minimalist modern UI principles.

## Features

### ✨ Core Features
- **Multi-Store Management**: Manage orders for BG Mississauga and BG Oakville
- **Vendor Management**: Track multiple vendors with WhatsApp contact information
- **Product Management**: Comprehensive product details including pricing and packaging information
- **Smart Reorder Rules**: Automatic calculation of reorder quantities based on on-hand inventory
- **Order Creation**: Intuitive order creation workflow

## Project Structure

```
lib/
├── main.dart
├── models/models.dart
├── screens/
├── services/firebase_service.dart
├── providers/app_providers.dart
└── utils/theme.dart
```

## Setup & Installation

### Prerequisites
- Flutter SDK 3.0+
- Firebase project with Firestore enabled

### Installation Steps

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Configure Firebase**
   - Create a Firebase project
   - Enable Firestore database
   - Download Firebase configuration

3. **Run the app**
   ```bash
   flutter run -d chrome
   ```

## License

This project is proprietary and confidential.

## Overview
The Newstore Ordering App is a Flutter application designed to streamline the order generation process by analyzing quantities on hand and utilizing reorder rules. The app is built using Firebase and Firestore, ensuring real-time data synchronization and user authentication.

## Features
- **User Authentication**: Google login functionality with a temporary guest user option for testing.
- **Store Management**: View and manage multiple stores.
- **Vendor Management**: Manage vendor details including names and WhatsApp phone numbers.
- **Product Management**: Manage product details such as SKU, pricing, and reorder rules.
- **Order Management**: View existing orders and create new orders based on date, store, and vendor.
- **Bulk Import**: Import order sheets in bulk with optional product details.

## Project Structure
```
newstore-ordering-app
├── lib
│   ├── main.dart
│   ├── screens
│   ├── models
│   ├── services
│   ├── widgets
│   └── utils
├── pubspec.yaml
├── pubspec.lock
├── web
│   ├── index.html
│   ├── favicon.png
│   └── manifest.json
├── android
├── ios
└── README.md
```

## Setup Instructions
1. **Clone the Repository**: 
   ```
   git clone <repository-url>
   cd newstore-ordering-app
   ```

2. **Install Dependencies**: 
   Run the following command to install the required dependencies:
   ```
   flutter pub get
   ```

3. **Firebase Configuration**: 
   - Set up a Firebase project and configure Firestore.
   - Add your Firebase configuration to the project.

4. **Run the Application**: 
   Use the following command to run the application:
   ```
   flutter run -d chrome
   ```

## Usage
- Launch the application in a web browser.
- Use Google login to authenticate or proceed as a guest.
- Navigate through the different screens to manage stores, vendors, products, and orders.

## Contributing
Contributions are welcome! Please open an issue or submit a pull request for any enhancements or bug fixes.

## License
This project is licensed under the MIT License. See the LICENSE file for details.