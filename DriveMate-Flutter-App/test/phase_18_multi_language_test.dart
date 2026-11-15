import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivemate_flutter/l10n/app_language.dart';
import 'package:drivemate_flutter/l10n/app_localizations.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/components/language_selection_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 18: Multi-Language Architecture & AppLanguage Tests', () {
    test('Verifies 5 supported languages and text directions', () {
      expect(AppLanguage.values.length, 5);

      // Verify language codes
      expect(AppLanguage.en.code, 'en');
      expect(AppLanguage.bn.code, 'bn');
      expect(AppLanguage.hi.code, 'hi');
      expect(AppLanguage.orLang.code, 'or');
      expect(AppLanguage.ur.code, 'ur');

      // Verify native script names
      expect(AppLanguage.en.nativeName, 'English');
      expect(AppLanguage.bn.nativeName, 'বাংলা');
      expect(AppLanguage.hi.nativeName, 'हिन्दी');
      expect(AppLanguage.orLang.nativeName, 'ଓଡ଼ିଆ');
      expect(AppLanguage.ur.nativeName, 'اردو');

      // Verify Urdu is RTL and others are LTR
      expect(AppLanguage.ur.textDirection, TextDirection.rtl);
      expect(AppLanguage.en.textDirection, TextDirection.ltr);
      expect(AppLanguage.bn.textDirection, TextDirection.ltr);
      expect(AppLanguage.hi.textDirection, TextDirection.ltr);
      expect(AppLanguage.orLang.textDirection, TextDirection.ltr);

      // Verify fromCode parsing
      expect(AppLanguage.fromCode('bn'), AppLanguage.bn);
      expect(AppLanguage.fromCode('HI'), AppLanguage.hi);
      expect(AppLanguage.fromCode('OR'), AppLanguage.orLang);
      expect(AppLanguage.fromCode('ur'), AppLanguage.ur);
      expect(AppLanguage.fromCode('unknown'), AppLanguage.en);
      expect(AppLanguage.fromCode(null), AppLanguage.en);
    });

    test('Verifies AppLocalizations dictionary completeness across all 5 languages', () {
      for (final lang in AppLanguage.values) {
        final loc = AppLocalizations(lang);

        // Brand & core strings should never be empty
        expect(loc.appName.isNotEmpty, true, reason: '${lang.code} appName empty');
        expect(loc.tagline.isNotEmpty, true, reason: '${lang.code} tagline empty');
        expect(loc.signIn.isNotEmpty, true, reason: '${lang.code} signIn empty');
        expect(loc.register.isNotEmpty, true, reason: '${lang.code} register empty');
        expect(loc.navHome.isNotEmpty, true, reason: '${lang.code} navHome empty');
        expect(loc.navBookings.isNotEmpty, true, reason: '${lang.code} navBookings empty');
        expect(loc.navLiveRide.isNotEmpty, true, reason: '${lang.code} navLiveRide empty');
        expect(loc.hireDriver.isNotEmpty, true, reason: '${lang.code} hireDriver empty');
        expect(loc.negotiateFare.isNotEmpty, true, reason: '${lang.code} negotiateFare empty');
        expect(loc.twoWayNegotiation.isNotEmpty, true, reason: '${lang.code} twoWayNegotiation empty');
      }

      // Explicit Bengali translation checks
      const bn = AppLocalizations(AppLanguage.bn);
      expect(bn.appName, 'ড্রাইভমেট');
      expect(bn.signIn, 'সাইন ইন');
      expect(bn.hireDriver, 'ড্রাইভার হায়ার করুন');

      // Explicit Hindi translation checks
      const hi = AppLocalizations(AppLanguage.hi);
      expect(hi.appName, 'ड्राइवमेट');
      expect(hi.signIn, 'साइन इन करें');
      expect(hi.hireDriver, 'ड्राइवर हायर करें');

      // Explicit Odia translation checks
      const odia = AppLocalizations(AppLanguage.orLang);
      expect(odia.appName, 'ଡ୍ରାଇଭମେଟ୍');
      expect(odia.hireDriver, 'ଡ୍ରାଇଭର ଭଡ଼ା କରନ୍ତୁ');

      // Explicit Urdu translation checks
      const ur = AppLocalizations(AppLanguage.ur);
      expect(ur.appName, 'ڈرائیومیٹ');
      expect(ur.signIn, 'سائن ان');
      expect(ur.hireDriver, 'ڈرائیور کی خدمات حاصل کریں');
    });

    test('Verifies DriveMateProvider language state management & SharedPreferences persistence', () async {
      final provider = DriveMateProvider();
      await provider.initLanguage();

      expect(provider.currentLanguage, AppLanguage.en);
      expect(provider.currentLocale.languageCode, 'en');
      expect(provider.textDirection, TextDirection.ltr);

      // Switch to Bengali
      await provider.setLanguage(AppLanguage.bn);
      expect(provider.currentLanguage, AppLanguage.bn);
      expect(provider.currentLocale.languageCode, 'bn');
      expect(provider.textDirection, TextDirection.ltr);

      // Verify SharedPreferences persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('drivemate_preferred_language'), 'bn');

      // Switch to Urdu (RTL)
      await provider.setLanguage(AppLanguage.ur);
      expect(provider.currentLanguage, AppLanguage.ur);
      expect(provider.currentLocale.languageCode, 'ur');
      expect(provider.textDirection, TextDirection.rtl);
      expect(prefs.getString('drivemate_preferred_language'), 'ur');

      // Re-initialize provider to verify auto-load from SharedPreferences
      final freshProvider = DriveMateProvider();
      await freshProvider.initLanguage();
      expect(freshProvider.currentLanguage, AppLanguage.ur);
      expect(freshProvider.textDirection, TextDirection.rtl);
    });
  });

  group('Phase 18: UI Language Selection Modal Test', () {
    testWidgets('Opens LanguageSelectionDialog and switches language to Hindi', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: MaterialApp(
            locale: provider.currentLocale,
            supportedLocales: AppLanguage.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => LanguageSelectionDialog.show(context),
                  child: const Text('Open Language Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.text('Open Language Modal'));
      await tester.pumpAndSettle();

      // Verify dialog is presented with languages
      expect(find.text('Select Language'), findsOneWidget);
      expect(find.text('বাংলা'), findsOneWidget);
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(find.text('ଓଡ଼ିଆ'), findsOneWidget);
      expect(find.text('اردو'), findsOneWidget);

      // Tap Hindi option
      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();

      // Tap Apply & Save
      await tester.ensureVisible(find.text('Apply & Save'));
      await tester.tap(find.text('Apply & Save'));
      await tester.pumpAndSettle();

      // Verify provider has updated to Hindi
      expect(provider.currentLanguage, AppLanguage.hi);
    });
  });
}
