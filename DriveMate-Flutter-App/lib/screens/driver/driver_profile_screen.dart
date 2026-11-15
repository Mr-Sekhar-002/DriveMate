import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final profile = provider.driverProfile;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        elevation: 0,
        title: const Text(
          'Driver Profile & KYC',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: AppColors.cyanAccent),
            tooltip: 'Edit Profile & Skills',
            onPressed: () => _showEditProfileSheet(context, provider, profile),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─── Verification Status Banner ────────────────────────────────
            _buildVerificationStatusBanner(context, provider, profile),
            const SizedBox(height: 16),

            // ─── Driver Profile Header Card ────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSubtle),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBlue.withOpacity(0.2),
                          border: Border.all(
                            color: profile.isVerified ? AppColors.successGreen : AppColors.primaryBlue,
                            width: 2.5,
                          ),
                          boxShadow: AppColors.blueGlowShadow,
                        ),
                        child: const Icon(Icons.person, color: AppColors.cyanAccent, size: 48),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: profile.isVerified ? AppColors.successGreen : (profile.isRejected ? AppColors.errorRed : Colors.amber),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          profile.isVerified ? Icons.verified : (profile.isRejected ? Icons.close : Icons.hourglass_top),
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile.driverName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.phone.isNotEmpty ? profile.phone : '+91 98112 23344',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${profile.rating > 0 ? profile.rating : 4.9} Rating (${profile.totalTrips} Completed Trips)',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Duty Status Switcher (Online / Offline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: profile.isOnline ? AppColors.successGreen : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              profile.isOnline ? 'DUTY ONLINE (Ready to Accept Trips)' : 'DUTY OFFLINE (Unavailable)',
                              style: TextStyle(
                                color: profile.isOnline ? AppColors.successGreen : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: profile.isOnline,
                          activeColor: AppColors.cyanAccent,
                          activeTrackColor: AppColors.primaryBlue.withOpacity(0.5),
                          onChanged: (val) => provider.toggleDriverOnline(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Professional Skills & Fleet Details Card ─────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Professional Credentials',
                        style: TextStyle(
                          color: AppColors.cyanAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      InkWell(
                        onTap: () => _showEditProfileSheet(context, provider, profile),
                        child: const Text(
                          'Edit Info',
                          style: TextStyle(color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildProfileRow(Icons.translate, 'Languages Spoken', profile.languages),
                  const Divider(color: AppColors.borderSubtle),
                  _buildProfileRow(Icons.work_history, 'Driving Experience', '${profile.experienceYears} Years Commercial Chauffeur'),
                  const Divider(color: AppColors.borderSubtle),
                  _buildProfileRow(Icons.directions_car, 'Vehicle Information', '${profile.vehicleModel} (${profile.vehicleNumber})'),
                  const Divider(color: AppColors.borderSubtle),
                  _buildProfileRow(Icons.payments, 'Hourly Chauffeur Fare', '₹${profile.hourlyRate.toStringAsFixed(0)} / hr'),
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    const Divider(color: AppColors.borderSubtle),
                    _buildProfileRow(Icons.notes, 'Chauffeur Bio', profile.bio!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── KYC Document Upload & Verification Section ───────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user, color: AppColors.cyanAccent, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'KYC Documents & Verification',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        profile.status.toUpperCase(),
                        style: TextStyle(
                          color: profile.isVerified ? AppColors.successGreen : (profile.isRejected ? AppColors.errorRed : Colors.amber),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Upload your Driving License and Government ID Proof. Confidential documents are protected and only accessible to authorized verification officers.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // 1. Driving License Tile
                  _buildKycDocTile(
                    context,
                    provider,
                    title: 'Driving License (DL)',
                    docNumber: profile.licenseNumber,
                    docPath: profile.licenseDocPath,
                    docType: 'license',
                    icon: Icons.badge,
                    profile: profile,
                  ),

                  const SizedBox(height: 12),

                  // 2. Identity Document Tile (Aadhaar / Voter / Passport)
                  _buildKycDocTile(
                    context,
                    provider,
                    title: 'Government Identity Proof (Aadhaar / Passport)',
                    docNumber: 'Verified Photo Identification',
                    docPath: profile.idDocPath,
                    docType: 'identity',
                    icon: Icons.credit_card,
                    profile: profile,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Admin Quick Status Switcher (Testing & Demo) ─────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: AppColors.cyanAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Administrative Verification Testbed',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Test KYC state transitions (Verified, Pending, Rejected) authoritative on server:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => provider.verifyDriverKycAdmin(driverId: int.tryParse(profile.id) ?? 3, status: 'verified'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.successGreen),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Verify ✓', style: TextStyle(color: AppColors.successGreen, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => provider.verifyDriverKycAdmin(driverId: int.tryParse(profile.id) ?? 3, status: 'pending'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.amber),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Pending ⌛', style: TextStyle(color: Colors.amber, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => provider.verifyDriverKycAdmin(
                            driverId: int.tryParse(profile.id) ?? 3,
                            status: 'rejected',
                            reason: 'Document photo blurry or expired. Please upload a clear color photo.',
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.errorRed),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Reject ✕', style: TextStyle(color: AppColors.errorRed, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Switch to Customer Mode Button ───────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => provider.switchRole(UserRole.customer),
                icon: const Icon(Icons.switch_account, color: AppColors.cyanAccent),
                label: const Text(
                  'Switch to Customer Mode',
                  style: TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cyanAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ─── Logout Button ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => provider.logout(),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed.withOpacity(0.85),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationStatusBanner(BuildContext context, DriveMateProvider provider, DriverProfile profile) {
    if (profile.isVerified) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.successGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.successGreen.withOpacity(0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified, color: AppColors.successGreen, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GOVERNMENT KYC VERIFIED CHAUFFEUR',
                    style: TextStyle(color: AppColors.successGreen, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your background check and driving license are verified. You are eligible for passenger bookings.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (profile.isRejected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.errorRed.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.errorRed, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KYC VERIFICATION REJECTED',
                    style: TextStyle(color: AppColors.errorRed, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.rejectionReason ?? 'Document unreadable or invalid. Please re-upload your driving license and ID.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_top, color: Colors.amber, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KYC VERIFICATION UNDER REVIEW',
                    style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your documents are under review by DriveMate Admin. Approvals typically take under 2 hours.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.cyanAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKycDocTile(
    BuildContext context,
    DriveMateProvider provider, {
    required String title,
    required String docNumber,
    required String? docPath,
    required String docType,
    required IconData icon,
    DriverProfile? profile,
  }) {
    final hasDoc = docPath != null && docPath.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDoc ? AppColors.successGreen.withOpacity(0.3) : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryBlue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasDoc ? AppColors.successGreen.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasDoc ? 'UPLOADED ✓' : 'ACTION REQUIRED',
                  style: TextStyle(
                    color: hasDoc ? AppColors.successGreen : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Reference: $docNumber',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (hasDoc) ...[
            const SizedBox(height: 4),
            Text(
              'File: $docPath',
              style: TextStyle(color: AppColors.cyanAccent.withOpacity(0.8), fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (hasDoc || docNumber != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showViewLicenseModal(context, title, docNumber, docPath, profile),
                    icon: const Icon(Icons.visibility_outlined, size: 15, color: AppColors.cyanAccent),
                    label: const Text('View Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cyanAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.cyanAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _uploadDocumentModal(context, provider, docType, title),
                  icon: Icon(hasDoc ? Icons.refresh : Icons.cloud_upload, size: 15),
                  label: Text(
                    hasDoc ? 'Replace' : 'Upload',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasDoc ? AppColors.bgDark : AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: hasDoc ? AppColors.cyanAccent.withOpacity(0.5) : Colors.transparent),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _uploadDocumentModal(BuildContext context, DriveMateProvider provider, String docType, String docTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload $docTitle',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a file format: JPG, PNG, or PDF (Max 5MB). Encrypted and stored safely.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.cyanAccent),
                title: const Text('Capture with Camera', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Take clear photo in bright lighting', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  // Generate base64 mock image bytes for verified KYC upload
                  final sampleBytes = utf8.encode('DRIVEMATE_KYC_DOC_DATA_${DateTime.now().millisecondsSinceEpoch}');
                  final b64 = base64Encode(sampleBytes);
                  provider.uploadDriverKycDocument(
                    docType: docType,
                    base64Data: b64,
                    fileName: '${docType}_scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primaryBlue),
                title: const Text('Upload from Gallery / Files', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Upload scanned PDF or JPG certificate', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  final sampleBytes = utf8.encode('DRIVEMATE_KYC_GALLERY_DOC_${DateTime.now().millisecondsSinceEpoch}');
                  final b64 = base64Encode(sampleBytes);
                  provider.uploadDriverKycDocument(
                    docType: docType,
                    base64Data: b64,
                    fileName: '${docType}_certified_${DateTime.now().millisecondsSinceEpoch}.png',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileSheet(BuildContext context, DriveMateProvider provider, DriverProfile profile) {
    final langCtrl = TextEditingController(text: profile.languages);
    final expCtrl = TextEditingController(text: '${profile.experienceYears}');
    final modelCtrl = TextEditingController(text: profile.vehicleModel);
    final numberCtrl = TextEditingController(text: profile.vehicleNumber);
    final rateCtrl = TextEditingController(text: '${profile.hourlyRate.toInt()}');
    final bioCtrl = TextEditingController(text: profile.bio ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Professional Profile',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField('Languages Spoken', langCtrl, 'e.g. English, Hindi, Bengali'),
                const SizedBox(height: 10),
                _buildTextField('Experience (Years)', expCtrl, 'e.g. 7', isNumber: true),
                const SizedBox(height: 10),
                _buildTextField('Vehicle Model', modelCtrl, 'e.g. Maruti Dzire VXI Commercial'),
                const SizedBox(height: 10),
                _buildTextField('Vehicle Registration Number', numberCtrl, 'e.g. WB 02 B 1234'),
                const SizedBox(height: 10),
                _buildTextField('Hourly Chauffeur Rate (₹/hr)', rateCtrl, 'e.g. 150', isNumber: true),
                const SizedBox(height: 10),
                _buildTextField('Chauffeur Bio & Specialty', bioCtrl, 'e.g. Punctual, non-smoker, experienced with night highway routes.', maxLines: 2),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final exp = int.tryParse(expCtrl.text.trim()) ?? profile.experienceYears;
                      final rate = double.tryParse(rateCtrl.text.trim()) ?? profile.hourlyRate;
                      provider.updateDriverProfileDetails(
                        languages: langCtrl.text.trim(),
                        experienceYears: exp,
                        vehicleModel: modelCtrl.text.trim(),
                        vehicleNumber: numberCtrl.text.trim(),
                        hourlyRate: rate,
                        bio: bioCtrl.text.trim(),
                      );
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyanAccent,
                      foregroundColor: AppColors.bgDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save Profile Updates', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint, {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            filled: true,
            fillColor: AppColors.cardBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderSubtle)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderSubtle)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cyanAccent)),
          ),
        ),
      ],
    );
  }

  void _showViewLicenseModal(
    BuildContext context,
    String title,
    String? docNumber,
    String? docPath,
    DriverProfile? profile,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.cyanAccent.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.badge_rounded, color: AppColors.cyanAccent, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Verified Digital License Card Preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F2B48), Color(0xFF1B4D7E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'UNION OF INDIA • DRIVING LICENCE',
                          style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        Icon(Icons.verified, color: AppColors.cyanAccent, size: 18),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 16),
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: const Icon(Icons.person, color: Colors.white70, size: 36),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.driverName ?? 'Commercial Chauffeur',
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'DL No: ${docNumber ?? profile?.licenseNumber ?? 'N/A'}',
                                style: const TextStyle(color: AppColors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Class: LMV-TR (Commercial Transport)',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status: VERIFIED & ACTIVE', style: TextStyle(color: const Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('Authority: WB RTO', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
