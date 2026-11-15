import 'package:flutter/material.dart';
import 'app_language.dart';

class AppLocalizations {
  final AppLanguage language;

  const AppLocalizations(this.language);

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return localizations ?? const AppLocalizations(AppLanguage.en);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // ─── TRANSLATION DICTIONARY ─────────────────────────────────────────────
  static final Map<String, Map<String, String>> _localizedValues = {
    // ── App Brand & Tagline ──
    'appName': {
      'en': 'DriveMate',
      'bn': 'ড্রাইভমেট',
      'hi': 'ड्राइवमेट',
      'or': 'ଡ୍ରାଇଭମେଟ୍',
      'ur': 'ڈرائیومیٹ',
    },
    'tagline': {
      'en': 'Your Car. Your Driver. Pan-India Mobility.',
      'bn': 'আপনার গাড়ি। আপনার চালক। সর্বভারতীয় মোবিলিটি।',
      'hi': 'आपकी कार। आपका ड्राइवर। अखिल भारतीय मोबिलिटी।',
      'or': 'ଆପଣଙ୍କ ଗାଡ଼ି। ଆପଣଙ୍କ ଡ୍ରାଇଭର। ପାନ୍-ଇଣ୍ଡିଆ ମୋବିଲିଟି।',
      'ur': 'آپ کی گاڑی۔ آپ کا ڈرائیور۔ آل انڈیا نقل و حرکت۔',
    },

    // ── Authentication & Roles ──
    'signIn': {
      'en': 'Sign In',
      'bn': 'সাইন ইন',
      'hi': 'साइन इन करें',
      'or': 'ସାଇନ୍ ଇନ୍',
      'ur': 'سائن ان',
    },
    'register': {
      'en': 'Register Account',
      'bn': 'অ্যাকাউন্ট খুলুন',
      'hi': 'खाता पंजीकृत करें',
      'or': 'ଖାତା ପଞ୍ଜୀକରଣ',
      'ur': 'اکاؤنٹ رجسٹر کریں',
    },
    'passwordLogin': {
      'en': 'Password Login',
      'bn': 'পাসওয়ার্ড লগইন',
      'hi': 'पासवर्ड लॉगिन',
      'or': 'ପାସୱାର୍ଡ ଲଗଇନ୍',
      'ur': 'پاس ورڈ لاگ ان',
    },
    'smsOtpLogin': {
      'en': 'SMS OTP Login',
      'bn': 'এসএমএস ওটিপি লগইন',
      'hi': 'एसएमएस ओटीपी लॉगिन',
      'or': 'ଏସଏମଏସ ଓଟିପି ଲଗଇନ୍',
      'ur': 'ایس ایم ایس او ٹی پی لاگ ان',
    },
    'sendSmsOtp': {
      'en': 'Send SMS OTP',
      'bn': 'এসএমএস ওটিপি পাঠান',
      'hi': 'एसएमएस ओटीपी भेजें',
      'or': 'ଏସଏମଏସ ଓଟିପି ପଠାନ୍ତୁ',
      'ur': 'ایس ایم ایس او ٹی پی بھیجیں',
    },
    'verifySmsOtp': {
      'en': 'Verify SMS OTP & Enter',
      'bn': 'ওটিপি যাচাই করে প্রবেশ করুন',
      'hi': 'ओटीपी सत्यापित कर प्रवेश करें',
      'or': 'ଓଟିପି ଯାଞ୍ଚ କରି ପ୍ରବେଶ କରନ୍ତୁ',
      'ur': 'او ٹی پی کی تصدیق کر کے داخل ہوں',
    },
    'autoFill': {
      'en': 'AUTO-FILL',
      'bn': 'স্বয়ংক্রিয় পূরণ',
      'hi': 'ऑटो-फिल',
      'or': 'ସ୍ୱୟଂଚାଳିତ ଭାବେ ପୂରଣ',
      'ur': 'خودکار بھریں',
    },
    'selectRole': {
      'en': 'SELECT ACCOUNT ROLE (STRICT RBAC)',
      'bn': 'অ্যাকাউন্টের ভূমিকা নির্বাচন করুন',
      'hi': 'खाता भूमिका चुनें (सख्त आरबीएसी)',
      'or': 'ଖାତା ଭୂମିକା ଚୟନ କରନ୍ତୁ',
      'ur': 'اکاؤنٹ کا کردار منتخب کریں',
    },
    'roleCustomer': {
      'en': 'Customer',
      'bn': 'গ্রাহক',
      'hi': 'ग्राहक',
      'or': 'ଗ୍ରାହକ',
      'ur': 'گاہک',
    },
    'roleDriver': {
      'en': 'Driver',
      'bn': 'চালক',
      'hi': 'ड्राइवर',
      'or': 'ଚାଳକ',
      'ur': 'ڈرائیور',
    },
    'roleOwner': {
      'en': 'Car Owner',
      'bn': 'গাড়ির মালিক',
      'hi': 'कार मालिक',
      'or': 'ଗାଡ଼ି ମାଲିକ',
      'ur': 'گاڑی کا مالک',
    },
    'roleAdmin': {
      'en': 'Admin',
      'bn': 'অ্যাডমিন',
      'hi': 'एडमिन',
      'or': 'ପ୍ରଶାସକ',
      'ur': 'ایڈمن',
    },
    'fullName': {
      'en': 'Full Legal Name',
      'bn': 'সম্পূর্ণ নাম',
      'hi': 'पूरा कानूनी नाम',
      'or': 'ସମ୍ପୂର୍ଣ୍ଣ ଆଇନଗତ ନାମ',
      'ur': 'مکمل قانونی نام',
    },
    'emailAddress': {
      'en': 'Email Address',
      'bn': 'ইমেইল ঠিকানা',
      'hi': 'ईमेल पता',
      'or': 'ଇମେଲ ଠିକଣା',
      'ur': 'ای میل کا پتہ',
    },
    'mobileNumber': {
      'en': 'Indian Mobile Number (+91)',
      'bn': 'ভারতীয় মোবাইল নম্বর (+৯১)',
      'hi': 'भारतीय मोबाइल नंबर (+91)',
      'or': 'ଭାରତୀୟ ମୋବାଇଲ୍ ନମ୍ବର (+୯୧)',
      'ur': 'ہندوستانی موبائل نمبر (+91)',
    },
    'password': {
      'en': 'Password',
      'bn': 'পাসওয়ার্ড',
      'hi': 'पासवर्ड',
      'or': 'ପାସୱାର୍ଡ',
      'ur': 'پاس ورڈ',
    },

    // ── Navigation Bar ──
    'navHome': {
      'en': 'Home',
      'bn': 'হোম',
      'hi': 'होम',
      'or': 'ମୂଳପୃଷ୍ଠା',
      'ur': 'ہوم',
    },
    'navBookings': {
      'en': 'Bookings',
      'bn': 'বুকিং সমূহ',
      'hi': 'बुकिंग्स',
      'or': 'ବୁକିଂ',
      'ur': 'بکنگز',
    },
    'navLiveRide': {
      'en': 'Live Ride',
      'bn': 'লাইভ রাইড',
      'hi': 'लाइव राइड',
      'or': 'ଲାଇଭ ରାଇଡ୍',
      'ur': 'لائیو رائیڈ',
    },
    'navBlueprint': {
      'en': 'Blueprint',
      'bn': 'ব্লুপ্রিন্ট',
      'hi': 'ब्लूप्रिंट',
      'or': 'ବ୍ଲୁପ୍ରିଣ୍ଟ',
      'ur': 'بلیو پرنٹ',
    },

    'navInvoices': {
      'en': 'Invoices & Receipts',
      'bn': 'ইনভয়েস ও রসিদ',
      'hi': 'इनवॉइस व रसीद',
      'or': 'ଇନଭଏସ୍ ଓ ରସିଦ',
      'ur': 'انوائس اور رسیدیں',
    },
    'navTripHistory': {
      'en': 'Trip History',
      'bn': 'ট্রিপ হিস্ট্রি',
      'hi': 'ट्रिप हिस्ट्री',
      'or': 'ଟ୍ରିପ୍ ଇତିହାସ',
      'ur': 'سفر کی تاریخ',
    },

    // ── Customer Home & Core Services ──
    'whatDoYouNeed': {
      'en': 'What do you need?',
      'bn': 'আপনার কী প্রয়োজন?',
      'hi': 'आपको क्या चाहिए?',
      'or': 'ଆପଣଙ୍କର କ’ଣ ଦରକାର?',
      'ur': 'آپ کو کیا ضرورت ہے؟',
    },
    'hireDriver': {
      'en': 'Hire a Driver',
      'bn': 'ড্রাইভার হায়ার করুন',
      'hi': 'ड्राइवर हायर करें',
      'or': 'ଡ୍ରାଇଭର ଭଡ଼ା କରନ୍ତୁ',
      'ur': 'ڈرائیور کی خدمات حاصل کریں',
    },
    'hireDriverSubtitle': {
      'en': 'Customer owns the car • Verified Chauffeur',
      'bn': 'গ্রাহকের নিজের গাড়ি • বিশ্বস্ত চালক',
      'hi': 'ग्राहक की अपनी कार • सत्यापित ड्राइवर',
      'or': 'ଗ୍ରାହକଙ୍କ ନିଜ ଗାଡ଼ି • ଯାଞ୍ଚ ହୋଇଥିବା ଚାଳକ',
      'ur': 'گاہک کی اپنی کار • تصدیق شدہ ڈرائیور',
    },
    'rentCar': {
      'en': 'Rent a Car',
      'bn': 'গাড়ি ভাড়া নিন',
      'hi': 'कार रेंट पर लें',
      'or': 'ଗାଡ଼ି ଭଡ଼ାରେ ନିଅନ୍ତୁ',
      'ur': 'گاڑی کرایہ پر لیں',
    },
    'rentCarSubtitle': {
      'en': 'Self-Drive',
      'bn': 'স্বয়ং-চালিত গাড়ি',
      'hi': 'सेल्फ-ड्राइव',
      'or': 'ନିଜେ ଚଳାନ୍ତୁ',
      'ur': 'سیلف ڈرائیو',
    },
    'rentCarAndDriver': {
      'en': 'Rent Car + Driver',
      'bn': 'গাড়ি + ড্রাইভার ভাড়া',
      'hi': 'कार + ड्राइवर रेंट',
      'or': 'ଗାଡ଼ି + ଚାଳକ ଭଡ଼ା',
      'ur': 'کار + ڈرائیور کرایہ',
    },
    'rentCarAndDriverSubtitle': {
      'en': 'Chauffeur Driven Rental',
      'bn': 'ড্রাইভার সহ রেন্টাল',
      'hi': 'ड्राइवर सहित रेंटल',
      'or': 'ଚାଳକ ସହିତ ଭଡ଼ା',
      'ur': 'ڈرائیور کے ساتھ کرایہ',
    },

    // ── Phase 19 Driver-Only Hiring & Location-Based Negotiation ──
    'driverHiringEngine': {
      'en': 'PHASE 19: DRIVER HIRING ENGINE',
      'bn': 'ফেজ ১৯: ড্রাইভার হায়ার ইঞ্জিন',
      'hi': 'चरण 19: ड्राइवर हायरिंग इंजन',
      'or': 'ପର୍ଯ୍ୟାୟ ୧୯: ଡ୍ରାଇଭର ଭଡ଼ା ଇଞ୍ଜିନ',
      'ur': 'مرحلہ 19: ڈرائیور ہائرنگ انجن',
    },
    'selectHiringType': {
      'en': 'Select Driver Hiring Type:',
      'bn': 'ড্রাইভার হায়ার টাইপ নির্বাচন করুন:',
      'hi': 'ड्राइवर हायरिंग का प्रकार चुनें:',
      'or': 'ଡ୍ରାଇଭର ଭଡ଼ା ପ୍ରକାର ଚୟନ କରନ୍ତୁ:',
      'ur': 'ڈرائیور کی خدمات کی قسم منتخب کریں:',
    },
    'oneWayTrip': {
      'en': 'One-way Trip',
      'bn': 'একমুখী ট্রিপ',
      'hi': 'एकतरफा ट्रिप',
      'or': 'ଏକତରଫା ଟ୍ରିପ୍',
      'ur': 'ایک طرفہ سفر',
    },
    'roundTrip': {
      'en': 'Round-trip',
      'bn': 'রাউন্ড-ট্রিপ (যাওয়া-আসা)',
      'hi': 'राउंड-ट्रिप (आना-जाना)',
      'or': 'ରାଉଣ୍ଡ ଟ୍ରିପ୍ (ଯିବା-ଆସିବା)',
      'ur': 'راؤنڈ ٹرپ',
    },
    'hourlyChauffeur': {
      'en': 'Hourly Chauffeur',
      'bn': 'ঘণ্টাভিত্তিক চালক',
      'hi': 'घंटे के अनुसार ड्राइवर',
      'or': 'ଘଣ୍ଟା ଅନୁସାରେ ଚାଳକ',
      'ur': 'گھنٹہ وار ڈرائیور',
    },
    'fullDayHiring': {
      'en': 'Full-day Hiring',
      'bn': 'সারাদিনের চালক',
      'hi': 'पूरे दिन के लिए ड्राइवर',
      'or': 'ସମ୍ପୂର୍ଣ୍ଣ ଦିନ ଭଡ଼ା',
      'ur': 'پورے دن کے لیے خدمات',
    },
    'pickupLocation': {
      'en': 'PICKUP LOCATION',
      'bn': 'পিকআপের অবস্থান',
      'hi': 'पिकअप स्थान',
      'or': 'ପିକଅପ୍ ସ୍ଥାନ',
      'ur': 'پک اپ کا مقام',
    },
    'destination': {
      'en': 'DESTINATION',
      'bn': 'গন্তব্যস্থল',
      'hi': 'गंतव्य स्थान',
      'or': 'ଗନ୍ତବ୍ୟ ସ୍ଥଳ',
      'ur': 'منزل مقصود',
    },
    'useCurrentLocation': {
      'en': 'Use Current Location',
      'bn': 'বর্তমান অবস্থান ব্যবহার করুন',
      'hi': 'वर्तमान स्थान का उपयोग करें',
      'or': 'ବର୍ତ୍ତମାନର ସ୍ଥାନ ବ୍ୟବହାର କରନ୍ତୁ',
      'ur': 'موجودہ مقام استعمال کریں',
    },
    'roadDistance': {
      'en': 'Road Distance',
      'bn': 'সড়ক দূরত্ব',
      'hi': 'सड़क की दूरी',
      'or': 'ସଡ଼କ ଦୂରତା',
      'ur': 'سڑک کا فاصلہ',
    },
    'durationMins': {
      'en': 'mins road route',
      'bn': 'মিনিট সড়ক পথ',
      'hi': 'मिनट का रास्ता',
      'or': 'ମିନିଟ୍ ରାସ୍ତା',
      'ur': 'منٹ کا راستہ',
    },
    'totalEstimatedFare': {
      'en': 'Total Estimated Fare:',
      'bn': 'মোট আনুমানিক ভাড়া:',
      'hi': 'कुल अनुमानित किराया:',
      'or': 'ମୋଟ ଆନୁମାନିକ ଭଡ଼ା:',
      'ur': 'کل متوقع کرایہ:',
    },
    'suggestedRange': {
      'en': 'Suggested Negotiation Range',
      'bn': 'প্রস্তাবিত সমঝোতার সীমা',
      'hi': 'सुझाई गई बातचीत की सीमा',
      'or': 'ପରାମର୍ଶିତ ବୁଝାମଣା ସୀମା',
      'ur': 'تجویز کردہ بات چیت کی حد',
    },
    'negotiateFare': {
      'en': 'Negotiate Fare',
      'bn': 'ভাড়া সমঝোতা করুন',
      'hi': 'किराया तय करें',
      'or': 'ଭଡ଼ା ବୁଝାମଣା କରନ୍ତୁ',
      'ur': 'کرایہ پر بات چیت کریں',
    },
    'twoWayNegotiation': {
      'en': 'Two-Way Fare Negotiation',
      'bn': 'উভয়পক্ষীয় ভাড়া সমঝোতা',
      'hi': 'दो-तरफा किराया बातचीत',
      'or': 'ଦୁଇ-ପାଖିଆ ଭଡ଼ା ବୁଝାମଣା',
      'ur': 'دو طرفہ کرایہ کی بات چیت',
    },
    'proposedFare': {
      'en': 'Your Proposed Fare (INR)',
      'bn': 'আপনার প্রস্তাবিত ভাড়া (টাকা)',
      'hi': 'आपका प्रस्तावित किराया (₹)',
      'or': 'ଆପଣଙ୍କ ପ୍ରସ୍ତାବିତ ଭଡ଼ା (ଟଙ୍କା)',
      'ur': 'آپ کا مجوزہ کرایہ (روپے)',
    },
    'submitOffer': {
      'en': 'Submit Offer to Chauffeur',
      'bn': 'চালকের কাছে প্রস্তাব পাঠান',
      'hi': 'ड्राइवर को ऑफर भेजें',
      'or': 'ଚାଳକଙ୍କୁ ଅଫର ପଠାନ୍ତୁ',
      'ur': 'ڈرائیور کو پیشکش بھیجیں',
    },
    'bookAt': {
      'en': 'Book',
      'bn': 'বুক করুন',
      'hi': 'बुक करें',
      'or': 'ବୁକ୍ କରନ୍ତୁ',
      'ur': 'بک کریں',
    },
    'driverCounterReceived': {
      'en': 'DRIVER COUNTER-OFFER RECEIVED',
      'bn': 'চালকের পাল্টা প্রস্তাব পাওয়া গেছে',
      'hi': 'ड्राइवर का काउंटर ऑफर मिला',
      'or': 'ଚାଳକଙ୍କ ପାଲଟା ପ୍ରସ୍ତାବ ମିଳିଛି',
      'ur': 'ڈرائیور کی جوابی پیشکش موصول ہوئی',
    },
    'fareAgreedConfirmed': {
      'en': 'FARE AGREED & CONFIRMED',
      'bn': 'ভাড়া সম্মত ও বুকিং নিশ্চিত',
      'hi': 'किराया सहमत और बुकिंग कन्फर्म',
      'or': 'ଭଡ଼ା ରାଜି ଏବଂ ବୁକିଂ ନିଶ୍ଚିତ',
      'ur': 'کرایہ طے پایا اور بکنگ کی تصدیق ہوئی',
    },
    'acceptOfferBtn': {
      'en': 'Accept',
      'bn': 'গ্রহণ করুন',
      'hi': 'स्वीकार करें',
      'or': 'ଗ୍ରହଣ କରନ୍ତୁ',
      'ur': 'قبول کریں',
    },
    'viewNegotiation': {
      'en': 'View Negotiation',
      'bn': 'সমঝোতা দেখুন',
      'hi': 'बातचीत देखें',
      'or': 'ବୁଝାମଣା ଦେଖନ୍ତୁ',
      'ur': 'بات چیت دیکھیں',
    },

    // ── Driver Operations Dashboard ──
    'driverOpsHub': {
      'en': 'Driver Operations Hub',
      'bn': 'ড্রাইভার অপারেশনস হাব',
      'hi': 'ड्राइवर ऑपरेशंस हब',
      'or': 'ଡ୍ରାଇଭର କାର୍ଯ୍ୟ କେନ୍ଦ୍ର',
      'ur': 'ڈرائیور آپریشنز ہب',
    },
    'bookingRequests': {
      'en': 'Booking Requests',
      'bn': 'বুকিং অনুরোধ সমূহ',
      'hi': 'बुकिंग अनुरोध',
      'or': 'ବୁକିଂ ଅନୁରୋଧ',
      'ur': 'بکنگ کی درخواستیں',
    },
    'acceptBooking': {
      'en': 'Accept Booking',
      'bn': 'বুকিং গ্রহণ করুন',
      'hi': 'बुकिंग स्वीकार करें',
      'or': 'ବୁକିଂ ଗ୍ରହଣ କରନ୍ତୁ',
      'ur': 'بکنگ قبول کریں',
    },
    'rejectBooking': {
      'en': 'Reject Booking',
      'bn': 'বুকিং বাতিল করুন',
      'hi': 'बुकिंग अस्वीकार करें',
      'or': 'ବୁକିଂ ପ୍ରତ୍ୟାଖ୍ୟାନ କରନ୍ତୁ',
      'ur': 'بکنگ مسترد کریں',
    },
    'navigateToPickup': {
      'en': 'Navigate to Pickup',
      'bn': 'পিকআপে নেভিগেট করুন',
      'hi': 'पिकअप के लिए नेविगेट करें',
      'or': 'ପିକଅପ୍ କୁ ଯାଆନ୍ତୁ',
      'ur': 'پک اپ کا راستہ تلاش کریں',
    },
    'iveArrived': {
      'en': "I've Arrived",
      'bn': 'আমি পৌঁছে গেছি',
      'hi': 'मैं पहुँच गया हूँ',
      'or': 'ମୁଁ ପହଞ୍ଚିଗଲି',
      'ur': 'میں پہنچ گیا ہوں',
    },
    'callCustomer': {
      'en': 'Call Customer',
      'bn': 'গ্রাহককে কল করুন',
      'hi': 'ग्राहक को कॉल करें',
      'or': 'ଗ୍ରାହକଙ୍କୁ କଲ୍ କରନ୍ତୁ',
      'ur': 'گاہک کو کال کریں',
    },
    'verifyOtp': {
      'en': 'Verify OTP',
      'bn': 'ওটিপি যাচাই করুন',
      'hi': 'ओटीपी सत्यापित करें',
      'or': 'ଓଟିପି ଯାଞ୍ଚ କରନ୍ତୁ',
      'ur': 'او ٹی پی کی تصدیق کریں',
    },
    'startTrip': {
      'en': 'Start Trip',
      'bn': 'ট্রিপ শুরু করুন',
      'hi': 'यात्रा शुरू करें',
      'or': 'ଯାତ୍ରା ଆରମ୍ଭ କରନ୍ତୁ',
      'ur': 'سفر شروع کریں',
    },
    'completeTrip': {
      'en': 'Complete Trip',
      'bn': 'ট্রিপ সমাপ্ত করুন',
      'hi': 'यात्रा समाप्त करें',
      'or': 'ଯାତ୍ରା ସମାପ୍ତ କରନ୍ତୁ',
      'ur': 'سفر مکمل کریں',
    },
    'tripHistory': {
      'en': 'Trip History',
      'bn': 'ট্রিপের ইতিহাস',
      'hi': 'यात्रा इतिहास',
      'or': 'ଯାତ୍ରା ଇତିହାସ',
      'ur': 'سفر کی تاریخ',
    },
    'myEarnings': {
      'en': 'My Earnings',
      'bn': 'আমার আয়',
      'hi': 'मेरी कमाई',
      'or': 'ମୋର ଆୟ',
      'ur': 'میری آمدنی',
    },
    'supportSos': {
      'en': 'Support & SOS',
      'bn': 'সহায়তা ও এসওএস',
      'hi': 'सहायता और आपातकालीन',
      'or': 'ସହାୟତା ଏବଂ ଜରୁରୀ ସେବା',
      'ur': 'مدد اور ہنگامی سروس',
    },

    // ── Multi-Language Settings & Common ──
    'language': {
      'en': 'Language',
      'bn': 'ভাষা',
      'hi': 'भाषा',
      'or': 'ଭାଷା',
      'ur': 'زبان',
    },
    'selectLanguage': {
      'en': 'Select Language',
      'bn': 'ভাষা নির্বাচন করুন',
      'hi': 'भाषा चुनें',
      'or': 'ଭାଷା ଚୟନ କରନ୍ତୁ',
      'ur': 'زبان منتخب کریں',
    },
    'followSystem': {
      'en': 'Follow System (Device Language)',
      'bn': 'ডিভাইসের ভাষা অনুসরণ করুন',
      'hi': 'डिवाइस की भाषा का पालन करें',
      'or': 'ଡିଭାଇସ୍ ଭାଷା ଅନୁସରଣ କରନ୍ତୁ',
      'ur': 'ڈیوائس کی زبان کے مطابق',
    },
    'savePreference': {
      'en': 'Apply & Save',
      'bn': 'প্রয়োগ ও সংরক্ষণ করুন',
      'hi': 'लागू करें और सहेजें',
      'or': 'ଲାଗୁ କରନ୍ତୁ ଏବଂ ସଂରକ୍ଷଣ କରନ୍ତୁ',
      'ur': 'لاگو کریں اور محفوظ کریں',
    },
    'notifications': {
      'en': 'Notifications',
      'bn': 'বিজ্ঞপ্তি সমূহ',
      'hi': 'सूचनाएं',
      'or': 'ବିଜ୍ଞପ୍ତି',
      'ur': 'اطلاعات',
    },
    'aiAssistant': {
      'en': 'DriveMate AI Assistant',
      'bn': 'ড্রাইভমেট এআই সহকারী',
      'hi': 'ड्राइवमेट एआई सहायक',
      'or': 'ଡ୍ରାଇଭମେଟ୍ ଏଆଇ ସହାୟକ',
      'ur': 'ڈرائیومیٹ اے آئی اسسٹنٹ',
    },
    'askAi': {
      'en': 'Ask AI Assistant...',
      'bn': 'এআই সহকারীকে জিজ্ঞাসা করুন...',
      'hi': 'एआई से सवाल पूछें...',
      'or': 'ଏଆଇ କୁ ପଚାରନ୍ତୁ...',
      'ur': 'اے آئی سے پوچھیں...',
    },
  };

