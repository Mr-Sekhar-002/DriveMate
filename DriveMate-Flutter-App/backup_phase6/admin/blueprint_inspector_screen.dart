import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class BlueprintInspectorScreen extends StatelessWidget {
  const BlueprintInspectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Architecture & Blueprint ERD', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('DriveMate Specification Inspector', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Architectural Overview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navy900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_tree, color: AppColors.cyanAccent, size: 24),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DriveMate Blueprint Specifications',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Your Car. Your Driver. Anytime.',
                            style: TextStyle(color: AppColors.cyanAccent, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.white.withOpacity(0.12)),
                  const SizedBox(height: 8),
                  const Text(
                    'Core Pillars from Architectural Diagram:',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  _buildBullet('One App: Customer, Driver, and Car Owner unified in one Flutter reactive client'),
                  _buildBullet('Seamless Ride: Real-time GPS routing, OSRM engine, OTP verification & instant payouts'),
                  _buildBullet('Backend Services: PHP REST API service layer with MySQL relational storage & ERD'),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Blueprint Architecture Diagram Image Viewer
            const Text(
              'Architectural Blueprint Diagram',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
            ),
            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.navy900,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.electricBlue.withOpacity(0.3)),
                ),
                child: Image.asset(
                  'assets/images/blueprint_diagram.jpeg',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 160,
                      color: AppColors.navy900,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, color: AppColors.cyanAccent, size: 36),
                            SizedBox(height: 8),
                            Text('Blueprint Diagram Loaded', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3 Core Business Flows
            const Text(
              'The 3 Key Business Flows (from Blueprint)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
            ),
            const SizedBox(height: 10),

            _buildFlowCard(
              title: 'Flow 1: Hire a Driver (Customer owns car)',
              steps: 'Select Hire a Driver → Book Driver (choose date/time & customer car) → Driver arrives & drives your car → Trip completed & rate driver.',
              color: AppColors.cyanLight,
              borderColor: AppColors.cyanAccent,
            ),
            const SizedBox(height: 8),
            _buildFlowCard(
              title: 'Flow 2: Rent a Car (Self-Drive)',
              steps: 'Search available cars → Book car (select rental dates) → Pick up car (from owner station) → Return car & close booking.',
              color: const Color(0xFFFEF3C7),
              borderColor: AppColors.accentGold,
            ),
            const SizedBox(height: 8),
            _buildFlowCard(
              title: 'Flow 3: Rent Car + Driver',
              steps: 'Search cars with driver → Book chauffeur package (select dates & destination) → Driver + Car arrives → Trip completed.',
              color: const Color(0xFFEDE9FE),
              borderColor: const Color(0xFF8B5CF6),
            ),

            const SizedBox(height: 20),

            // External Integrations
            const Text(
              'External Integrations Architecture',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
            ),
            const SizedBox(height: 10),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildIntegrationItem('Google Maps & OSRM', 'GPS live tracking, route polyline calculation & geocoding'),
                    const Divider(height: 14),
                    _buildIntegrationItem('Firebase FCM', 'Push alerts for driver arrival, bookings & status updates'),
                    const Divider(height: 14),
                    _buildIntegrationItem('Razorpay & Cashfree', 'Secure payments, UPI intent, and instant refund processing'),
                    const Divider(height: 14),
                    _buildIntegrationItem('SMS Gateway', 'SMS OTP verification and critical trip telemetry alerts'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Database ERD Schema Details
            const Text(
              'MySQL ERD Database Schema (10 Entities)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
            ),
            const SizedBox(height: 10),

            ..._tables.map((t) {
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['tbl']!, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.electricBlue, fontSize: 13.5)),
                      const SizedBox(height: 4),
                      Text(t['cols']!, style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimaryDark)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  static Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11.5))),
        ],
      ),
    );
  }

  static Widget _buildFlowCard({
    required String title,
    required String steps,
    required Color color,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.navy900)),
          const SizedBox(height: 4),
          Text(steps, style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimaryDark)),
        ],
      ),
    );
  }

  static Widget _buildIntegrationItem(String name, String details) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: AppColors.successGreen, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy900)),
              Text(details, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  static final List<Map<String, String>> _tables = [
    {'tbl': 'users', 'cols': 'id (PK), name, email, password, phone, role (customer/driver/owner/admin), status, created_at'},
    {'tbl': 'driver_profile', 'cols': 'id (PK), user_id (FK), license_number, vehicle_type, vehicle_model, vehicle_number, documents, status, created_at'},
    {'tbl': 'vehicles', 'cols': 'id (PK), owner_id (FK), type, model, number_plate, color, capacity, status, created_at'},
    {'tbl': 'car_listings', 'cols': 'id (PK), owner_id (FK), vehicle_id (FK), vehicle_type, daily_rate, hourly_rate, description, status, available_from, available_to, created_at'},
    {'tbl': 'bookings', 'cols': 'id (PK), user_id (FK), driver_id (FK), vehicle_id (FK), car_listing_id (FK), booking_type, start_date, end_date, pickup_location, destination, total_amount, status, created_at'},
    {'tbl': 'trips', 'cols': 'id (PK), booking_id (FK), driver_id (FK), vehicle_id (FK), start_location, end_location, start_time, end_time, distance_km, fare, status, created_at'},
    {'tbl': 'payments', 'cols': 'id (PK), booking_id (FK), amount, payment_method, transaction_id, status, paid_at, refund_id, created_at'},
    {'tbl': 'reviews', 'cols': 'id (PK), user_id (FK), driver_id (FK), booking_id (FK), rating, comment, created_at'},
    {'tbl': 'documents', 'cols': 'id (PK), user_id (FK), type (dl/rc/insurance/kyc), file_url, status, verified_at, created_at'},
    {'tbl': 'notifications', 'cols': 'id (PK), user_id (FK), type (booking/payment/system), title, message, is_read, created_at'},
  ];
}
