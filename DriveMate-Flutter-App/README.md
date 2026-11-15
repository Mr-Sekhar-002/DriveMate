# DriveMate — Flutter & Dart Cross-Platform Application

> **Your Car. Your Driver. Anytime.**
> A modern, production-grade Flutter application implementing the complete DriveMate blueprint specification: On-demand Professional Driver Hiring, Car Rentals (Self-Drive & With Driver), Multi-Role Access (Customer, Driver, Car Owner, Admin), and Live OSRM Route Navigation with Simulated Telemetry.

---

## 🚀 Key Architectural Pillars & Features

### 1. Multi-Role Unified App
DriveMate unifies all platform stakeholders in a single responsive client:
* **Customer Mode**:
  * **Main Search Engine**: Interactive location picker (Pickup, Destination, Travel Date & Time) with quick airport/office suggestions.
  * **Flow 1 — Hire a Driver**: Customer provides their own vehicle (Sedan, SUV, Luxury) and books verified professional chauffeurs with hourly rates ($15/hr).
  * **Flow 2 — Rent a Car**: Self-drive rental fleet with daily/hourly options, security deposit breakdown, and vehicle type filtering (Sedan, SUV, Luxury, Hatchback).
  * **Flow 3 — Rent Car + Driver**: All-in-one executive chauffeur-driven packages with luxury vehicles (Mercedes-Benz, Toyota Fortuner, Camry Hybrid).
  * **Bookings Center**: Tabbed status views (In Progress, Confirmed, Completed) with live ride tracking links and chauffeur rating.
* **Driver Mode**:
  * Online / Offline real-time toggle.
  * Instant incoming ride request dispatches with Customer pickup, destination, fare, and Accept / Decline actions.
  * Turn-by-turn OSRM GPS navigation interface with speed, ETA, and progress telemetry.
  * Today's earnings and trip metrics.
* **Car Owner Mode**:
  * Vehicle fleet monitoring and monetization stats (Monthly revenue, utilization rate).
  * **"List My Car" Portal**: Modal dialog to register vehicles, set hourly/daily rates, select rental mode (Self-Drive, With Driver, or Both), and manage fleet availability.
* **Admin Mode (Command Center)**:
  * Central command panel monitoring system status, live trips, and revenue metrics.
  * **Driver KYC Verification**: Review driver license, RC book, insurance, and KYC Aadhaar documents with Approve / Reject workflows.
  * **MySQL ERD Inspector**: Real-time view of the 10 database entities from the DriveMate specification.

### 2. Live OSRM Route Engine & Canvas Map
* **Dynamic Turn-by-Turn Guidance**: Maneuver instructions dynamically adapt as trip progresses (departure, ramp entrance, highway merge, destination arrival).
* **Custom Route Canvas**: Uses Flutter's `CustomPainter` to draw the city street grid, planned route line, animated cyan progress polyline, live vehicle position with radar wave pulse, and pickup/destination markers.
* **Telemetry**: Distance remaining, speed (44 km/h), ETA, and 4-digit security OTP code.
* **Interactive Ride Simulation**: "+25% Step" simulation button and "Complete Trip" action triggering the 5-star rating & review dialog.

---

## 📁 Project Directory Structure

```
drivemate_flutter/
├── lib/
│   ├── main.dart                          # Application entry point, theme setup & root role router
│   ├── theme/
│   │   └── app_theme.dart                 # Brand palette (Navy900, CyanAccent, ElectricBlue), light & dark themes
│   ├── models/
│   │   └── drivemate_models.dart          # Data entities (User, DriverProfile, Vehicle, CarListing, Booking, Trip, etc.)
│   ├── providers/
│   │   └── drivemate_provider.dart        # ChangeNotifier state management for all user roles, bookings & trips
│   ├── components/
│   │   ├── drivemate_header.dart          # Header with logo, blueprint button, notifications badge, role switcher
│   │   ├── trip_search_widget.dart        # Interactive search bar with suggestions & 3 service type tabs
│   │   ├── booking_card.dart              # Booking card with route timeline, status pills, and action buttons
│   │   ├── live_trip_map_card.dart        # OSRM turn-by-turn guidance and custom painter GPS route canvas
│   │   └── rating_review_dialog.dart      # 5-star rating modal with feedback tags and review submission
│   └── screens/
│       ├── auth/
│       │   └── auth_screen.dart           # Login and Registration with role picker (Customer, Driver, Owner, Admin)
│       ├── customer/
│       │   ├── customer_home_screen.dart  # Hero header, search, 3 direct service cards, fleet and chauffeur list
│       │   ├── hire_driver_flow_screen.dart # Flow 1: Duration selector, customer car info, payment gateways
│       │   ├── rent_car_flow_screen.dart  # Flow 2: Car filters, daily rates, security deposit breakdown
│       │   ├── rent_car_and_driver_flow_screen.dart # Flow 3: Executive chauffeur packages
│       │   ├── active_trip_tracking_screen.dart # Live OSRM route tracking, Chauffeur call & SOS emergency
│       │   └── customer_bookings_screen.dart # Filterable booking history
│       ├── driver/
│       │   └── driver_dashboard_screen.dart # Online toggle, incoming ride banner, earnings, active navigation
│       ├── owner/
│       │   └── car_owner_dashboard_screen.dart # Fleet revenue stats, "List My Car" dialog modal
│       ├── admin/
│       │   ├── admin_dashboard_screen.dart # System overview, Driver KYC verification, MySQL ERD schema
│       │   └── blueprint_inspector_screen.dart # DriveMate architecture diagram viewer, flows, integrations
│       └── notifications/
│           └── notification_center_screen.dart # Notification feed with read/unread indicators
├── assets/
│   └── images/
│       └── blueprint_diagram.jpeg         # Architectural blueprint diagram from AI Studio specification
├── test/
│   └── widget_test.dart                   # Unit and widget test suite
└── pubspec.yaml                           # Flutter dependencies (provider, intl, cupertino_icons)
```

---

## 💻 How to Run

### 1. Requirements
* Flutter SDK (3.24.x or higher)
* Dart SDK (3.5.x or higher)

### 2. Get Dependencies
```bash
flutter pub get
```

### 3. Run Analysis & Tests
```bash
flutter analyze
flutter test
```

### 4. Launch the App
* **Web (Chrome)**:
  ```bash
  flutter run -d chrome
  ```
* **Android Device / Emulator**:
  ```bash
  flutter run -d android
  ```
* **Windows Desktop**:
  ```bash
  flutter run -d windows
  ```
