import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final user = provider.currentUser;
    final isDark = AppColors.isDark(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final cardBg = AppColors.cardBgOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);
    final pageBg = AppColors.pageBgOf(context);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Avatar & Name (Matching Mockup Screen 8)
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: AppColors.blueGlowShadow,
                      border: Border.all(color: AppColors.primaryBlue, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/avatar_samiran.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: cardBg,
                          child: const Icon(Icons.person, size: 50, color: AppColors.primaryBlue),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.role.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Menu Items Card
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.softShadow,
                border: Border.all(color: borderSubtle),
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.person_outline_rounded,
                    title: 'Edit Profile',
                    onTap: () => _showEditProfileModal(context, provider),
                  ),
                  Divider(height: 1, indent: 56, color: borderSubtle),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    onTap: () => _showChangePasswordModal(context, provider),
                  ),
                  Divider(height: 1, indent: 56, color: borderSubtle),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'My Wallet',
                    trailingText: '₹',
                    onTap: () => provider.navigateTo(ActiveCustomerScreen.wallet),
                  ),
                  Divider(height: 1, indent: 56, color: borderSubtle),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.card_giftcard_rounded,
                    title: 'Offers & Rewards',
                    trailingText: '₹150 Bonus',
                    onTap: () => provider.navigateTo(ActiveCustomerScreen.offersRewards),
                  ),
                  Divider(height: 1, indent: 56, color: borderSubtle),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.notifications_none_rounded,
                    title: 'Notification Settings',
                    onTap: () => provider.navigateTo(ActiveCustomerScreen.notifications),
                  ),
                  Divider(height: 1, indent: 56, color: borderSubtle),
                  // Dark Mode Appearance Switch
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCardElevated : AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            provider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: provider.isDarkMode ? AppColors.accentCyan : AppColors.primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dark Mode',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                provider.isDarkMode ? 'Night surfaces active' : 'Daylight theme active',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: provider.isDarkMode,
                          activeColor: AppColors.electric,
                          onChanged: (_) => provider.toggleThemeMode(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, indent: 56, color: borderSubtle),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    onTap: () => provider.navigateTo(ActiveCustomerScreen.helpSupport),
                  ),
                  Divider(height: 1, indent: 56, color: borderSubtle),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    title: 'About DriveMate',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'DriveMate',
                        applicationVersion: 'v1.0.0 (3D Dark Edition)',
                        applicationLegalese: '© 2026 DriveMate Mobility Technologies Pvt. Ltd.',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button (Matching Mockup Screen 8: Red outlined button with logout icon)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => provider.logout(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.errorRed.withOpacity(0.6)),
                  backgroundColor: AppColors.errorRed.withOpacity(0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.errorRed, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: AppColors.errorRed,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);
    final itemBg = isDark ? AppColors.darkCardElevated : AppColors.bgSecondary;
    final textPrimary = AppColors.textPrimaryOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: itemBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentCyan,
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showEditProfileModal(BuildContext context, DriveMateProvider provider) {
    final user = provider.currentUser;
    final modalBg = AppColors.cardBgOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final inputFill = AppColors.inputFillOf(context);
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phone);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: modalBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Update your verified personal details',
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Name Field
                    TextFormField(
                      controller: nameController,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: inputFill,
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter your name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Email Field
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: inputFill,
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter your email';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Phone Field
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: inputFill,
                        prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter your phone number';
                        final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                        if (clean.length < 10) return 'Must be at least 10 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSaving = true);
                                final ok = await provider.updateUserProfile(
                                  name: nameController.text.trim(),
                                  email: emailController.text.trim(),
                                  phone: phoneController.text.trim(),
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChangePasswordModal(BuildContext context, DriveMateProvider provider) {
    final modalBg = AppColors.cardBgOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final inputFill = AppColors.inputFillOf(context);
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: modalBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Secure your DriveMate account credentials',
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Current Password
                    TextFormField(
                      controller: currentPassController,
                      obscureText: obscureCurrent,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        labelStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: inputFill,
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryBlue),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter your current password';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // New Password
                    TextFormField(
                      controller: newPassController,
                      obscureText: obscureNew,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'New Password (min 6 characters)',
                        labelStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: inputFill,
                        prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppColors.primaryBlue),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setModalState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter a new password';
                        if (val.length < 6) return 'Must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Confirm New Password
                    TextFormField(
                      controller: confirmPassController,
                      obscureText: obscureConfirm,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        labelStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: inputFill,
                        prefixIcon: const Icon(Icons.check_circle_outline, color: AppColors.primaryBlue),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Confirm your new password';
                        if (val != newPassController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSaving = true);
                                final ok = await provider.changePassword(
                                  currentPassword: currentPassController.text,
                                  newPassword: newPassController.text,
                                  confirmPassword: confirmPassController.text,
                                );
                                if (ctx.mounted && ok) {
                                  Navigator.pop(ctx);
                                } else {
                                  setModalState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
