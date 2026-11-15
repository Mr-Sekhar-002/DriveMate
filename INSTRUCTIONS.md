# 🚗 DriveMate — Complete Platform Setup & User Guide

Welcome to the **DriveMate** platform! This package contains everything required to run, test, deploy, and develop the DriveMate ecosystem, including the Flutter Android app, the PHP REST API backend, Docker containerization, Cloud Database configurations, and the production-ready Release APK.

---

## 📁 Package Contents

```text
DriveMate-Complete/
├── APK/
│   └── DriveMate-Release.apk         <-- Ready-to-install Android APK (63.6 MB)
├── Database/
│   ├── drivemate_database.sql        <-- Complete MySQL database schema & sample data (UTF-8)
│   └── import_to_aiven.bat           <-- One-click database import tool
├── DriveMate-Flutter-App/            <-- Full Flutter Mobile Application Source Code
│   ├── lib/                          <-- Dart source code (Models, Screens, Theme, Config)
│   ├── assets/                       <-- Icons, illustrations, sound assets
│   └── pubspec.yaml                  <-- Flutter dependencies & metadata
├── DriveMate-PHP-API/                <-- Complete PHP 8.2 REST API Server
│   ├── controllers/                  <-- Auth, Booking, Car, Driver, Payment controllers
│   ├── config/database.php           <-- Dynamic MySQL connection (supports Aiven, Render, Local)
│   ├── routes/api.php                <-- RESTful routing engine
│   └── services/SmsService.php       <-- SMS OTP & SOS dispatch engine
├── Dockerfile                        <-- Production Dockerfile for Render cloud deployment
├── docker-entrypoint.sh              <-- Apache dynamic port initialization script
├── render.yaml                       <-- Render cloud blueprint infrastructure spec
├── push_to_github.bat                <-- One-click GitHub synchronization tool
└── INSTRUCTIONS.md                   <-- This complete guide
```

---

## ⚡ 1. Quick Start: Install & Test on Android Devices

You can install and test DriveMate immediately on one or more physical Android phones or emulators.

### Step 1: Install the APK
1. Copy `APK/DriveMate-Release.apk` to your Android device via USB, Google Drive, WhatsApp, or Bluetooth.
2. Tap the APK file on your device and tap **Install**.
   *(If prompted, allow "Install unknown apps" from your file manager).*
3. Open **DriveMate**.

### Step 2: Live Cloud Backend Connection
- The APK is **pre-configured** out of the box to connect to your live Render backend:
  **`https://drivemate-vrr6.onrender.com/api`**
- If you ever need to inspect or change the backend URL:
  - On the Login/Welcome screen, tap the **Cloud Server Settings** icon (gear / cloud icon at the top right).
  - Enter any custom URL or select a preset and tap **Ping & Save**.

---

## 👥 2. Multi-Device Testing (Customer + Driver)

DriveMate supports real-time multi-device testing connected to the same live Aiven cloud database:

### Testing on Device 1 — Customer Role
1. Open the app and select the **Customer Login** tab.
2. Enter your phone number (e.g., `8910345687`).
3. Tap **Send SMS OTP**.
4. Tap **AUTO-FILL** (or enter the 6-digit code).
5. Tap **Sign In with OTP**.
6. You are now in the Customer dashboard:
   - Browse verified drivers or search cars.
   - Enter pickup and destination on the interactive OpenStreetMap.
   - Send booking and fare negotiation requests.

### Testing on Device 2 — Driver Role
1. Open the app on your second device and select the **Driver Login** tab.
2. Sign in with the registered driver phone: **`9811223344`** (Rajesh Kumar).
3. The Driver dashboard will display:
   - Online / Offline toggle.
   - Incoming drive requests from Device 1 in real-time.
   - Negotiate, Accept, or Reject buttons.
   - Real-time trip status updates.

---

## 📱 3. OTP Login & Registration Guide

### Login with OTP:
- Enter your mobile number.
- Tap **Send SMS OTP**.
- The backend generates the verification code and saves it to the cloud database.
- An interactive banner displays the code with an **AUTO-FILL** button for 1-tap sign-in.

### Registration with OTP:
- Tap **Create Account** on the login screen.
- Enter your Full Name, Email, and Mobile Number.
- Tap **Send SMS OTP**.
- Enter the 6-digit OTP code received (or tap **AUTO-FILL**).
- Tap **Create Account**. Your account is verified and created in the database.

