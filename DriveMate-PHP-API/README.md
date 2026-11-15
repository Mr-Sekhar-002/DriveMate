# 🚗 DriveMate — Backend REST API & Services

> High-Performance On-Demand Chauffeur Hiring & Car Rental Platform API  
> Built with **PHP 8.2+ (Pure OOP)**, **MySQL 8.0**, **OpenStreetMap (OSRM + Nominatim)**, and **Multi-Method Payments (UPI QR, In-App Wallet, Cash on Delivery, Razorpay)**.

---

## 📌 Teammate Quickstart (3 Steps to Run)

### Prerequisites
* **XAMPP** (with Apache and MySQL installed at `C:\xampp`)
* **PHP 8.1+** (PDO, cURL, OpenSSL, mbstring enabled)
* **MySQL 8.0+** or MariaDB 10.4+

---

### Step 1: Clone / Copy to XAMPP `htdocs`
Place this folder inside your XAMPP root:
```
C:\xampp\htdocs\drivemate-api\
```

### Step 2: One-Click Automated Setup
Double-click or run:
```cmd
setup.bat
```
This script automatically:
1. Verifies PHP & Composer.
2. Creates the `drivemate` database in MySQL.
3. Imports the complete schema ([`database/schema.sql`](database/schema.sql)) and demo seed data ([`database/seeds.sql`](database/seeds.sql)).
4. Creates `.env` from template.
5. Verifies required storage directories.

### Step 3: Test Health & Endpoints
Run the automated test runner in PowerShell:
```powershell
powershell -File test_all.ps1
```
Open the interactive playground in your browser:
👉 **`http://localhost/drivemate-api/test.html`**

Admin Dashboard:
👉 **`http://localhost/drivemate-api/admin/`**  
*(Login: `admin@drivemate.com` / `password`)*

---

## 🔑 Demo Login Accounts

All demo accounts share the password: **`password`**

| Role | Email | Phone | Access / Capabilities |
|---|---|---|---|
| **Admin** | `admin@drivemate.com` | `9000000000` | Full portal, revenue analytics, pricing settings |
| **Customer** | `customer@drivemate.com` | `9876543210` | Booking chauffeur, car rentals, wallet (₹1000) |
| **Driver** | `driver@drivemate.com` | `9811223344` | Live trip tracking, cash collection, earnings (₹28.5k) |
| **Fleet Owner** | `owner@drivemate.com` | `9822334455` | Manage rental cars, approve requests, fleet income |

---

## 🏗️ Architecture & Project Structure

```
drivemate-api/
│
├── .env.example             # Safe environment configuration template
├── .gitignore               # Protects secrets, logs, uploads from git
├── .htaccess                # Apache mod_rewrite for clean REST URLs
├── index.php                # Unified entry point & CORS handler
├── README.md                # Project documentation (this file)
├── CLAUDE.md                # Development standards & conventions
├── PROJECT_PRD.md           # Product Requirements Document
├── ULTRA_PLAN.md            # Architecture roadmap & milestones
├── SECURITY_AUDIT.md        # Security review & key rotation guide
│
├── config/
│   ├── database.php         # PDO connection singleton (UTF8mb4, Strict)
│   └── cors.php             # CORS headers & OPTIONS preflight
│
├── controllers/             # Business logic endpoints
│   ├── AuthController.php   # Register, Login, Phone OTP, Password Reset
│   ├── BookingController.php# Chauffeur & rental booking workflows
│   ├── CarController.php    # Vehicle listings, approvals, fleet earnings
│   ├── DriverController.php # Available drivers, online toggle, earnings
│   ├── MapController.php    # 100% OpenStreetMap (OSRM + Nominatim)
│   ├── PaymentController.php# UPI QR, Cash on Delivery, Wallet, Invoices
│   ├── TripController.php   # Start trip, 5s GPS pings, complete trip
│   ├── UserController.php   # Profiles, avatars, KYC verification
│   ├── SupportController.php# Complaints & support tickets
│   └── SettingsController.php# Dynamic base fare, rates, analytics
│
├── database/
│   ├── schema.sql           # Complete DDL tables & indexes
│   ├── seeds.sql            # Demo users, drivers, cars, wallet funds
│   └── migrate.php          # Migration runner
│
├── helpers/
│   ├── Response.php         # Standard JSON response helper
│   └── JwtHelper.php        # Pure PHP HS256 stateless JWT encoder
│
├── middleware/
│   └── AuthMiddleware.php   # Bearer token validator & RBAC
│
├── services/
│   ├── JwtService.php       # Enterprise token generation & decoding
│   └── PaymentService.php   # UPI payload, Razorpay validation, GST
│
├── routes/
│   └── api.php              # Central dispatch routing table
│
├── admin/
│   └── index.php            # Administration dashboard & analytics
│
├── test.html                # Interactive Live Testing Playground
├── test_all.ps1             # 6-step automated PowerShell test suite
└── postman_collection.json  # Complete Postman Collection (v2.1)
```