  String tr(String key) {
    final langCode = language.code;
    final dict = _localizedValues[key];
    if (dict == null) return key;
    return dict[langCode] ?? dict['en'] ?? key;
  }

  // Typed Convenience Getters
  String get appName => tr('appName');
  String get tagline => tr('tagline');
  String get signIn => tr('signIn');
  String get register => tr('register');
  String get passwordLogin => tr('passwordLogin');
  String get smsOtpLogin => tr('smsOtpLogin');
  String get sendSmsOtp => tr('sendSmsOtp');
  String get verifySmsOtp => tr('verifySmsOtp');
  String get autoFill => tr('autoFill');
  String get selectRole => tr('selectRole');
  String get roleCustomer => tr('roleCustomer');
  String get roleDriver => tr('roleDriver');
  String get roleOwner => tr('roleOwner');
  String get roleAdmin => tr('roleAdmin');
  String get fullName => tr('fullName');
  String get emailAddress => tr('emailAddress');
  String get mobileNumber => tr('mobileNumber');
  String get password => tr('password');

  String get navHome => tr('navHome');
  String get navBookings => tr('navBookings');
  String get navLiveRide => tr('navLiveRide');
  String get navBlueprint => tr('navBlueprint');
  String get navInvoices => tr('navInvoices');
  String get navTripHistory => tr('navTripHistory');

