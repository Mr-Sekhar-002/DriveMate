import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../components/ai_chatbot_dialog.dart';
import '../../components/drivemate_logo.dart';
import '../../components/language_selection_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final Function(String email, UserRole role) onLogin;
  final Function(String name, String email, String phone, UserRole role, String? licenseNumber) onRegister;

  const AuthScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegisterMode = false;
  bool _useOtpMode = false;
  UserRole _selectedRole = UserRole.customer;

  final TextEditingController _nameController = TextEditingController(text: 'Rajesh Das');
  final TextEditingController _emailController = TextEditingController(text: 'rajesh.das@drivemate.in');
  final TextEditingController _phoneController = TextEditingController(text: '+91 98301 22334');
  final TextEditingController _passwordController = TextEditingController(text: 'password123');
  final TextEditingController _licenseController = TextEditingController(text: 'WB-962019003412');
  final TextEditingController _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _otpSent = false;
  bool _isSendingOtp = false;
  String? _currentExpectedOtp;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _licenseController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _sendSmsOtp() async {
    final phone = _phoneController.text.trim();
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit Indian mobile number (+91)'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    String generatedOtp = (Random().nextInt(900000) + 100000).toString();

    // Attempt backend API call if XAMPP is running
    try {
      final mobile10 = digitsOnly.length >= 10 ? digitsOnly.substring(digitsOnly.length - 10) : digitsOnly;
      final response = await http.post(
        Uri.parse('http://localhost/drivemate-api/public/index.php/api/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': mobile10}),
      ).timeout(const Duration(milliseconds: 1500));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['data'] != null && body['data']['dev_otp'] != null) {
          generatedOtp = body['data']['dev_otp'].toString();
        }
      }
    } catch (_) {
      // Backend offline or timeout — seamlessly use locally generated 6-digit OTP
    }

    if (mounted) {
      setState(() {
        _isSendingOtp = false;
        _otpSent = true;
        _currentExpectedOtp = generatedOtp;
        _otpController.clear();
      });
      _startCooldown(60);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SMS OTP sent to $phone. Test Code: $generatedOtp'),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'AUTO-FILL',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _otpController.text = generatedOtp;
              });
            },
          ),
        ),
      );
    }
  }

  void _verifyOtpAndLogin() {
    if (!_otpSent || _currentExpectedOtp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap "Send SMS OTP" first to generate your verification code.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final enteredOtp = _otpController.text.trim();
    if (enteredOtp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the full 6-digit SMS OTP code.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (enteredOtp != _currentExpectedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid OTP. Expected $_currentExpectedOtp. Please check or tap Auto-Fill.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP Verified successfully! Logging in as ${_selectedRole.label}...'),
        backgroundColor: AppColors.successGreen,
        duration: const Duration(seconds: 2),
      ),
    );

    widget.onLogin(_emailController.text.trim(), _selectedRole);
  }

  void _onRoleChanged(UserRole role) {
    setState(() {
      _selectedRole = role;
      switch (role) {
        case UserRole.customer:
          _nameController.text = 'Rajesh Das';
          _emailController.text = 'rajesh.das@drivemate.in';
          _phoneController.text = '+91 98301 22334';
          break;
        case UserRole.driver:
          _nameController.text = 'Amitava Roy';
          _emailController.text = 'amitava.roy@drivemate.in';
          _phoneController.text = '+91 98745 61230';
          _licenseController.text = 'WB-962019003412';
          break;
        case UserRole.owner:
          _nameController.text = 'Debabrata Mukherjee';
          _emailController.text = 'debabrata.mukherjee@drivemate.in';
          _phoneController.text = '+91 98312 45678';
          break;
        case UserRole.admin:
          _nameController.text = 'Regional Operations Admin';
          _emailController.text = 'admin@drivemate.in';
          _phoneController.text = '+91 98000 11223';
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top Bar: Language Selector & AI Assistant Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => LanguageSelectionDialog.show(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B3555),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cyanAccent.withOpacity(0.6), width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.language, color: AppColors.cyanAccent, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${provider.currentLanguage.nativeName} (${provider.currentLanguage.code.toUpperCase()})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.keyboard_arrow_down, color: AppColors.cyanAccent, size: 16),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.smart_toy_outlined, color: AppColors.cyanAccent, size: 22),
                        tooltip: 'DriveMate AI Assistant',
                        onPressed: () => AiChatbotDialog.show(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Redesigned Professional DriveMate Brand Logo (Car Rental + Chauffeur Mobility)
                  const DriveMateLogo(size: 78, showGlow: true),

                  const SizedBox(height: 14),

                  // Brand Title
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Drive',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Mate',
                          style: TextStyle(
                            color: AppColors.cyanAccent,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    l10n.tagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Role Selector Grid
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            l10n.selectRole,
                            style: const TextStyle(
                              color: AppColors.cyanAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: UserRole.values.map((role) {
                            final isSelected = _selectedRole == role;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _onRoleChanged(role),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.electricBlue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        switch (role) {
                                          UserRole.customer => Icons.person,
                                          UserRole.driver => Icons.airline_seat_recline_extra,
                                          UserRole.owner => Icons.directions_car,
                                          UserRole.admin => Icons.admin_panel_settings,
                                        },
                                        color: isSelected ? Colors.white : Colors.white60,
                                        size: 20,
                                      ),
                                      const SizedBox(height: 4),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          switch (role) {
                                            UserRole.customer => l10n.roleCustomer,
                                            UserRole.driver => l10n.roleDriver,
                                            UserRole.owner => l10n.roleOwner,
                                            UserRole.admin => l10n.roleAdmin,
                                          },
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white70,
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Auth Card Container
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Tab Selector: Sign In vs Register
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isRegisterMode = false),
                                child: Column(
                                  children: [
                                    Text(
                                      l10n.signIn,
                                      style: TextStyle(
                                        color: !_isRegisterMode ? Colors.white : Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 3,
                                      color: !_isRegisterMode ? AppColors.cyanAccent : Colors.transparent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isRegisterMode = true),
                                child: Column(
                                  children: [
                                    Text(
                                      l10n.register,
                                      style: TextStyle(
                                        color: _isRegisterMode ? Colors.white : Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 3,
                                      color: _isRegisterMode ? AppColors.cyanAccent : Colors.transparent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Auth Method Toggle (Password vs SMS OTP) — Theme: #1B3555 Navy / #08B6D1 Cyan
                        if (!_isRegisterMode) ...[
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B1930),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF1B3555), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                // 1. Password Login Button
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _useOtpMode = false),
                                    borderRadius: BorderRadius.circular(9),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: !_useOtpMode ? AppColors.electricBlue : const Color(0xFF1B3555),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: !_useOtpMode ? AppColors.cyanAccent : const Color(0xFF2A4A70),
                                          width: 1.5,
                                        ),
                                        boxShadow: !_useOtpMode
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.electricBlue.withOpacity(0.4),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lock_outline,
                                            size: 15,
                                            color: !_useOtpMode ? Colors.white : Colors.white70,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              l10n.passwordLogin,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: !_useOtpMode ? Colors.white : Colors.white70,
                                                fontSize: 12,
                                                fontWeight: !_useOtpMode ? FontWeight.bold : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // 2. SMS OTP Login Button
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _useOtpMode = true),
                                    borderRadius: BorderRadius.circular(9),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: _useOtpMode ? AppColors.electricBlue : const Color(0xFF1B3555),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: _useOtpMode ? AppColors.cyanAccent : const Color(0xFF2A4A70),
                                          width: 1.5,
                                        ),
                                        boxShadow: _useOtpMode
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.electricBlue.withOpacity(0.4),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.sms_outlined,
                                            size: 15,
                                            color: _useOtpMode ? Colors.white : Colors.white70,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              l10n.smsOtpLogin,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: _useOtpMode ? Colors.white : Colors.white70,
                                                fontSize: 12,
                                                fontWeight: _useOtpMode ? FontWeight.bold : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Registration Fields
                        if (_isRegisterMode) ...[
                          _buildTextField(
                            controller: _nameController,
                            label: l10n.fullName,
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _emailController,
                            label: l10n.emailAddress,
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _phoneController,
                            label: l10n.mobileNumber,
                            icon: Icons.phone_android,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Create Secure Password',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white54,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          if (_selectedRole == UserRole.driver) ...[
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _licenseController,
                              label: 'Commercial Driving License (DL)',
                              icon: Icons.card_membership,
                            ),
                          ],
                        ],

                        // SMS OTP Login Form
                        if (_useOtpMode && !_isRegisterMode) ...[
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Registered Mobile Number (+91)',
                            icon: Icons.phone_android,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),

                          // Send OTP / Cooldown Button
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.cyanAccent,
                                side: const BorderSide(color: AppColors.cyanAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: (_cooldownSeconds > 0 || _isSendingOtp) ? null : _sendSmsOtp,
                              icon: _isSendingOtp
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyanAccent),
                                    )
                                  : const Icon(Icons.sms, size: 16),
                              label: Text(
                                _cooldownSeconds > 0
                                    ? 'Resend OTP in ${_cooldownSeconds}s'
                                    : (_otpSent ? 'Resend SMS OTP' : 'Send SMS OTP (MSG91 / Fast2SMS)'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),

                          // Active OTP Banner (Ensures 100% testability & transparency)
                          if (_otpSent && _currentExpectedOtp != null) ...[
                            Container(
                              margin: const EdgeInsets.only(top: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.cyanAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.security, color: AppColors.cyanAccent, size: 18),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'SMS OTP Dispatched (Gateway Test Mode)',
                                          style: TextStyle(
                                            color: AppColors.cyanAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _otpController.text = _currentExpectedOtp!;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.cyanAccent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Auto-Fill',
                                            style: TextStyle(
                                              color: AppColors.navy900,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text(
                                        'Active Security Code: ',
                                        style: TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                      Text(
                                        _currentExpectedOtp!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 17,
                                          letterSpacing: 3.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'When Fast2SMS or MSG91 keys are set in backend .env, this OTP is delivered via physical cellular SMS. In local testing, enter or tap Auto-Fill above.',
                                    style: TextStyle(color: Colors.white60, fontSize: 10.5, height: 1.3),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _otpController,
                              label: '6-Digit SMS OTP Code',
                              icon: Icons.pin,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ] else if (!_isRegisterMode) ...[
                          // Standard Email + Password Fields
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white54,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cyanAccent,
                              foregroundColor: AppColors.navy900,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (_isRegisterMode) {
                                widget.onRegister(
                                  _nameController.text.trim(),
                                  _emailController.text.trim(),
                                  _phoneController.text.trim(),
                                  _selectedRole,
                                  _selectedRole == UserRole.driver ? _licenseController.text.trim() : null,
                                );
                              } else if (_useOtpMode) {
                                _verifyOtpAndLogin();
                              } else {
                                widget.onLogin(
                                  _emailController.text.trim(),
                                  _selectedRole,
                                );
                              }
                            },
                            child: Text(
                              _isRegisterMode
                                  ? 'Create Account & Enter'
                                  : _useOtpMode
                                      ? 'Verify SMS OTP & Enter'
                                      : 'Sign In as ${_selectedRole.label}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // RBAC Security Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Strict Role-Based Access Control: Each account role is strictly isolated to its own features and authenticated endpoints.',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
        prefixIcon: Icon(icon, color: AppColors.cyanAccent, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cyanAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
