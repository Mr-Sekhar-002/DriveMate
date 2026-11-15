# DriveMate — Complete Commercial Mobility Platform
> **Tagline:** Your Car. Your Driver.  
> **Architecture:** Flutter 3.24.3 (Android/iOS) + Core PHP 8.2 REST API + MySQL Database

---

## Package Contents

```
DriveMate-Complete-Project/
├── APK/
│   └── DriveMate-v1.0.0-release.apk        # Ready-to-install Android Release Application (30.0 MB)
├── Database/
│   └── drivemate_database.sql              # Complete MySQL database export (14 Relational Tables + Seed Data)
├── DriveMate-Flutter-App/                  # Production Flutter Frontend Source Code
│   ├── lib/                                # Application code (Providers, Models, Screens, Components)
│   ├── test/                               # 10 Feature test suites (48/48 Unit & Widget tests passed)
│   ├── assets/                             # Icons, vehicle artwork, logos
│   └── pubspec.yaml                        # Dependencies & environment configuration
├── DriveMate-PHP-API/                      # Production Core PHP REST API Backend
│   ├── config/                             # Database & environment connection
│   ├── controllers/                        # REST Controllers (Auth, Booking, Trip, Pricing, Wallet, etc.)
│   ├── helpers/                            # Response & Security utilities
│   ├── middleware/                         # JWT Authentication Middleware
│   ├── routes/                             # API Router (routes/api.php)
│   └── .env                                # Server configuration (DB credentials, UPI VPA, Razorpay keys)
└── README.md                               # This documentation file
```

---

## 1. Quick Start: Install Android Application Directly
If you just want to test or run the application immediately on an Android phone or emulator:
1. Copy `APK/DriveMate-v1.0.0-release.apk` to your phone.
2. Tap on the APK file to install (**Allow Installation from Unknown Sources** if prompted).
3. Open **DriveMate** from your app drawer.

---

## 2. Backend & Database Setup (XAMPP)

### Step 1: Database Import
1. Start **Apache** and **MySQL** in the XAMPP Control Panel.
2. Open your browser and go to `http://localhost/phpmyadmin`.
3. Create a new database named **`drivemate`** (Collation: `utf8mb4_unicode_ci`).
4. Select the `drivemate` database, go to the **Import** tab, choose `Database/drivemate_database.sql`, and click **Import**.

### Step 2: REST API Setup
1. Copy the `DriveMate-PHP-API` folder to your XAMPP htdocs directory:
   `C:\xampp\htdocs\drivemate-api`
2. Ensure the `.env` file contains your local MySQL credentials:
   ```env
   DB_HOST=localhost
   DB_NAME=drivemate
   DB_USER=root
   DB_PASS=
   JWT_SECRET=drivemate_secret_2024
   BASE_URL=http://localhost/drivemate-api
   UPI_VPA=drivemate@icici
   UPI_PAYEE_NAME="DriveMate Mobility"
   ```
3. Test the API in your browser:  
   `http://localhost/drivemate-api/promotions`  
   You should see a JSON response with active promotional coupons (`WELCOME50`, `DRIVE10`).

---

## 3. Flutter Application Development Setup

### Prerequisites:
- Flutter SDK `3.24.3` or later
- Dart SDK `3.5.3` or later
- Android Studio / VS Code with Flutter extension
- Android SDK 36

### Run Flutter in Development Mode:
1. Open the `DriveMate-Flutter-App` folder in **VS Code**.
2. Open the terminal and fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Connect your Android device via USB (or start an Android Emulator).
4. Run the application:
   ```bash
   flutter run
   ```
5. Run the complete automated test suite (48 test cases across 10 commercial mobility features):
   ```bash
   flutter test
   ```

---

## 4. Default Demo Credentials

### Customer Role:
- **Email:** `customer@drivemate.com`
- **Password:** `password123`
- **Features:** Hire Driver, Self-Drive Rental, Outstation Trip, Live Route Tracking, Start OTP (`4829`), In-App Wallet Top-Up/Withdraw, 10-Component Transparent Fare Breakdown, Safety Center & SOS Dispatch, Loyalty Rewards Redemption (`WELCOME50`), 24/7 Support Desk.

### Driver Role:
- **Email:** `driver@drivemate.com`
- **Password:** `password123`
- **Features:** Online/Offline Duty Toggle, Live Booking Request Dispatch with Countdown, Telemetry GPS updates, Chauffeur Earnings Ledger, KYC Document Verification Shield.

---

## 5. 10 Advanced Features Verification Matrix

| Feature # | Feature Module | Verification Status |
| :---: | :--- | :---: |
| 1 | Smart Booking System (4 Services, 5 Durations, Double-Booking Guard) | **4/4 Tests Passed** |
| 2 | Advanced Live Tracking (OpenStreetMap, OSRM Polyline, Start OTP, SOS) | **5/5 Tests Passed** |
| 3 | Driver Profiles & KYC Verification (DL/ID Upload, Privacy Shield) | **5/5 Tests Passed** |
| 4 | Smart Fare Calculator (Server Authoritative 10-Component Price Sheet) | **3/3 Tests Passed** |
| 5 | Safety Center & SOS Dispatch (Rapid Helplines 112, 108, 1091, Control Room) | **6/6 Tests Passed** |
| 6 | Payment & In-App Wallet (Recharge Presets, UPI/Bank Payouts, Ledger) | **6/6 Tests Passed** |
| 7 | Real-Time Notifications Hub (Categories, Haptic Vibration & Sound Controls) | **4/4 Tests Passed** |
| 8 | Premium Car Rental (5 Categories, Digital Handover Inspection Checklist) | **3/3 Tests Passed** |
| 9 | Offers & Referral Rewards (Coupon Engine, Points to Cash Conversion) | **6/6 Tests Passed** |
| 10 | Customer Support & Dispute Desk (FAQ Search, Ticket Tracking, Hotline) | **6/6 Tests Passed** |
| **Total** | **All Commercial Mobility Features** | **48/48 Tests Passed (100%)** |

---
**DriveMate** — Engineered with Flutter & Core PHP REST API.
