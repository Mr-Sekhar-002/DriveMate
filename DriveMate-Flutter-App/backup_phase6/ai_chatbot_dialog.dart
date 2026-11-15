import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_language.dart';
import '../l10n/app_localizations.dart';
import '../providers/drivemate_provider.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String time;

  ChatMessage({required this.text, required this.isUser, required this.time});
}

class AiChatbotDialog extends StatefulWidget {
  const AiChatbotDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AiChatbotDialog(),
    );
  }

  @override
  State<AiChatbotDialog> createState() => _AiChatbotDialogState();
}

class _AiChatbotDialogState extends State<AiChatbotDialog> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    final provider = context.read<DriveMateProvider>();
    final greeting = _getInitialGreeting(provider.currentLanguage);
    _messages = [
      ChatMessage(text: greeting, isUser: false, time: 'Now'),
    ];
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getInitialGreeting(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.bn:
        return 'নমস্কার! আমি ড্রাইভমেট এআই সহকারী। ড্রাইভার হায়ার, গাড়ি ভাড়া, ভাড়া সমঝোতা বা রুট সম্পর্কে যে কোনো প্রশ্ন করতে পারেন।';
      case AppLanguage.hi:
        return 'नमस्ते! मैं ड्राइवमेट एआई सहायक हूँ। ड्राइवर हायरिंग, कार रेंटल, किराया बातचीत या रूट के बारे में कुछ भी पूछें।';
      case AppLanguage.orLang:
        return 'ନମସ୍କାର! ମୁଁ ଡ୍ରାଇଭମେଟ୍ ଏଆଇ ସହାୟକ। ଡ୍ରାଇଭର ଭଡ଼ା, କାର୍ ରେଣ୍ଟାଲ୍, କିରାୟା ବୁଝାମଣା କିମ୍ବା ରୁଟ୍ ବିଷୟରେ ଯାହା ଇଚ୍ଛା ପଚାରିପାରିବେ।';
      case AppLanguage.ur:
        return 'سلام! میں ڈرائیومیٹ اے آئی اسسٹنٹ ہوں۔ ڈرائیور کی خدمات، کار کرایہ، کرایہ کی بات چیت یا راستے کے بارے میں کچھ بھی پوچھیں۔';
      case AppLanguage.en:
      default:
        return 'Hello! I am your DriveMate AI Assistant. Ask me anything about hiring a chauffeur, car rentals, two-way fare negotiation, or navigation.';
    }
  }

  void _handleSend([String? prefilledText]) {
    final query = (prefilledText ?? _queryController.text).trim();
    if (query.isEmpty) return;

    final provider = context.read<DriveMateProvider>();
    final lang = provider.currentLanguage;

    setState(() {
      _messages.add(ChatMessage(text: query, isUser: true, time: 'Now'));
      _queryController.clear();
    });

    final reply = _generateLocalizedAnswer(query, lang);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false, time: 'Now'));
      });
      _scrollToBottom();
    });
  }

  String _generateLocalizedAnswer(String query, AppLanguage lang) {
    final q = query.toLowerCase();

    // 1. Driver Hiring / Chauffeur queries (Supports Bengali/Hindi scripts & Romanized Banglish/Hinglish)
    if (q.contains('driver') || q.contains('ড্রাইভার') || q.contains('চালক') || q.contains('ড্ৰাইভাৰ') ||
        q.contains('हक') || q.contains('ଡ୍ରାଇଭର') || q.contains('ڈرائیور') || q.contains('chauffeur') ||
        q.contains('ami driver') || q.contains('driver chai') || q.contains('driver chahiye')) {
      switch (lang) {
        case AppLanguage.bn:
          return 'ড্রাইভমেটে আপনি নিজের গাড়ির জন্য অভিজ্ঞ ও ব্যাকগ্রাউন্ড-যাচাইকৃত চালক হায়ার করতে পারেন। ওএসআরএম রুট অনুযায়ী একমুখী, রাউন্ড-ট্রিপ, ঘণ্টাভিত্তিক বা সারাদিনের জন্য হায়ার করুন।';
        case AppLanguage.hi:
          return 'ड्राइवमेट पर आप अपनी कार के लिए सत्यापित पेशेवर ड्राइवर हायर कर सकते हैं। सड़क दूरी के अनुसार एकतरफा, राउंड-ट्रिप, प्रति घंटा या पूरे दिन के लिए सेवा उपलब्ध है।';
        case AppLanguage.orLang:
          return 'ଡ୍ରାଇଭମେଟ୍ ରେ ଆପଣ ନିଜ କାର୍ ପାଇଁ ଅଭିଜ୍ଞ ଚାଳକ ଭଡ଼ା କରିପାରିବେ। ଏକତରଫା, ଯିବା-ଆସିବା, ଘଣ୍ଟା କିମ୍ବା ପୂରା ଦିନ ପାଇଁ ଉପଲବ୍ଧ।';
        case AppLanguage.ur:
          return 'ڈرائیومیٹ پر آپ اپنی گاڑی کے لیے تصدیق شدہ پیشہ ور ڈرائیور حاصل کر سکتے ہیں۔ ایک طرفہ، راؤنڈ ٹرپ، گھنٹہ وار یا پورے دن کے لیے دستیاب ہے۔';
        case AppLanguage.en:
        default:
          return 'With DriveMate, you can hire verified chauffeurs for customer-owned vehicles. Available as One-way, Round-trip, Hourly (2-12 hrs), or Full-day packages.';
      }
    }

    // 2. Fare Negotiation queries
    if (q.contains('negotiat') || q.contains('fare') || q.contains('ভাড়া') || q.contains('দরদাম') ||
        q.contains('দাম') || q.contains('किराया') || q.contains('बातचीत') || q.contains('ଭଡ଼ା') ||
        q.contains('كرایہ') || q.contains('koto') || q.contains('kitna') || q.contains('bujhamana')) {
      switch (lang) {
        case AppLanguage.bn:
          return 'ড্রাইভমেট টু-ওয়ে ভাড়া সমঝোতা সাপোর্ট করে! সার্ভার ফর্মুলার আনুমানিক ভাড়ার উপর আপনি নিজের প্রস্তাবিত ভাড়া পাঠাতে পারেন। চালক গ্রহণ করলে বা পাল্টা প্রস্তাব দিলে双方 একমত হলেই বুকিং নিশ্চিত হয়।';
        case AppLanguage.hi:
          return 'ड्राइवमेट पर दो-तरफा किराया बातचीत की सुविधा है। आप अपना कस्टम ऑफर भेज सकते हैं। ड्राइवर स्वीकार कर सकता है या काउंटर-ऑफर दे सकता है। दोनों की सहमति पर ही राइड पक्की होती है।';
        case AppLanguage.orLang:
          return 'ଡ୍ରାଇଭମେଟ୍ ରେ ଦୁଇ-ପାଖିଆ ଭଡ଼ା ବୁଝାମଣା ଉପଲବ୍ଧ। ଆପଣ ନିଜ ପ୍ରସ୍ତାବିତ ଭଡ଼ା ପଠାଇପାରିବେ। ଉଭୟ ରାଜି ହେବା ପରେ ହିଁ ବୁକିଂ ନିଶ୍ଚିତ ହୁଏ।';
        case AppLanguage.ur:
          return 'ڈرائیومیٹ پر دو طرفہ کرایہ کی بات چیت کی سہولت موجود ہے۔ آپ اپنی پیشکش بھیج سکتے ہیں اور ڈرائیور سے باہمی اتفاق پر ہی بکنگ کنفرم ہوتی ہے۔';
        case AppLanguage.en:
        default:
          return 'DriveMate features real-time Two-Way Fare Negotiation. Submit your custom offer within or outside the suggested range. The trip is confirmed only when both parties mutually agree.';
      }
    }

    // 3. OTP verification queries
    if (q.contains('otp') || q.contains('ওটিপি') || q.contains('ओटीपी') || q.contains('କୋଡ୍') || q.contains('او ٹی پی')) {
      switch (lang) {
        case AppLanguage.bn:
          return 'নিরাপত্তার জন্য আপনার ৪-সংখ্যার রাইড ওটিপি চালকের ড্যাশবোর্ডে স্বয়ংক্রিয়ভাবে দেখানো হয় না। চালক পৌঁছানোর পর মুখে ওটিপি শেয়ার করুন। ওটিপি যাচাইয়ের পরেই ট্রিপ শুরু হবে।';
        case AppLanguage.hi:
          return 'सुरक्षा के लिए 4-अंकीय राइड ओटीपी ड्राइवर को स्क्रीन पर नहीं दिखता। पिकअप पर पहुँचने पर ड्राइवर को मौखिक रूप से बताएं। ओटीपी सत्यापन के बाद ही यात्रा शुरू होगी।';
        case AppLanguage.orLang:
          return 'ସୁରକ୍ଷା ପାଇଁ ୪-ଅଙ୍କ ବିଶିଷ୍ଟ ଓଟିପି ଚାଳକଙ୍କୁ ସିଧା ଦେଖାଯାଏ ନାହିଁ। ଆପଣ ଚାଳକଙ୍କୁ କହିବା ପରେ ସେ ଯାଞ୍ଚ କରି ଯାତ୍ରା ଆରମ୍ଭ କରିବେ।';
        case AppLanguage.ur:
          return 'سیکورٹی کے لیے 4 ہندسوں کا رائیڈ او ٹی پی ڈرائیور کو زبانی بتائیں۔ پی ایچ پی بیک اینڈ پر تصدیق کے بعد ہی سفر شروع ہوگا۔';
        case AppLanguage.en:
        default:
          return 'For passenger safety, the 4-digit ride OTP is never shown on the driver dashboard. Please share it verbally upon arrival. The driver can start the trip only after backend OTP verification.';
      }
    }

    // 4. Car Rental / Self-Drive queries
    if (q.contains('rent') || q.contains('car') || q.contains('গাড়ি ভাড়া') || q.contains('রেন্ট') ||
        q.contains('किराए') || q.contains('गाड़ी') || q.contains('ଗାଡ଼ି') || q.contains('گاڑی')) {
      switch (lang) {
        case AppLanguage.bn:
          return 'ড্রাইভমেট সেল্ফ-ড্রাইভ কার রেন্টাল এবং চালকসহ কার রেন্টাল অফার করে। আপনার পছন্দসই সেডান, এসইউভি বা হ্যাচব্যাক বেছে নিন।';
        case AppLanguage.hi:
          return 'ड्राइवमेट पर सेल्फ-ड्राइव और ड्राइवर सहित कार रेंटल दोनों उपलब्ध हैं। आप अपनी पसंद की सेडान, एसयूवी या हैचबैक चुन सकते हैं।';
        case AppLanguage.orLang:
          return 'ଡ୍ରାଇଭମେଟ୍ ରେ ସେଲ୍ଫ-ଡ୍ରାଇଭ୍ ଏବଂ ଚାଳକ ସହିତ କାର୍ ଭଡ଼ାରେ ମିଳିଥାଏ।';
        case AppLanguage.ur:
          return 'ڈرائیومیٹ پر سیلف ڈرائیو اور ڈرائیور کے ساتھ کار کرایہ دونوں دستیاب ہیں۔';
        case AppLanguage.en:
        default:
          return 'DriveMate offers verified Self-Drive Car Rentals as well as Chauffeur-driven rentals across Sedans, SUVs, and Hatchbacks.';
      }
    }

    // Default Fallback
    switch (lang) {
      case AppLanguage.bn:
        return 'ধন্যবাদ আপনার বার্তার জন্য। জরুরি সহায়তার জন্য ১১২ বা ১৮০০-ড্রাইভমেট (1800-DRIVEMATE) টোল-ফ্রি নম্বরে যোগাযোগ করতে পারেন।';
      case AppLanguage.hi:
        return 'आपके प्रश्न के लिए धन्यवाद। तत्काल सहायता के लिए हमारे हेल्पलाइन नंबर 1800-DRIVEMATE या 112 पर संपर्क करें।';
      case AppLanguage.orLang:
        return 'ଆପଣଙ୍କ ପ୍ରଶ୍ନ ପାଇଁ ଧନ୍ୟବାଦ। ଜରୁରୀ ସହାୟତା ପାଇଁ 1800-DRIVEMATE କିମ୍ବା 112 ରେ କଲ୍ କରନ୍ତୁ।';
      case AppLanguage.ur:
        return 'آپ کے سوال کا شکریہ۔ فوری مدد کے لیے ہیلپ لائن 1800-DRIVEMATE یا 112 پر رابطہ کریں۔';
      case AppLanguage.en:
      default:
        return 'Thank you for your inquiry. For immediate emergency or booking assistance, tap Emergency SOS or contact our toll-free desk at 1800-DRIVEMATE.';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final lang = provider.currentLanguage;
    final isRtl = lang.textDirection == TextDirection.rtl;

    final List<String> quickFaqs;
    switch (lang) {
      case AppLanguage.bn:
        quickFaqs = ['ড্রাইভার কীভাবে হায়ার করব?', 'ভাড়া সমঝোতা কীভাবে কাজ করে?', 'রাইড ওটিপি কী?'];
        break;
      case AppLanguage.hi:
        quickFaqs = ['ड्राइवर कैसे हायर करें?', 'किराया बातचीत कैसे करें?', 'राइड ओटीपी सुरक्षा?'];
        break;
      case AppLanguage.orLang:
        quickFaqs = ['ଡ୍ରାଇଭର କିପରି ଭଡ଼ା କରିବି?', 'ଭଡ଼ା ବୁଝାମଣା କିପରି ହୁଏ?', 'ଓଟିପି ସୁରକ୍ଷା କ’ଣ?'];
        break;
      case AppLanguage.ur:
        quickFaqs = ['ڈرائیور کیسے ہائر کریں؟', 'کرایہ پر بات چیت کیسے کریں؟', 'او ٹی پی کیسے کام کرتا ہے؟'];
        break;
      case AppLanguage.en:
      default:
        quickFaqs = ['How to hire a driver?', 'How does fare negotiation work?', 'How does ride OTP work?'];
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Top handle & header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.navy900,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.cyanAccent.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy_outlined, color: AppColors.cyanAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DriveMate AI Assistant',
                          style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Multi-Lingual Mobility Support • ${lang.nativeName} (${lang.code.toUpperCase()})',
                          style: const TextStyle(color: AppColors.cyanAccent, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Quick FAQ Prompt Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.surfaceLight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: quickFaqs.map((faq) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: AppColors.electricBlue.withOpacity(0.4)),
                        label: Text(faq, style: const TextStyle(fontSize: 11, color: AppColors.navy900, fontWeight: FontWeight.w600)),
                        onPressed: () => _handleSend(faq),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Chat Messages Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(14),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color: msg.isUser ? AppColors.electricBlue : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: msg.isUser ? AppColors.electricBlue : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          color: msg.isUser ? Colors.white : AppColors.textPrimaryDark,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        onSubmitted: (_) => _handleSend(),
                        decoration: InputDecoration(
                          hintText: context.l10n.askAi,
                          hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: AppColors.cyanAccent,
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: AppColors.navy900, size: 18),
                        onPressed: () => _handleSend(),
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
}