### How to Receive Real Carrier SMS Messages:
In India, telecom guidelines (TRAI) require an Indian DLT SMS Gateway. The DriveMate backend is pre-integrated with **Fast2SMS**:
1. Sign up for a free account at [https://www.fast2sms.com](https://www.fast2sms.com).
2. Copy your API Key from the Fast2SMS dashboard.
3. In your **Render Dashboard** → click your Web Service → **Environment**, add:
   - Key: `FAST2SMS_API_KEY`
   - Value: `your_fast2sms_api_key`
4. Fast2SMS will immediately dispatch real cellular SMS messages to your phone `8910345687`.

---

## ☁️ 4. Cloud Infrastructure (Render & Aiven)

Your production backend and database are already deployed and running:

- **Live Backend API (Render):** `https://drivemate-vrr6.onrender.com/`
- **Cloud Database (Aiven MySQL):**
  - **Host:** `mysql-39ea1200-sekharchanda989-7510.b.aivencloud.com`
  - **Port:** `13904`
  - **Database:** `drivemate` (and `defaultdb`)
  - **User:** `avnadmin`
- **GitHub Repository:** [https://github.com/Mr-Sekhar-002/DriveMate](https://github.com/Mr-Sekhar-002/DriveMate)

### Live API Test URLs (Open in Any Browser):
- Available Cars: `https://drivemate-vrr6.onrender.com/api/cars/available`
- Available Drivers: `https://drivemate-vrr6.onrender.com/api/drivers/available`

---

## 💻 5. How to Run the Flutter App Locally

To run the Flutter app on your computer using VS Code, Android Studio, or the command line:

### Prerequisites:
- Flutter SDK (v3.19 or higher)
- Android Studio or VS Code with Flutter extension
- Connected Android phone (USB debugging enabled) or Android Emulator

### Steps:
1. Open terminal inside `DriveMate-Flutter-App/`:
   ```bash
   cd DriveMate-Flutter-App
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```
4. To build a new release APK:
   ```bash
   flutter build apk --release
   ```
   The compiled APK will be output to `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🖥️ 6. How to Run the PHP REST API Locally (XAMPP / Docker)

### Option A: Using XAMPP (Local Apache & MySQL)
1. Copy the `DriveMate-PHP-API` folder into your XAMPP web root:
   `C:\xampp\htdocs\DriveMate-PHP-API`
2. Start **Apache** and **MySQL** in the XAMPP Control Panel.
3. Open `http://localhost/phpmyadmin` and import `Database/drivemate_database.sql`.
4. The local API endpoint is accessible at:
   `http://localhost/DriveMate-PHP-API/public/index.php/api` (or via Apache rewrite at `http://localhost/DriveMate-PHP-API/api`).

### Option B: Using Docker
From the project root directory, build and run the Docker container:
```bash
docker build -t drivemate-api .
docker run -p 8080:80 -e DB_HOST=your_host -e DB_NAME=drivemate -e DB_USER=your_user -e DB_PASS=your_pass drivemate-api
```
The API is now live at `http://localhost:8080/api/`.

---

## 🛡️ 7. Emergency SOS System

The Emergency SOS system is integrated directly into the application:
1. Tap the **SOS** floating button on any active trip or navigation screen.
2. The app fetches live GPS coordinates and generates a secure Google Maps tracking link.
3. An emergency dispatch alert is triggered to saved emergency contacts and master phone `8910345687`.
4. A one-tap shortcut to dial Police emergency **112** is provided immediately.

---

## 🚀 8. Summary of All Audited & Verified Features

| Module | Verification Status | Features Included |
| :--- | :--- | :--- |
| **Dark Mode Contrast** | ✅ 100% Fixed | Dynamic color tokens across all tabs, cards, dropdowns, and payment gateways. No white rectangles or unreadable text. |
| **Authentication** | ✅ 100% Functional | Dual customer/driver login tabs, SMS OTP with auto-fill, and OTP-verified registration. |
| **Price Negotiation** | ✅ 100% Functional | Clean negotiable trip fare display without cluttered fee breakdowns. Customer can propose custom counter-offers. |
| **Explore & Drivers** | ✅ 100% Functional | Real-time driver availability, ratings, and smart matching from Aiven cloud database. |
| **Wallet & Payments** | ✅ 100% Functional | Wallet balance, transaction history, add funds, withdrawal status tracking, and payment method selector. |
| **SOS Emergency** | ✅ 100% Functional | Live GPS coordinates retrieval, Google Maps shareable tracking link, and 112 emergency routing. |
| **Render Cloud & DB** | ✅ 100% Live | Dockerized PHP 8.2 Apache server on Render connected to Aiven Cloud MySQL. |

---

*DriveMate — Your Car. Your Driver.*