  String get whatDoYouNeed => tr('whatDoYouNeed');
  String get hireDriver => tr('hireDriver');
  String get hireDriverSubtitle => tr('hireDriverSubtitle');
  String get rentCar => tr('rentCar');
  String get rentCarSubtitle => tr('rentCarSubtitle');
  String get rentCarAndDriver => tr('rentCarAndDriver');
  String get rentCarAndDriverSubtitle => tr('rentCarAndDriverSubtitle');

  String get oneWayTrip => tr('oneWayTrip');
  String get roundTrip => tr('roundTrip');
  String get hourlyChauffeur => tr('hourlyChauffeur');
  String get fullDayHiring => tr('fullDayHiring');

  String get pickupLocation => tr('pickupLocation');
  String get destination => tr('destination');
  String get useCurrentLocation => tr('useCurrentLocation');
  String get roadDistance => tr('roadDistance');
  String get totalEstimatedFare => tr('totalEstimatedFare');
  String get suggestedRange => tr('suggestedRange');
  String get negotiateFare => tr('negotiateFare');
  String get twoWayNegotiation => tr('twoWayNegotiation');
  String get proposedFare => tr('proposedFare');
  String get submitOffer => tr('submitOffer');
  String get bookAt => tr('bookAt');
  String get driverCounterReceived => tr('driverCounterReceived');
  String get fareAgreedConfirmed => tr('fareAgreedConfirmed');
  String get acceptOfferBtn => tr('acceptOfferBtn');
  String get viewNegotiation => tr('viewNegotiation');

  String get driverOpsHub => tr('driverOpsHub');
  String get bookingRequests => tr('bookingRequests');
  String get acceptBooking => tr('acceptBooking');
  String get rejectBooking => tr('rejectBooking');
  String get navigateToPickup => tr('navigateToPickup');
  String get iveArrived => tr('iveArrived');
  String get callCustomer => tr('callCustomer');
  String get verifyOtp => tr('verifyOtp');
  String get startTrip => tr('startTrip');
  String get completeTrip => tr('completeTrip');
  String get tripHistory => tr('tripHistory');
  String get myEarnings => tr('myEarnings');
  String get supportSos => tr('supportSos');

  String get languageTitle => tr('language');
  String get selectLanguage => tr('selectLanguage');
  String get followSystem => tr('followSystem');
  String get savePreference => tr('savePreference');
  String get notifications => tr('notifications');
  String get aiAssistant => tr('aiAssistant');
  String get askAi => tr('askAi');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'bn', 'hi', 'or', 'ur'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(AppLanguage.fromLocale(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).tr(key);
}
