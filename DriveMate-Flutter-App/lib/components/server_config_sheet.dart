import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/drivemate_provider.dart';
import '../theme/app_theme.dart';

class ServerConfigSheet extends StatefulWidget {
  const ServerConfigSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ServerConfigSheet(),
    );
  }

  @override
  State<ServerConfigSheet> createState() => _ServerConfigSheetState();
}

class _ServerConfigSheetState extends State<ServerConfigSheet> {
  late TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;
  bool _isTestSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final rawUrl = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (rawUrl.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final testUri = Uri.parse('$rawUrl/health');
      final res = await http.get(testUri).timeout(const Duration(seconds: 5));
      setState(() {
        _isTesting = false;
        _isTestSuccess = res.statusCode >= 200 && res.statusCode < 400;
        _testResult = _isTestSuccess
            ? 'Server Reachable! (Status: ${res.statusCode})'
            : 'Server responded with HTTP ${res.statusCode}';
      });
    } catch (e) {
      // Try root as fallback
      try {
        final rootUri = Uri.parse(rawUrl);
        final res2 = await http.get(rootUri).timeout(const Duration(seconds: 4));
        setState(() {
          _isTesting = false;
          _isTestSuccess = true;
          _testResult = 'Server Connected! (HTTP ${res2.statusCode})';
        });
      } catch (err2) {
        setState(() {
          _isTesting = false;
          _isTestSuccess = false;
          _testResult = 'Cannot connect: Check Render URL or Internet connection.';
        });
      }
    }
  }

  Future<void> _saveAndApply() async {
    final rawUrl = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (rawUrl.isEmpty) return;

    await ApiConfig.setCustomBaseUrl(rawUrl, env: ApiEnvironment.render);
    if (!mounted) return;

    final provider = context.read<DriveMateProvider>();
    provider.checkBackendHealth();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.successGreen,
        content: Text(
          'Server connected to: $rawUrl',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final cardBg = isDark ? AppColors.darkCardBg : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;
    final cardInner = isDark ? AppColors.darkCardElevated : AppColors.lightPage;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: borderSubtle),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: AppColors.cyanAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server & Render Cloud Setup',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Connect physical Driver & Customer devices to same server',
                          style: TextStyle(fontSize: 11.5, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Text(
                'QUICK PRESETS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.cloud, size: 14, color: AppColors.cyanAccent),
                    label: const Text('Render Cloud', style: TextStyle(fontSize: 11.5)),
                    backgroundColor: cardInner,
                    onPressed: () {
                      setState(() {
                        _urlController.text = 'https://drivemate-api.onrender.com/api';
                        _testResult = null;
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.wifi, size: 14, color: AppColors.primaryBlue),
                    label: const Text('Local Wi-Fi LAN', style: TextStyle(fontSize: 11.5)),
                    backgroundColor: cardInner,
                    onPressed: () {
                      setState(() {
                        _urlController.text = 'http://192.168.0.107:80/drivemate-api/public/index.php/api';
                        _testResult = null;
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.phone_android, size: 14, color: AppColors.successGreen),
                    label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11.5)),
                    backgroundColor: cardInner,
                    onPressed: () {
                      setState(() {
                        _urlController.text = 'http://10.0.2.2:80/drivemate-api/public/index.php/api';
                        _testResult = null;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'BACKEND API BASE URL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlController,
                style: TextStyle(color: textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cardInner,
                  hintText: 'https://your-service.onrender.com/api',
                  hintStyle: TextStyle(color: AppColors.textMutedOf(context)),
                  prefixIcon: const Icon(Icons.link_rounded, color: AppColors.cyanAccent, size: 18),
                  suffixIcon: IconButton(
                    icon: _isTesting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.network_check_rounded, color: AppColors.primaryBlue, size: 20),
                    tooltip: 'Ping & Test Connection',
                    onPressed: _isTesting ? null : _testConnection,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderSubtle)),
                ),
              ),

              if (_testResult != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isTestSuccess
                        ? AppColors.successGreen.withOpacity(0.15)
                        : AppColors.errorRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isTestSuccess ? AppColors.successGreen : AppColors.errorRed,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isTestSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: _isTestSuccess ? AppColors.successGreen : AppColors.errorRed,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isTestSuccess ? AppColors.successGreen : AppColors.errorRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(color: borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _saveAndApply,
                      child: const Text('Save & Connect Server', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
