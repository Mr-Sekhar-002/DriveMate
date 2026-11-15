import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final docs = provider.documents;
    final pendingCount = docs.where((d) => d.status == 'pending').length;

    return Column(
      children: [
        // Admin Command Header
        Container(
          width: double.infinity,
          color: AppColors.navy900,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: AppColors.cyanAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Admin Web Panel (PHP Backend)',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    'DriveMate Central Command & Database ERD',
                    style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.electricBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SYS ONLINE',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Tabs
        Container(
          color: AppColors.navy800,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.cyanAccent,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.cyanAccent,
            tabs: [
              const Tab(text: 'Dashboard'),
              Tab(text: 'Driver KYC ($pendingCount)'),
              const Tab(text: 'MySQL ERD'),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Dashboard Overview
              _buildOverviewTab(provider),

              // KYC Document Verification
              _buildKYCTab(provider),

              // MySQL ERD Entities
              _buildErdTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(DriveMateProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAdminMetricCard(
                  'Active Trips',
                  provider.activeTrip != null ? '1 Active' : '0 Active',
                  Icons.navigation,
                  AppColors.electricBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAdminMetricCard(
                  'Total Revenue',
                  '₹1,24,800',
                  Icons.currency_rupee,
                  AppColors.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildAdminMetricCard(
                  'Registered Users',
                  '4,821',
                  Icons.people,
                  AppColors.cyanAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAdminMetricCard(
                  'Fleet Listed',
                  '${provider.carListings.length} Vehicles',
                  Icons.directions_car,
                  AppColors.accentGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('System Services Health', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark)),
          const SizedBox(height: 10),
          _buildHealthRow('PHP REST API Server', 'v8.3 (Laravel / Lumen) • Responding 22ms', AppColors.successGreen),
          _buildHealthRow('OSRM Routing Engine', 'Graph Server • 99.98% Uptime', AppColors.successGreen),
          _buildHealthRow('Payment Gateway (Razorpay/Cashfree)', 'Webhooks Live • SSL 256-bit', AppColors.successGreen),
          _buildHealthRow('Firebase Cloud Messaging (FCM)', 'Push Channel Active', AppColors.successGreen),
        ],
      ),
    );
  }

  Widget _buildKYCTab(DriveMateProvider provider) {
    final docs = provider.documents;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final isPending = doc.status == 'pending';
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      doc.type.label,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy900),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        doc.status.toUpperCase(),
                        style: TextStyle(
                          color: isPending ? AppColors.accentGold : AppColors.successGreen,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Driver / Applicant: ${doc.userName} (Doc No: ${doc.documentNumber})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('File: ${doc.fileUrl}', style: const TextStyle(fontSize: 11, color: AppColors.electricBlue)),
                if (isPending) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.errorRed,
                          side: const BorderSide(color: AppColors.errorRed),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => provider.verifyDriverDocument(doc.id, false),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => provider.verifyDriverDocument(doc.id, true),
                        child: const Text('Approve & Verify'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErdTab() {
    final tables = [
      {'name': 'users', 'desc': 'id (PK), name, email, password, phone, role, status, created_at'},
      {'name': 'driver_profile', 'desc': 'id (PK), user_id (FK), license_number, vehicle_type, rating, trips, status'},
      {'name': 'vehicles', 'desc': 'id (PK), owner_id (FK), type, model, number_plate, color, capacity, status'},
      {'name': 'car_listings', 'desc': 'id (PK), owner_id (FK), vehicle_id (FK), rental_type, daily_rate, hourly_rate, status'},
      {'name': 'bookings', 'desc': 'id (PK), user_id (FK), driver_id (FK), vehicle_id (FK), booking_type, total_amount, status'},
      {'name': 'trips', 'desc': 'id (PK), booking_id (FK), driver_id (FK), distance_km, fare, status, created_at'},
      {'name': 'payments', 'desc': 'id (PK), booking_id (FK), amount, payment_method, transaction_id, status'},
      {'name': 'reviews', 'desc': 'id (PK), user_id (FK), driver_id (FK), rating, comment, created_at'},
      {'name': 'documents', 'desc': 'id (PK), user_id (FK), type, document_number, file_url, status'},
      {'name': 'notifications', 'desc': 'id (PK), user_id (FK), type, title, message, is_read, created_at'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final t = tables[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart, size: 16, color: AppColors.electricBlue),
                    const SizedBox(width: 8),
                    Text(
                      t['name']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.navy900),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(t['desc']!, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryDark)),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildAdminMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  static Widget _buildHealthRow(String service, String details, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: statusColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                Text(details, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
