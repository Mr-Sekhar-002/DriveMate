import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_language.dart';
import '../l10n/app_localizations.dart';
import '../providers/drivemate_provider.dart';
import '../theme/app_theme.dart';

class LanguageSelectionDialog extends StatefulWidget {
  const LanguageSelectionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LanguageSelectionDialog(),
    );
  }

  @override
  State<LanguageSelectionDialog> createState() => _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends State<LanguageSelectionDialog> {
  late AppLanguage _selectedLanguage;
  late bool _followSystem;

  @override
  void initState() {
    super.initState();
    final provider = context.read<DriveMateProvider>();
    _selectedLanguage = provider.currentLanguage;
    _followSystem = provider.followSystemLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final l10n = context.l10n;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Drag indicator bar
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.electricBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.language, color: AppColors.electricBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.selectLanguage,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy900,
                      ),
                    ),
                    const Text(
                      'English • বাংলা • हिन्दी • ଓଡ଼ିଆ • اردو',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Follow System Device Language Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings_suggest_outlined, size: 20, color: AppColors.navy900),
                    const SizedBox(width: 10),
                    Text(
                      l10n.followSystem,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy900),
                    ),
                  ],
                ),
                Switch(
                  value: _followSystem,
                  activeColor: AppColors.electricBlue,
                  onChanged: (val) {
                    setState(() {
                      _followSystem = val;
                      if (val) {
                        final sys = View.of(context).platformDispatcher.locale;
                        _selectedLanguage = AppLanguage.fromLocale(sys);
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Supported Languages List
          ...AppLanguage.values.map((lang) {
            final isSelected = !_followSystem && _selectedLanguage == lang;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.cyanLight : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.electricBlue : Colors.grey.shade300,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.electricBlue : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      lang.code.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.navy900,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  lang.nativeName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.navy900 : AppColors.textPrimaryDark,
                  ),
                ),
                subtitle: Text(
                  '${lang.englishName}${lang.textDirection == TextDirection.rtl ? " (RTL)" : ""}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppColors.electricBlue, size: 22)
                    : const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 20),
                onTap: () {
                  setState(() {
                    _followSystem = false;
                    _selectedLanguage = lang;
                  });
                },
              ),
            );
          }),

          const SizedBox(height: 16),

          // Apply Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: AppColors.navy900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                provider.setLanguage(_selectedLanguage, followSystem: _followSystem);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                l10n.savePreference,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}
