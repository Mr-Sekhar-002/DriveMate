# 🚗 DriveMate — Product Requirements Document (PRD)

**Version:** 2.0  
**Status:** In Development / MVP Verified  
**Target Market:** Pan-India (All Metropolitan & Tier-2/3 Cities)  
**Primary Tech Stack:** PHP 8.2 (REST API) + MySQL 8.0 + Flutter 3.24 (Dart) + OpenStreetMap / Google Maps  

---

## 1. Executive Summary & Problem Statement

### The Problem
In India, vehicle owners and commuters face three fragmented challenges:
1. **Chauffeur Availability:** Finding verified, background-checked professional drivers on an on-demand hourly or daily basis is difficult, unorganized, and unreliable.
2. **Self-Drive Car Rental High Friction:** Traditional rental platforms impose heavy security deposits, delayed paperwork, and limited regional fleet availability.
3. **Automotive Glare & Road Distraction:** Most driver apps use bright white interfaces that cause severe glare and driver fatigue during night journeys.

### The Solution: DriveMate
DriveMate is a high-performance unified mobility platform offering:
* **On-Demand Chauffeur Hiring:** Verified professional drivers for personal cars (hourly, outstation, daily).
* **Self-Drive & Chauffeur-Driven Car Rentals:** Wide selection of vehicles with transparent pricing.
* **Cockpit Safety UI:** Automotive-grade dark theme (True Black `#000000`, High-Saturation Route Blue `#2979FF`, Neon Green `#00E676`) minimizing glare and driver distraction.
* **Pan-India Smart Routing:** Hybrid Google Routes API (v2) + OpenStreetMap OSRM fallback with real-time location autocomplete.
* **All-India Payment Suite:** Dynamic UPI QR Code, Cash on Delivery, In-App Digital Wallet, and Razorpay with itemized 5% GST tax invoices.

---

## 2. User Personas

| Persona | Role | Key Needs |
|---|---|---|
| **Passenger / Car Owner** | Customer | Fast booking, transparent pricing, verified drivers with KYC, instant UPI/Cash payments, safety SOS. |
| **Professional Driver** | Chauffeur | Fair 85% revenue share, flexible online/offline toggle, clear turn-by-turn navigation, cash collection logging. |
| **Fleet / Car Owner** | Partner | List vehicles, approve rental requests, track bookings and vehicle availability, withdraw earnings. |
| **System Admin** | Administrator | Real-time analytics, user & driver verification, support ticket resolution, dynamic pricing settings. |

---

## 3. Core Feature Specifications

### 3.1 Authentication & KYC
* JWT HS256 stateless session management with bcrypt-hashed passwords.
* Multi-role support (`customer`, `driver`, `owner`, `admin`).
* Document upload module for Aadhaar, Driving License, RC, and Insurance.

### 3.2 Live Mapping & Routing
* Real-time location autocomplete with Google Places API + OpenStreetMap Nominatim.
* Dynamic driving distance & duration calculation using Google Routes v2 with OSRM fallback.
* Accurate fare estimator based on base fare, per-kilometer rate, and driver allowance.

### 3.3 Multi-Method Payment Gateway
* **UPI Dynamic QR Code:** Generates NPCI-compliant deep-link (`upi://pay?...`) and instant QR code for Google Pay, PhonePe, Paytm, and BHIM.
* **Cash on Delivery:** Direct driver cash collection with 1-click status sync.
* **In-App Digital Wallet:** Instant top-up, 1-click booking payment, and automatic refund ledger.
* **Itemized GST Tax Invoice:** Generates compliant invoice with 5% GST (2.5% CGST + 2.5% SGST), driver profile, and trip summary.

---

## 4. Success Metrics & KPIs
* **API Latency:** < 250ms response time on all core REST endpoints.
* **Driver Dispatch Efficiency:** Driver matching confirmation in under 60 seconds.
* **Payment Reliability:** 99.9% payment reconciliation rate across UPI, Cash, and Wallet.
* **Zero Zero-Day Exposure:** Strict `.env` isolation and parameterized SQL queries.