---

## 🗺️ Mapping & Navigation (100% OpenStreetMap)

DriveMate operates on zero-cost, high-reliability OpenStreetMap:
* **Road Routing Engine:** OpenStreetMap OSRM (`router.project-osrm.org`) — provides realistic driving distance, duration, and road geometry without Google Cloud billing.
* **Live Autocomplete:** OpenStreetMap Nominatim (`nominatim.openstreetmap.org`) with India countrycode filter — provides real-time address & landmark suggestions as users type.
* **Reverse Geocoding:** Converts GPS lat/lng into readable street addresses.

---

## 💳 Payment & Wallet Suite

| Method | Endpoint | Description |
|---|---|---|
| **Dynamic UPI QR** | `POST /payments/create-order` | Generates NPCI deep-link (`upi://pay?...`) and dynamic QR image for GPay / PhonePe / Paytm / BHIM. |
| **In-App Wallet** | `GET /payments/wallet`<br>`POST /payments/wallet/add-money` | Digital balance for instant 1-click booking checkout and automated refunds. |
| **Cash on Delivery** | `POST /payments/cash-collect` | Allows driver or customer to confirm cash received on trip drop-off. |
| **GST Tax Invoice** | `GET /payments/invoice?booking_id=1` | Itemized invoice with 5% GST (2.5% CGST + 2.5% SGST), driver details, and trip summary. |
| **Instant Refund** | `POST /payments/refund` | Instantly restores funds to customer's in-app wallet or original payment source. |
| **Online Gateway** | `POST /payments/verify` | Razorpay signature verification with test sandbox support. |

---

## 📮 Postman Collection Import

1. Open **Postman**.
2. Click **Import** (top left).
3. Select [`postman_collection.json`](postman_collection.json).
4. All endpoints are pre-configured. Running **Login User** automatically captures and stores the Bearer token for all other requests!

---

## 🧪 Testing the APIs

### Option A: Interactive Browser Console
Navigate to:
👉 **`http://localhost/drivemate-api/test.html`**
* Test OpenStreetMap route calculation with live autocomplete suggestions.
* Generate a dynamic UPI QR code on screen and scan with your phone.
* Top-up in-app wallet and pay for bookings.
* View and print itemized GST tax invoices.

### Option B: PowerShell CLI Test Suite
```powershell
powershell -File C:\xampp\htdocs\drivemate-api\test_all.ps1
```

---

## 🛡️ Security & Environment Guidelines

1. Never commit `.env` containing sensitive credentials to Git. Use [`.env.example`](.env.example).
2. All database queries use **PDO Prepared Statements** preventing SQL Injection.
3. Passwords are encrypted using standard **BCRYPT** hashes.
4. Protected routes require `Authorization: Bearer <token>` in headers.

---

## 👥 Team & Contribution
* **Project:** DriveMate Mobility Platform
* **Architecture:** RESTful Stateless API
* **License:** Proprietary / Team Internal
