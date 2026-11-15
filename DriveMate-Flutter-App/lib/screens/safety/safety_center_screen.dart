import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';
import '../../helpers/phone_dialer_helper.dart';

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});

  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriveMateProvider>().fetchEmergencyContacts();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerSos(DriveMateProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final alertCardBg = AppColors.cardBgOf(ctx);
        final alertTextPrimary = AppColors.textPrimaryOf(ctx);
        final alertTextSecondary = AppColors.textSecondaryOf(ctx);
        return AlertDialog(
          backgroundColor: alertCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Activate SOS Emergency?',
                  style: TextStyle(color: alertTextPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            'This will instantly dispatch your live GPS location and ride details to the Police (112), your registered emergency contacts, and the DriveMate 24/7 Safety Command Center.',
            style: TextStyle(color: alertTextSecondary, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final result = await provider.triggerSosEmergency();
                if (!mounted) return;
                if (result != null) {
                  _showSosResultModal(context, result);
                }
              },
              child: const Text('CONFIRM EMERGENCY SOS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSosResultModal(BuildContext context, SafetySosDispatchResult result) {
    final cardBg = AppColors.cardBgOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: borderSubtle),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.errorRed, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOS DISPATCHED • #${result.incidentId}',
                          style: const TextStyle(
                            color: AppColors.errorRed,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${result.contactsAlertedCount} Contacts Alerted • Police Notified',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      result.status,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardElevatedOf(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
                ),
                child: Text(
                  result.dispatchMessage,
                  style: TextStyle(color: textPrimary, fontSize: 13, height: 1.4),
                ),
              ),

              // Live GPS Location Link Card
              if (result.googleMapsLink != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardElevatedOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.errorRed, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live GPS Coordinates & Link:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: textPrimary),
                            ),
                            Text(
                              result.googleMapsLink!,
                              style: const TextStyle(fontSize: 11, color: AppColors.electric),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 14, color: AppColors.electric),
                        label: const Text('MAP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.electric)),
                        onPressed: () async {
                          final uri = Uri.parse(result.googleMapsLink!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // Contacts Alert Delivery Status List
              if (result.contactsNotified.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Contacts Alert Delivery Status:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                ),
                const SizedBox(height: 8),
                ...result.contactsNotified.map((c) {
                  final isSent = c['status'] == 'SENT';
                  final statusColor = isSent ? AppColors.successGreen : AppColors.warningAmber;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardElevatedOf(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Icon(isSent ? Icons.check_circle : Icons.info_outline, color: statusColor, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${c['name'] ?? 'Contact'} (${c['phone_masked'] ?? c['phone'] ?? ''})',
                            style: TextStyle(fontSize: 12, color: textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isSent ? 'SMS SENT' : 'STANDBY',
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // Device Messaging Fallback Action
              if (!result.smsGatewayActive && result.contactsNotified.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warningAmber.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backend SMS Gateway in standby/offline mode. Tap below to send this emergency SOS with live GPS link directly via your phone messaging app.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.warningAmber, height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warningAmber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.sms_rounded, size: 16),
                          label: const Text('DISPATCH VIA PHONE SMS APP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () async {
                            final phones = result.contactsNotified
                                .map((c) => c['phone']?.toString() ?? '')
                                .where((p) => p.isNotEmpty)
                                .join(',');
                            final uri = Uri(
                              scheme: 'sms',
                              path: phones,
                              queryParameters: {'body': result.dispatchMessage},
                            );
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (result.instructions.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Safety Actions:', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...result.instructions.map((inst) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(inst, style: TextStyle(color: textSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.call, size: 18),
                      label: Text('CALL POLICE ${result.policeHelpline}'),
                      onPressed: () => PhoneDialerHelper.makePhoneCall(context, result.policeHelpline),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentCyan,
                        side: const BorderSide(color: AppColors.accentCyan),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.headset_mic_rounded, size: 18),
                      label: const Text('CONTROL ROOM'),
                      onPressed: () => PhoneDialerHelper.makePhoneCall(context, result.controlRoom),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareTripModal(BuildContext context, DriveMateProvider provider, Trip trip) async {
    final shareData = await provider.shareLiveTrip(trip.id);
    final bookingRef = shareData?['booking_reference'] ?? 'DM-BK-${trip.bookingId}';
    final shareUrl = shareData?['share_url'] ?? 'https://drivemate.app/track/$bookingRef';

    if (!context.mounted) return;
    final isDark = AppColors.isDark(context);
    final sheetBg = isDark ? AppColors.darkCardBg : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;
    final cardInner = isDark ? AppColors.darkCardElevated : AppColors.lightPage;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Share Live Trip with Family', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Trip with ${trip.driverName} • ${trip.vehicleModel}', style: const TextStyle(color: AppColors.accentCyan, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cardInner, borderRadius: BorderRadius.circular(12)),
              child: SelectableText(shareUrl, style: TextStyle(color: textSecondary, fontSize: 12)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('COPY & SHARE TRACKING LINK', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  provider.showToast('Live tracking link copied to clipboard!');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddContactSheet(BuildContext context, DriveMateProvider provider) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String relationship = 'Family';
    bool notifyOnTrip = true;

    final isDark = AppColors.isDark(context);
    final sheetBg = isDark ? AppColors.darkCardBg : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;
    final cardInner = isDark ? AppColors.darkCardElevated : AppColors.lightPage;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Emergency Contact',
                      style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Emergency contacts will receive your live GPS coordinates during trips and in emergencies.',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Contact Full Name',
                    labelStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: cardInner,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.accentCyan),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: '10-Digit Mobile Number',
                    labelStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: cardInner,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.accentCyan),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: relationship,
                  dropdownColor: sheetBg,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Relationship',
                    labelStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: cardInner,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Family', child: Text('Family Member')),
                    DropdownMenuItem(value: 'Spouse', child: Text('Spouse / Partner')),
                    DropdownMenuItem(value: 'Parent', child: Text('Parent / Guardian')),
                    DropdownMenuItem(value: 'Friend', child: Text('Trusted Friend')),
                    DropdownMenuItem(value: 'Colleague', child: Text('Colleague / Work')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setSheetState(() => relationship = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Notify automatically on trip start', style: TextStyle(color: textPrimary, fontSize: 13)),
                  subtitle: const Text('Sends a safe tracking link with driver & car details', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  value: notifyOnTrip,
                  activeColor: AppColors.accentCyan,
                  onChanged: (val) => setSheetState(() => notifyOnTrip = val),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      if (name.isEmpty || phone.length < 10) {
                        provider.showToast('Please enter a valid full name and 10-digit phone number');
                        return;
                      }
                      Navigator.pop(ctx);
                      await provider.addEmergencyContact(name, phone, relationship, notifyOnTrip: notifyOnTrip);
                    },
                    child: const Text('SAVE EMERGENCY CONTACT', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReportIssueSheet(BuildContext context, DriveMateProvider provider) {
    String selectedCategory = 'Route Deviation';
    final descCtrl = TextEditingController();

    final isDark = AppColors.isDark(context);
    final sheetBg = isDark ? AppColors.darkCardBg : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;
    final cardInner = isDark ? AppColors.darkCardElevated : AppColors.lightPage;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Report Safety Issue',
                      style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Our rapid safety response team reviews all passenger incident reports immediately.',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text('Incident Category', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Route Deviation',
                    'Driver Misbehavior',
                    'Rash Driving',
                    'Vehicle Breakdown',
                    'Medical Issue',
                  ].map((cat) {
                    final isSel = selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : textSecondary)),
                      selected: isSel,
                      selectedColor: AppColors.primaryBlue,
                      backgroundColor: cardInner,
                      onSelected: (val) {
                        if (val) setSheetState(() => selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Describe what happened in detail...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: cardInner,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final desc = descCtrl.text.trim();
                      if (desc.isEmpty) {
                        provider.showToast('Please provide details of the safety concern');
                        return;
                      }
                      Navigator.pop(ctx);
                      await provider.reportSafetyIssue(category: selectedCategory, description: desc);
                    },
                    child: const Text('SUBMIT INCIDENT REPORT', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final activeTrip = provider.activeTrip;
    final contacts = provider.emergencyContacts;

    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;
    final pageBg = isDark ? AppColors.darkBg : AppColors.page;
    final cardBg = isDark ? AppColors.darkCardBg : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppColors.accentCyan, size: 22),
            const SizedBox(width: 8),
            Text(
              'Safety Center',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.successGreen.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: AppColors.successGreen, size: 14),
                SizedBox(width: 4),
                Text('24/7 Monitored', style: TextStyle(color: AppColors.successGreen, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ACTIVE TRIP SAFETY TELEMETRY CARD (if trip active)
            if (activeTrip != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryBlue.withOpacity(0.15), AppColors.accentCyan.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ACTIVE TRIP MONITORED',
                          style: TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.cardBg,
                          child: Icon(Icons.person, color: AppColors.accentCyan),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(activeTrip.driverName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                              const Text('Assigned Verified Chauffeur', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_location_rounded, color: AppColors.accentCyan),
                          tooltip: 'Share Live Trip',
                          onPressed: () {
                            _showShareTripModal(context, provider, activeTrip);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ONE-TOUCH HIGH-IMPACT SOS EMERGENCY BUTTON
            Center(
              child: Column(
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.errorRed.withOpacity(0.35),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _triggerSos(provider),
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.sos_rounded, color: Colors.white, size: 48),
                                SizedBox(height: 4),
                                Text(
                                  'SOS ALERT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'One-Touch Emergency SOS',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dispatches live GPS to Police 112 & your registered contacts',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // EMERGENCY HELPLINES GRID (2x2)
            Text(
              'Rapid Helplines',
              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildHelplineCard(
                  title: 'Police Emergency',
                  number: '112',
                  icon: Icons.local_police_rounded,
                  color: AppColors.errorRed,
                  onTap: () => PhoneDialerHelper.makePhoneCall(context, '112'),
                ),
                _buildHelplineCard(
                  title: 'Medical / Ambulance',
                  number: '108',
                  icon: Icons.medical_services_rounded,
                  color: AppColors.warningAmber,
                  onTap: () => PhoneDialerHelper.makePhoneCall(context, '108'),
                ),
                _buildHelplineCard(
                  title: 'Women Helpline',
                  number: '1091',
                  icon: Icons.shield_rounded,
                  color: AppColors.accentCyan,
                  onTap: () => PhoneDialerHelper.makePhoneCall(context, '1091'),
                ),
                _buildHelplineCard(
                  title: 'DriveMate 24/7 Desk',
                  number: '+91 99999 99999',
                  icon: Icons.headset_mic_rounded,
                  color: AppColors.primaryBlue,
                  onTap: () => PhoneDialerHelper.makePhoneCall(context, '+919999999999'),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // TRUSTED EMERGENCY CONTACTS SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trusted Contacts',
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${contacts.length}/5 Registered Contacts',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                if (contacts.length < 5)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentCyan,
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _showAddContactSheet(context, provider),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (contacts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderSubtle),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.contact_phone_outlined, color: AppColors.textMuted, size: 36),
                    const SizedBox(height: 10),
                    Text('No Emergency Contacts Added', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Add family members so they receive your live trip status.', textAlign: TextAlign.center, style: TextStyle(color: textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('Add First Contact'),
                      onPressed: () => _showAddContactSheet(context, provider),
                    ),
                  ],
                ),
              )
            else
              ...contacts.map((contact) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
                      child: Text(
                        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : 'C',
                        style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  contact.name,
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentCyan.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(contact.relationship, style: const TextStyle(color: AppColors.accentCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(contact.phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone_outlined, color: AppColors.successGreen, size: 20),
                      tooltip: 'Call Contact',
                      onPressed: () => PhoneDialerHelper.makePhoneCall(context, contact.phone),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.errorRed, size: 20),
                      tooltip: 'Remove Contact',
                      onPressed: () => provider.deleteEmergencyContact(contact.id),
                    ),
                  ],
                ),
              )),
            const SizedBox(height: 24),

            // REPORT ISSUE & SAFETY GUIDELINES
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.report_problem_outlined, color: AppColors.warningAmber, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Report a Ride Safety Issue',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warningAmber,
                          side: const BorderSide(color: AppColors.warningAmber),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => _showReportIssueSheet(context, provider),
                        child: const Text('Report Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.borderSubtle),
                  const SizedBox(height: 8),
                  const Text('DriveMate Safety Guarantees:', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  _buildGuidelineItem('Verified Chauffeurs with background checks and commercial badges.'),
                  _buildGuidelineItem('Live GPS Route Deviation tracking with automatic control-room alerts.'),
                  _buildGuidelineItem('Phone Number Masking protects your personal contact privacy.'),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHelplineCard({
    required String title,
    required String number,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    number,
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.accentCyan, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
