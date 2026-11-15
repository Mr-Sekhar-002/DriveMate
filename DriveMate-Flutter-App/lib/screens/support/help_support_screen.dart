import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../helpers/phone_dialer_helper.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DriveMateProvider>();
      provider.fetchFaqsAndContact();
      provider.fetchMyTickets();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final contact = provider.supportContact;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        backgroundColor: AppColors.navy900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Support',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              '24x7 Assistance & Support Center',
              style: TextStyle(fontSize: 11, color: AppColors.cyanAccent),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.cyanAccent,
          indicatorWeight: 3,
          labelColor: AppColors.cyanAccent,
          unselectedLabelColor: AppColors.textSecondaryLight,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            const Tab(
              icon: Icon(Icons.quiz_outlined, size: 20),
              text: 'FAQs & Guide',
            ),
            Tab(
              icon: const Icon(Icons.history_edu, size: 20),
              text: 'My Requests (${provider.myTickets.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: FAQs & Contact Support
          _buildFaqsAndContactTab(provider, contact),

          // TAB 2: Support Request History
          _buildTicketsHistoryTab(provider),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.cyanAccent,
        foregroundColor: AppColors.navy900,
        elevation: 4,
        onPressed: () => _openCreateTicketDialog(context, provider),
        icon: const Icon(Icons.add_comment, size: 20),
        label: const Text('Report a Problem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  // ─── TAB 1: FAQS & CONTACT OPTIONS ──────────────────────────────────────────
  Widget _buildFaqsAndContactTab(DriveMateProvider provider, SupportContact? contact) {
    final faqs = provider.faqs;
    final filteredFaqs = faqs.where((faq) {
      final matchesCategory = _selectedCategory == 'all' || faq.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesQuery = _searchQuery.isEmpty ||
          faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq.answer.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    return RefreshIndicator(
      color: AppColors.cyanAccent,
      backgroundColor: const Color(0xFF0D233A),
      onRefresh: () async {
        await provider.fetchFaqsAndContact();
        await provider.fetchMyTickets();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 24x7 Quick Assistance Action Cards
            _buildContactStrip(contact),

            const SizedBox(height: 18),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F253F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search help topics (e.g. fare, OTP, refund)...',
                  hintStyle: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: AppColors.cyanAccent, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),
            ),

            const SizedBox(height: 14),

            // Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('all', 'All Topics'),
                  _buildCategoryChip('booking', 'Booking Support'),
                  _buildCategoryChip('payment', 'Payment & Invoice'),
                  _buildCategoryChip('trip', 'Trip & Live Route'),
                  _buildCategoryChip('driver', 'Driver & Safety'),
                  _buildCategoryChip('app', 'App / General'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'FREQUENTLY ASKED QUESTIONS',
                  style: TextStyle(
                    color: AppColors.cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${filteredFaqs.length} Articles',
                  style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // FAQs List
            if (filteredFaqs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F253F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.help_outline, color: AppColors.textSecondaryLight, size: 40),
                    const SizedBox(height: 10),
                    const Text(
                      'No matching articles found',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Have an urgent issue? Tap "Report a Problem" to connect with our operations desk.',
                      style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyanAccent,
                        foregroundColor: AppColors.navy900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _openCreateTicketDialog(context, provider),
                      icon: const Icon(Icons.add_comment, size: 16),
                      label: const Text('Contact Support Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              )
            else
              ...filteredFaqs.map((faq) => _buildFaqTile(faq)),

            const SizedBox(height: 80), // Padding for FAB
          ],
        ),
      ),
    );
  }

  // ─── CONTACT STRIP ──────────────────────────────────────────────────────────
  Widget _buildContactStrip(SupportContact? contact) {
    final helpline = contact?.helpline ?? '+91 98000 11223';
    final tollFree = contact?.tollFree ?? '1800-DRIVEMATE';
    final emergency = contact?.emergency ?? '112';
    final email = contact?.email ?? 'support@drivemate.com';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D233A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cyanAccent.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanAccent.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.headset_mic, color: AppColors.cyanAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Direct Operational Channels',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Live assistance available 24x7 for customers and chauffeurs across Kakdwip and Bengal.',
            style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // 24x7 Phone Helpline
              Expanded(
                child: _buildContactButton(
                  icon: Icons.phone_in_talk,
                  label: '24x7 Helpline',
                  subtitle: tollFree,
                  color: AppColors.cyanAccent,
                  textColor: AppColors.navy900,
                  onTap: () => PhoneDialerHelper.makePhoneCall(context, helpline),
                ),
              ),
              const SizedBox(width: 10),
              // Emergency SOS
              Expanded(
                child: _buildContactButton(
                  icon: Icons.emergency,
                  label: 'SOS Helpline',
                  subtitle: emergency,
                  color: const Color(0xFFEF4444),
                  textColor: Colors.white,
                  onTap: () => PhoneDialerHelper.makePhoneCall(context, emergency),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Email Support
          InkWell(
            onTap: () async {
              final uri = Uri(scheme: 'mailto', path: email, query: 'subject=DriveMate Support Request');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Email: $email',
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Text('Send Email >', style: TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: textColor.withOpacity(0.85), fontSize: 10, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String categoryKey, String label) {
    final isSelected = _selectedCategory == categoryKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.navy900 : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        selectedColor: AppColors.cyanAccent,
        backgroundColor: const Color(0xFF0F253F),
        side: BorderSide(color: isSelected ? AppColors.cyanAccent : Colors.white12),
        onSelected: (val) {
          if (val) setState(() => _selectedCategory = categoryKey);
        },
      ),
    );
  }

  Widget _buildFaqTile(SupportFaq faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F253F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.cyanAccent,
          collapsedIconColor: Colors.white54,
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.cyanAccent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_getCategoryIcon(faq.category), color: AppColors.cyanAccent, size: 16),
          ),
          title: Text(
            faq.question,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Text(
                faq.answer,
                style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12.5, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2: SUPPORT TICKETS HISTORY ─────────────────────────────────────────
  Widget _buildTicketsHistoryTab(DriveMateProvider provider) {
    final tickets = provider.myTickets;

    return RefreshIndicator(
      color: AppColors.cyanAccent,
      backgroundColor: const Color(0xFF0D233A),
      onRefresh: () => provider.fetchMyTickets(),
      child: provider.isLoadingSupport && tickets.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.cyanAccent),
            )
          : tickets.isEmpty
              ? _buildEmptyTicketsView(provider)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return _buildTicketCard(ticket);
                  },
                ),
    );
  }

  Widget _buildEmptyTicketsView(DriveMateProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cyanAccent.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cyanAccent.withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(Icons.inbox, color: AppColors.cyanAccent, size: 40),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Support Requests Yet',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Whenever you report an issue with a ride, chauffeur, invoice, or app feature, your tracking history and admin replies will appear here.',
              style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12.5, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: AppColors.navy900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => _openCreateTicketDialog(context, provider),
              icon: const Icon(Icons.add_comment, size: 18),
              label: const Text('Submit a Support Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    final statusColor = switch (ticket.status.toLowerCase()) {
      'resolved' => AppColors.successGreen,
      'in_progress' => AppColors.cyanAccent,
      'closed' => Colors.grey,
      _ => const Color(0xFFF59E0B), // open
    };

    final statusLabel = switch (ticket.status.toLowerCase()) {
      'resolved' => 'RESOLVED',
      'in_progress' => 'IN PROGRESS',
      'closed' => 'CLOSED',
      _ => 'OPEN',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F253F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: ID, Category & Status Pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#TKT-${ticket.id}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ticket.category.toUpperCase(),
                  style: const TextStyle(color: AppColors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Subject
          Text(
            ticket.subject,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          // Message
          Text(
            ticket.message,
            style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12.5, height: 1.4),
          ),

          // Attached Booking Reference (if available)
          if (ticket.bookingId != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, color: AppColors.cyanAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking #${ticket.bookingId}${ticket.pickupLocation != null ? ' • ${ticket.pickupLocation} to ${ticket.destination}' : ''}${ticket.totalAmount != null ? ' • ₹${ticket.totalAmount!.toInt()}' : ''}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Admin Reply Section (if present)
          if (ticket.adminReply != null && ticket.adminReply!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.support_agent, color: AppColors.successGreen, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'DriveMate Support Desk Resolution',
                        style: TextStyle(color: AppColors.successGreen, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ticket.adminReply!,
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(color: Colors.white10),
          const SizedBox(height: 4),

          // Created At Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Submitted: ${ticket.createdAt}',
                style: const TextStyle(color: Colors.grey, fontSize: 10.5),
              ),
              if (ticket.resolvedAt != null)
                Text(
                  'Resolved: ${ticket.resolvedAt}',
                  style: const TextStyle(color: AppColors.successGreen, fontSize: 10.5),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── CREATE SUPPORT TICKET MODAL ────────────────────────────────────────────
  void _openCreateTicketDialog(BuildContext context, DriveMateProvider provider) {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String selectedCategory = 'booking';
    int? selectedBookingId;

    // Filter available bookings for attachment
    final userBookings = provider.bookings;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Color(0xFF0D233A),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Report a Problem / Support Request',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const Text(
                  'Your request will be routed directly to our 24x7 operations dispatch desk.',
                  style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                ),
                const SizedBox(height: 18),

                // Category Dropdown
                const Text('ISSUE CATEGORY', style: TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F253F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      dropdownColor: const Color(0xFF0F253F),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'booking', child: Text('Booking Assistance / Schedule')),
                        DropdownMenuItem(value: 'payment', child: Text('Payment & Invoice Support')),
                        DropdownMenuItem(value: 'trip', child: Text('Trip & Live Navigation Route')),
                        DropdownMenuItem(value: 'driver', child: Text('Driver / Chauffeur Service')),
                        DropdownMenuItem(value: 'vehicle', child: Text('Vehicle Condition / Rental')),
                        DropdownMenuItem(value: 'app', child: Text('App Issue / Technical Bug')),
                        DropdownMenuItem(value: 'other', child: Text('Other Inquiry')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCategory = val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Optional Booking Selector
                if (userBookings.isNotEmpty) ...[
                  const Text('ATTACH RELEVANT BOOKING (OPTIONAL)', style: TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F253F),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: selectedBookingId,
                        dropdownColor: const Color(0xFF0F253F),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        hint: const Text('None / General Inquiry', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('None / General Inquiry'),
                          ),
                          ...userBookings.map((b) {
                            final bId = int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
                            return DropdownMenuItem<int?>(
                              value: bId,
                              child: Text(
                                '#${b.id} • ${b.pickupLocation} (${b.status})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setModalState(() => selectedBookingId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Subject Field
                const Text('SUBJECT', style: TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F253F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: subjectCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Brief summary of the issue...',
                      hintStyle: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Description Field
                const Text('DETAILED DESCRIPTION', style: TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F253F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: messageCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Describe what happened, location details, or error encountered...',
                      hintStyle: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyanAccent,
                      foregroundColor: AppColors.navy900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final subject = subjectCtrl.text.trim();
                      final message = messageCtrl.text.trim();
                      if (subject.isEmpty || message.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter both subject and message description.'),
                            backgroundColor: AppColors.errorRed,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(modalCtx);
                      final success = await provider.createSupportTicket(
                        subject: subject,
                        category: selectedCategory,
                        message: message,
                        bookingId: selectedBookingId,
                      );

                      if (success && mounted) {
                        _tabController.animateTo(1);
                      }
                    },
                    child: const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    return switch (category.toLowerCase()) {
      'booking' => Icons.calendar_month,
      'payment' => Icons.account_balance_wallet,
      'trip' => Icons.navigation,
      'driver' => Icons.person_pin,
      'vehicle' => Icons.directions_car,
      'app' => Icons.phone_android,
      _ => Icons.help_outline,
    };
  }
}
